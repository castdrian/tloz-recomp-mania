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

assert_rgba() {
  path=$1
  color_type=$(/usr/bin/od -An -tu1 -j25 -N1 "$root/$path" \
    | /usr/bin/tr -d '[:space:]')
  test "$color_type" = "6" || {
    printf 'expected %s to use PNG color type 6, got %s\n' "$path" "$color_type" >&2
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

for direction in down left right up; do
  for frame in 1 2; do
    path="assets/sprites/shield_${direction}_${frame}.png"
    assert_dimensions "$path" 16x16
    assert_transparent_corner "$path"
    assert_rgba "$path"
  done
done

for path in \
            assets/sprites/use_item_1.png \
            assets/sprites/use_item_2.png; do
  assert_dimensions "$path" 16x16
  assert_transparent_corner "$path"
done

assert_dimensions assets/sprites/environment/pot.png 16x16
assert_transparent_corner assets/sprites/environment/pot.png
assert_rgba assets/sprites/environment/pot.png

for color in red green blue purple silver gold; do
  path="assets/sprites/environment/rupee_${color}.png"
  assert_dimensions "$path" 18x18
  assert_transparent_corner "$path"
  assert_rgba "$path"
done

for path in assets/sprites/environment/grass_fx_1.png \
            assets/sprites/environment/grass_fx_2.png \
            assets/sprites/environment/grass_fx_3.png \
            assets/sprites/environment/grass_fx_4.png \
            assets/sprites/environment/grass_fx_5.png \
            assets/sprites/environment/grass_fx_6.png; do
  assert_dimensions "$path" 16x16
  assert_transparent_corner "$path"
  assert_rgba "$path"
done

for path in assets/sprites/environment/pot_fx_1.png \
            assets/sprites/environment/pot_fx_2.png \
            assets/sprites/environment/pot_fx_3.png \
            assets/sprites/environment/pot_fx_4.png \
            assets/sprites/environment/pot_fx_5.png \
            assets/sprites/environment/pot_fx_6.png; do
  assert_dimensions "$path" 31x31
  assert_transparent_corner "$path"
  assert_rgba "$path"
done

/opt/homebrew/bin/rg -q 'Minecraft_Villager_Hurt_1\.wav' "$root/main.lua"
/opt/homebrew/bin/rg -q 'Minecraft_Villager_Hurt_4\.wav' "$root/main.lua"
/opt/homebrew/bin/rg -q 'Minecraft_Villager_Death\.wav' "$root/main.lua"
/opt/homebrew/bin/rg -q 'TLOZ_RUPEE_DROP' "$root/main.lua"
/opt/homebrew/bin/rg -q 'TLOZ_GRASS_CUT' "$root/main.lua"
/opt/homebrew/bin/rg -q 'TLOZ_POT_BREAK' "$root/main.lua"
/opt/homebrew/bin/rg -q 'PaletteFX\.markSpriteRedraw' "$root/main.lua"
/opt/homebrew/bin/rg -q 'assetFacing = facing' "$root/main.lua"

printf '%s\n' 'tloz-recomp-mania sprite asset tests passed'
