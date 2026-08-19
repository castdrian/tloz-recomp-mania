# what-the-heck

what the heck is this?

This content mod replaces every text row exposed by the imported Pokémon Red, Blue, Yellow, and Gold extraction with English text sent through a forty-language translation relay and translated back to English. That includes dialogue, signs, battle text, and menu text present in the extracted text tables.

The same relay is applied to the extracted Pokémon, move, item, and trainer names. The runtime control codes, placeholders, record IDs, and original spacing around those controls are preserved. The supplied Gen 1 and Gold data exports do not contain an ability-name registry; Gen 1 has no ability system, so there is no ability table available to patch. The included engine-string catalog is empty because no separate engine-string extraction was supplied; the extracted `text.lua` tables are the available game text source.

The catalogs are generated before packaging, so the game does not need an internet connection. Missing or unsafe entries remain English and the mod does not include ROMs or save files.

The mod chooses the catalog for the active game version. Blue uses the Red catalog when no separate Blue source catalog is supplied because the shared Gen 1 text and named-record identifiers are compatible.

To regenerate the catalogs, provide extracted `text.lua` files from your own imported ROM caches:

```sh
python3 tools/translate_chain.py \
  --red /path/to/red/data/generated/text.lua \
  --yellow /path/to/yellow/data/generated/text.lua \
  --gold /path/to/gold/data/generated/text.lua \
  --output lang
```

Named catalogs use the matching `--red-pokemon`, `--red-moves`, `--red-items`, and `--red-trainers` options, with equivalent options for Yellow and Gold. Use `--skip-text` when regenerating only named catalogs.

The relay uses Google Translate's public translation endpoint through the same sequential approach as the translation telephone tools. The generated output is normalized for the original game font and validated against the source tables before packaging. The package contains generated catalogs only and does not need an internet connection, ROMs, or save files at runtime.
