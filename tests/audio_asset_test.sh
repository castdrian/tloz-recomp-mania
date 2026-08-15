set -eu

root=${1:-.}
ffmpeg=/opt/homebrew/bin/ffmpeg

mean_volume() {
  "$ffmpeg" -hide_banner -i "$1" -af volumedetect -f null - 2>&1 \
    | awk '/mean_volume:/ { print $5; exit }'
}

reference=$(mean_volume "$root/assets/audio/mc/MC_Link_Sword1.wav")

test -f "$root/assets/audio/oot/OOT_Pot_Shatter.wav" || {
  printf '%s\n' 'missing OOT pot shatter audio' >&2
  exit 1
}

for name in Minecraft_Villager_Hurt_1 Minecraft_Villager_Hurt_2 \
           Minecraft_Villager_Hurt_3 Minecraft_Villager_Hurt_4 \
           Minecraft_Villager_Death; do
  path="$root/assets/audio/$name.wav"
  test -f "$path" || {
    printf 'missing normalized audio: %s\n' "$path" >&2
    exit 1
  }
  actual=$(mean_volume "$path")
  awk -v reference="$reference" -v actual="$actual" \
    'BEGIN { delta = actual - reference; if (delta < 0) delta = -delta; exit !(delta <= 1.5) }' || {
    printf 'audio level mismatch for %s: reference %s, actual %s\n' \
      "$path" "$reference" "$actual" >&2
    exit 1
  }
done

printf '%s\n' 'tloz-recomp-mania audio asset tests passed'
