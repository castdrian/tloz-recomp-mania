package.path = "./?.lua;./?/init.lua;" .. package.path

local ok, T = pcall(require, "tests.modkit")
if ok then
  local Data = T.fixtures.fresh()
  local run = T.sdk.loadMod("mods/tloz-recomp-mania", { data = Data })
  T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
  T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")
  T.check(Data.audio.sfx.TLOZ_SWORD_1 ~= nil, "sword audio registered")
  T.check(Data.audio.sfx.TLOZ_ARROW_SHOOT ~= nil, "bow audio registered")
  T.check(Data.audio.sfx.TLOZ_BOMB_DROP ~= nil, "bomb audio registered")
  T.check(Data.audio.sfx.TLOZ_VILLAGER_DEATH ~= nil, "villager death audio registered")
  local audio = {
    "TLOZ_LINK_DASH", "TLOZ_LINK_DYING", "TLOZ_LINK_FALL",
    "TLOZ_LINK_HURT", "TLOZ_LINK_JUMP", "TLOZ_LINK_LAND",
    "TLOZ_LINK_PICKUP", "TLOZ_LINK_PUSH", "TLOZ_LINK_SHOCK",
    "TLOZ_LINK_SHOCK_FAST", "TLOZ_LINK_THROW", "TLOZ_SWORD_1",
    "TLOZ_SWORD_2", "TLOZ_SWORD_3", "TLOZ_SWORD_4",
    "TLOZ_SWORD_CHARGE", "TLOZ_SWORD_MAGIC", "TLOZ_SWORD_MAGIC_LOOP",
    "TLOZ_SWORD_SPIN", "TLOZ_SWORD_SPIN_MAGIC", "TLOZ_SWORD_TAP",
    "TLOZ_SHIELD", "TLOZ_ARROW_HIT", "TLOZ_ARROW_SHOOT",
    "TLOZ_BOOMERANG", "TLOZ_HOOKSHOT", "TLOZ_HAMMER",
    "TLOZ_HAMMER_POST", "TLOZ_SHOVEL", "TLOZ_MAGIC_POWDER",
    "TLOZ_FIRE_ROD", "TLOZ_ICE_ROD", "TLOZ_LAMP", "TLOZ_CANE",
    "TLOZ_CANE_MAGIC", "TLOZ_BOMB_DROP", "TLOZ_BOMB_BLOW",
    "TLOZ_VILLAGER_HURT_1", "TLOZ_VILLAGER_HURT_2",
    "TLOZ_VILLAGER_HURT_3", "TLOZ_VILLAGER_HURT_4",
    "TLOZ_VILLAGER_DEATH",
  }
  for _, name in ipairs(audio) do
    T.check(Data.audio.sfx[name] ~= nil, name .. " registered")
  end
  run.release()
  T.finish("tloz-recomp-mania")
else
  local manifest = assert(io.open("manifest.json", "r")):read("*a")
  assert(manifest:match('"id"%s*:%s*"tloz%-recomp%-mania"'))
  assert(manifest:match('"version"%s*:%s*"0%.1%.0"'))
  assert(loadfile("main.lua"))
  print("tloz-recomp-mania standalone load checks passed")
end
