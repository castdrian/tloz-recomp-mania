from __future__ import annotations

import argparse
import json
import re
import sys
import time
import unicodedata
import urllib.parse
import urllib.request
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

CHAIN = (
    "es", "fr", "de", "it", "pt", "nl", "ru", "uk", "pl", "cs",
    "sk", "hu", "ro", "bg", "el", "tr", "ar", "he", "fa", "hi",
    "bn", "ur", "ta", "te", "th", "vi", "id", "ms", "tl", "sw",
    "am", "af", "zu", "ja", "ko", "zh-CN", "fi", "sv", "no", "da",
)

ENTRY = re.compile(
    r'^\s*(?:\["(?P<quoted>(?:\\.|[^"])*)"\]|'
    r'(?P<bare>[A-Za-z_][A-Za-z0-9_]*))\s*=\s*'
    r'"(?P<value>(?:\\.|[^"])*)",?\s*$'
)
ROW = re.compile(r'(?i)WTH(\d{6})\s*[:：]\s*(.*?)(?=\s*WTH\d{6}\s*[:：]|\Z)', re.S)
ID_FIELD = re.compile(r'^\s*id\s*=\s*"(?P<value>(?:\\.|[^"])*)",?\s*$')
NAME_FIELD = re.compile(r'^\s*name\s*=\s*"(?P<value>(?:\\.|[^"])*)",?\s*$')
NAMED_CATALOGS = ("pokemon", "moves", "items", "trainers")
CONTROL_CHARACTERS = ("\n", "\v", "\f", "\r", "\t")
CONTROL_PATTERN = re.compile("[" + "".join(re.escape(value) for value in CONTROL_CHARACTERS) + "]")
RUNTIME_TOKENS = re.compile(r"\{[^{}\n]+\}|#MON|POKéMON|POKEMON|¥")
FIXED_PATTERN = re.compile(r"[\n\v\f\r\t]|\{[^{}\n]+\}|#MON|POKéMON|POKEMON|¥")


def decode_lua(value: str) -> str:
    result = []
    index = 0
    escapes = {"a": "\a", "b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", "v": "\v", "\\": "\\", '"': '"', "'": "'"}
    while index < len(value):
        if value[index] != "\\":
            result.append(value[index])
            index += 1
            continue
        index += 1
        if index >= len(value):
            result.append("\\")
            break
        if value[index].isdigit():
            end = index
            while end < len(value) and end < index + 3 and value[end].isdigit():
                end += 1
            result.append(chr(int(value[index:end])))
            index = end
            continue
        result.append(escapes.get(value[index], value[index]))
        index += 1
    return "".join(result)


def lua_string(value: str) -> str:
    output = []
    for character in value:
        code = ord(character)
        if character == "\\":
            output.append("\\\\")
        elif character == '"':
            output.append('\\"')
        elif character == "\n":
            output.append("\\n")
        elif character == "\r":
            output.append("\\r")
        elif character == "\t":
            output.append("\\t")
        elif character == "\v":
            output.append("\\v")
        elif character == "\f":
            output.append("\\f")
        elif code < 32:
            output.append("\\%03d" % code)
        else:
            output.append(character)
    return '"' + "".join(output) + '"'


def parse_catalog(path: Path) -> dict[str, str]:
    rows = {}
    nested_depth = 0
    for line_number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        stripped = line.strip()
        if not stripped or stripped == "return {":
            continue
        if nested_depth:
            if stripped.endswith("{"):
                nested_depth += 1
            elif stripped in {"}", "},"}:
                nested_depth -= 1
            continue
        if re.match(r"^[A-Za-z_][A-Za-z0-9_]*\s*=\s*\{\s*$", stripped):
            nested_depth = 1
            continue
        if stripped in {"}", "},"}:
            continue
        if re.match(r"^generation\s*=", stripped):
            continue
        match = ENTRY.match(line)
        if not match:
            if "=" in line:
                raise ValueError(f"unrecognized catalog row in {path}:{line_number}")
            continue
        key = match.group("quoted") if match.group("quoted") is not None else match.group("bare")
        decoded_key = decode_lua(key)
        if decoded_key in rows:
            raise ValueError(f"duplicate catalog key {decoded_key} in {path}:{line_number}")
        rows[decoded_key] = decode_lua(match.group("value"))
    if not rows:
        raise ValueError(f"no text entries found in {path}")
    return rows


def parse_named_catalog(path: Path) -> dict[str, str]:
    rows = {}
    pending = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        indent = len(line) - len(line.lstrip())
        for level in tuple(pending):
            if level > indent:
                del pending[level]
        id_match = ID_FIELD.match(line)
        if id_match:
            pending[indent] = decode_lua(id_match.group("value"))
            continue
        name_match = NAME_FIELD.match(line)
        if name_match and pending:
            if indent not in pending:
                raise ValueError(f"named catalog id missing beside name in {path}:{line}")
            level = indent
            key = pending[level]
            value = decode_lua(name_match.group("value"))
            if key in rows:
                raise ValueError(f"duplicate named catalog id {key} in {path}")
            rows[key] = value
    if not rows:
        raise ValueError(f"no named entries found in {path}")
    return rows


def request_batch(text: str, source: str, target: str) -> str:
    query = urllib.parse.urlencode({"client": "gtx", "sl": source, "tl": target, "dt": "t", "q": text})
    url = "https://translate.googleapis.com/translate_a/single?" + query
    last_error = None
    for attempt in range(5):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "what-the-heck-generator/1.0"})
            with urllib.request.urlopen(request, timeout=45) as response:
                payload = json.load(response)
            parts = payload[0] if isinstance(payload, list) else []
            return "".join(part[0] for part in parts if isinstance(part, list) and part and isinstance(part[0], str))
        except Exception as error:
            last_error = error
            time.sleep(0.75 * (attempt + 1))
    raise RuntimeError(f"translation request failed {source}->{target}: {last_error}")


def parse_rows(value: str) -> dict[int, str]:
    rows = {}
    for match in ROW.finditer(value):
        index = int(match.group(1))
        if index in rows:
            raise ValueError(f"duplicate translated row {index}")
        rows[index] = match.group(2).strip()
    return rows


def translate_batch(batch: list[tuple[int, str]], source: str, target: str) -> tuple[dict[int, str], set[int]]:
    payload = "\n".join("WTH%06d: %s" % (index, value) for index, value in batch)
    try:
        translated = parse_rows(request_batch(payload, source, target))
        expected = {index for index, _ in batch}
        if set(translated) == expected:
            return {index: translated[index] for index in expected}, set()
    except Exception:
        translated = {}
    if len(batch) == 1:
        return {batch[0][0]: batch[0][1]}, {batch[0][0]}
    midpoint = len(batch) // 2
    left, left_failed = translate_batch(batch[:midpoint], source, target)
    right, right_failed = translate_batch(batch[midpoint:], source, target)
    return {**left, **right}, left_failed | right_failed


def batches(rows: dict[int, str], limit: int = 7000) -> list[list[tuple[int, str]]]:
    result = []
    current = []
    size = 0
    for index, value in rows.items():
        entry = "WTH%06d: %s\n" % (index, value)
        if current and size + len(entry) > limit:
            result.append(current)
            current = []
            size = 0
        current.append((index, value))
        size += len(entry)
    if current:
        result.append(current)
    return result


def translate_rows(rows: dict[int, str], workers: int) -> dict[int, str]:
    original = dict(rows)
    current = dict(rows)
    failed = set()
    for stage, target in enumerate((*CHAIN, "en"), 1):
        source = "en" if stage == 1 else (*CHAIN, "en")[stage - 2]
        active = {index: value for index, value in current.items() if index not in failed}
        if not active:
            break
        groups = batches(active)
        translated = {}
        with ThreadPoolExecutor(max_workers=workers) as pool:
            futures = [pool.submit(translate_batch, batch, source, target) for batch in groups]
            for position, future in enumerate(as_completed(futures), 1):
                values, batch_failed = future.result()
                translated.update(values)
                failed.update(batch_failed)
                if position == len(futures) or position % 10 == 0:
                    print(f"  {source}->{target}: {position}/{len(futures)} batches", file=sys.stderr, flush=True)
        current = {
            index: original[index] if index in failed else CONTROL_PATTERN.sub(" ", translated[index])
            for index in original
        }
    return current


def split_literal(value: str) -> tuple[str, str, str]:
    left = len(value) - len(value.lstrip(" "))
    right = len(value.rstrip(" "))
    if right < left:
        right = left
    return value[:left], value[left:right], value[right:]


def split_value(value: str) -> tuple[list[tuple[str, str | int]], dict[int, tuple[str, str, str]]]:
    layout = []
    literals = {}
    cursor = 0
    for match in FIXED_PATTERN.finditer(value):
        literal = value[cursor:match.start()]
        if literal:
            index = len(literals) + 1
            literals[index] = split_literal(literal)
            layout.append(("text", index))
        layout.append(("fixed", match.group(0)))
        cursor = match.end()
    literal = value[cursor:]
    if literal:
        index = len(literals) + 1
        literals[index] = split_literal(literal)
        layout.append(("text", index))
    return layout, literals


def fixed_parts(value: str) -> list[tuple[str, str]]:
    parts = []
    cursor = 0
    for match in FIXED_PATTERN.finditer(value):
        parts.append(("text", value[cursor:match.start()]))
        parts.append(("fixed", match.group(0)))
        cursor = match.end()
    parts.append(("text", value[cursor:]))
    return parts


def preserve_literal(value: str, original: str) -> str:
    value = value.strip(" ")
    original = original.strip(" ")
    if original and not value:
        return original
    if re.search(r"[A-Za-z]", original) and not re.search(r"[A-Za-z]", value):
        return original
    return value


def restore_boundaries(value: str, original: str) -> str:
    translated_parts = fixed_parts(value)
    original_parts = fixed_parts(original)
    translated_fixed = [part for kind, part in translated_parts if kind == "fixed"]
    original_fixed = [part for kind, part in original_parts if kind == "fixed"]
    if translated_fixed != original_fixed or len(translated_parts) != len(original_parts):
        return value
    restored = []
    for translated_part, original_part in zip(translated_parts, original_parts):
        if translated_part[0] == "fixed":
            restored.append(translated_part[1])
            continue
        prefix, original_literal, suffix = split_literal(original_part[1])
        restored.append(prefix + preserve_literal(translated_part[1], original_literal) + suffix)
    return "".join(restored)


def clean(value: str, original: str) -> str:
    value = value.replace("“", '"').replace("”", '"').replace("’", "'").replace("–", "-").replace("—", "-")
    protected = {}

    def replace(match: re.Match[str]) -> str:
        marker = "__WTH_CLEAN_%03d__" % len(protected)
        protected[marker] = match.group(0)
        return marker

    value = RUNTIME_TOKENS.sub(replace, value)
    value = unicodedata.normalize("NFKD", value).encode("ascii", "ignore").decode("ascii")
    for marker, original_token in protected.items():
        value = value.replace(marker, original_token)
    if not re.search(r"[A-Za-z]", value):
        return original
    return value


def clean_name(value: str, original: str) -> str:
    value = clean(value, original)
    if "I-" not in original:
        value = re.sub(r" *I-(?=[ \n\v\f\r\t]|$|[A-Za-z]|[.!?,])", "", value)
    source_suffix = re.search(r"[^\w\s]+$", original.strip())
    suffix = source_suffix.group(0) if source_suffix else ""
    value = value.strip()
    value = re.sub(r"(?:\s*[^\w\s]+)+$", "", value)
    value = re.sub(r"[ ]{2,}", " ", value)
    if suffix:
        value += suffix
    return value or original


def clean_text(value: str, original: str) -> str:
    value = clean(value, original)
    if "/" not in original:
        value = value.replace("/", "")
    value = re.sub(r" *I-(?=[ \n\v\f\r\t]|$|[A-Za-z]|[.!?,])", "", value)
    return value


def validate_catalog(original: dict[str, str], output: dict[str, str], named: bool) -> None:
    if original.keys() != output.keys():
        missing = sorted(set(original) - set(output))
        extra = sorted(set(output) - set(original))
        raise ValueError(f"catalog key mismatch; missing={missing[:3]} extra={extra[:3]}")
    for key, original_value in original.items():
        output_value = output[key]
        if original_value and not output_value:
            raise ValueError(f"empty translated value for {key}")
        if named:
            continue
        if CONTROL_PATTERN.findall(original_value) != CONTROL_PATTERN.findall(output_value):
            raise ValueError(f"control-code mismatch for {key}")
        if RUNTIME_TOKENS.findall(original_value) != RUNTIME_TOKENS.findall(output_value):
            raise ValueError(f"runtime-token mismatch for {key}")
        if restore_boundaries(output_value, original_value) != output_value:
            raise ValueError(f"spacing-boundary mismatch for {key}")
        if "/" not in original_value and "/" in output_value:
            raise ValueError(f"relay slash artifact for {key}")
        if "I-" not in original_value and "I-" in output_value:
            raise ValueError(f"relay I- artifact for {key}")


def write_catalog(destination: Path, output: dict[str, str]) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    lines = ["return {"]
    lines.extend(f"  [{lua_string(key)}] = {lua_string(value)}," for key, value in output.items())
    lines.append("}")
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def translate_catalog(source: Path, destination: Path, workers: int, parser=parse_catalog) -> None:
    original = parser(source)
    layouts = {}
    rows = {}
    boundaries = {}
    for key, value in sorted(original.items()):
        layout, literals = split_value(value)
        offset = len(rows)
        rows.update({offset + index: literal[1] for index, literal in literals.items()})
        boundaries.update({offset + index: (literal[0], literal[2]) for index, literal in literals.items()})
        layouts[key] = [(kind, offset + part if kind == "text" else part) for kind, part in layout]
    print(f"{source.name}: {len(original)} entries", file=sys.stderr, flush=True)
    translated = translate_rows(rows, workers) if rows else {}
    output = {}
    cleaner = clean_name if parser is parse_named_catalog else clean_text
    for key in sorted(original):
        value = "".join(
            boundaries[part][0] + preserve_literal(translated.get(part, rows[part]), rows[part]) + boundaries[part][1]
            if kind == "text" else part
            for kind, part in layouts[key]
        )
        value = restore_boundaries(value, original[key])
        output[key] = restore_boundaries(cleaner(value, original[key]), original[key])
    validate_catalog(original, output, parser is parse_named_catalog)
    write_catalog(destination, output)
    print(f"wrote {destination} with {len(output)} entries", file=sys.stderr, flush=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--red", type=Path)
    parser.add_argument("--blue", type=Path)
    parser.add_argument("--yellow", type=Path)
    parser.add_argument("--gold", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--workers", type=int, default=8)
    parser.add_argument("--skip-text", action="store_true")
    for version in ("red", "blue", "yellow", "gold"):
        for catalog in NAMED_CATALOGS:
            parser.add_argument(f"--{version}-{catalog}", type=Path)
    args = parser.parse_args()
    if not args.skip_text:
        if not args.red or not args.yellow or not args.gold:
            parser.error("--red, --yellow, and --gold are required unless --skip-text is used")
        catalogs = (("red", args.red), ("yellow", args.yellow), ("gold", args.gold))
        translate_catalog(args.red, args.output / "red.lua", args.workers)
        if args.blue:
            translate_catalog(args.blue, args.output / "blue.lua", args.workers)
        else:
            (args.output / "blue.lua").write_text((args.output / "red.lua").read_text(encoding="utf-8"), encoding="utf-8")
        for name, source in catalogs[1:]:
            translate_catalog(source, args.output / (name + ".lua"), args.workers)
    for catalog in NAMED_CATALOGS:
        for version in ("red", "blue", "yellow", "gold"):
            source = getattr(args, f"{version}_{catalog}")
            destination = args.output / f"{version}_{catalog}.lua"
            if source:
                translate_catalog(source, destination, args.workers, parse_named_catalog)
            elif version == "blue" and (args.output / f"red_{catalog}.lua").is_file():
                destination.write_text((args.output / f"red_{catalog}.lua").read_text(encoding="utf-8"), encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
