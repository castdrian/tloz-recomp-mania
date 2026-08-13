set -eu

root=${1:-.}

assert_dimensions() {
  path=$1
  expected=$2
  actual=$(/opt/homebrew/bin/identify -format '%wx%h' "$root/$path")
  test "$actual" = "$expected" || {
    printf 'expected %s to be %s, got %s\n' "$path" "$expected" "$actual" >&2
    exit 1
  }
}

assert_transparent_corner() {
  path=$1
  pixel=$(/opt/homebrew/bin/identify -format '%[pixel:p{0,0}]' "$root/$path")
  test "$pixel" = "srgba(0,0,0,0)" || {
    printf 'expected %s to have a transparent corner, got %s\n' "$path" "$pixel" >&2
    exit 1
  }
}

for direction in down left right up; do
  for pose in stand walk walk_alt; do
    path="assets/sprites/mc/move_${direction}_${pose}.png"
    assert_dimensions "$path" 16x16
    assert_transparent_corner "$path"
  done
done

for path in assets/sprites/mc/sword_swing_1.png \
            assets/sprites/mc/sword_swing_5.png \
            assets/sprites/mc/sword_spin_1.png \
            assets/sprites/mc/sword_spin_5.png; do
  assert_dimensions "$path" 32x32
  assert_transparent_corner "$path"
done

for path in assets/sprites/shield_down_1.png \
            assets/sprites/shield_left_1.png \
            assets/sprites/shield_right_1.png \
            assets/sprites/shield_up_1.png \
            assets/sprites/use_item_1.png \
            assets/sprites/use_item_2.png; do
  assert_dimensions "$path" 16x16
  assert_transparent_corner "$path"
done

/opt/homebrew/bin/rg -q 'Minecraft_Villager_Hurt_1\.wav' "$root/main.lua"
/opt/homebrew/bin/rg -q 'Minecraft_Villager_Death\.wav' "$root/main.lua"
/opt/homebrew/bin/rg -q 'PaletteFX\.markSpriteRedraw' "$root/main.lua"

printf '%s\n' 'tloz-recomp-mania sprite asset tests passed'
