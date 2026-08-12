package.path = "./?.lua;./?/init.lua;" .. package.path

local T = require("tests.modkit")
local Data = T.fixtures.fresh()

local run = T.sdk.loadMod("mods/tloz-recomp-mania", { data = Data })
T.eq(#run.errors, 0, "loads clean (" .. tostring(run.errors[1]) .. ")")
T.eq(run.mod and run.mod.state, "loaded", "reached the loaded state")
T.check(Data.audio.sfx.TLOZ_SWORD_1 ~= nil, "sword audio registered")
T.check(Data.audio.sfx.TLOZ_VILLAGER_DEATH ~= nil, "villager death audio registered")

run.release()
T.finish("tloz-recomp-mania")
