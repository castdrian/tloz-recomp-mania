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
  run.release()
  T.finish("tloz-recomp-mania")
else
  local manifest = assert(io.open("manifest.json", "r")):read("*a")
  assert(manifest:match('"id"%s*:%s*"tloz%-recomp%-mania"'))
  assert(manifest:match('"version"%s*:%s*"0%.1%.0"'))
  assert(loadfile("main.lua"))
  print("tloz-recomp-mania standalone load checks passed")
end
