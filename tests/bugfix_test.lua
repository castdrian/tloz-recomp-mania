local Hitbox = require("hitbox")
local Feedback = require("feedback")
local WarpEffects = require("warp_effects")

local player = { cellX = 5, cellY = 5, facing = "right" }
local front = { id = "front", cellX = 6, cellY = 5 }
local upper = { id = "upper", cellX = 6, cellY = 4 }
local side = { id = "side", cellX = 5, cellY = 4 }
local behind = { id = "behind", cellX = 4, cellY = 5 }

local target = Hitbox.target(player, { upper, front, behind })
assert(target == front)
assert(Hitbox.target(player, { upper, behind }) == upper)
assert(Hitbox.target(player, { side, behind }) == side)
assert(Hitbox.target(player, { behind }) == nil)
local roundabout = Hitbox.roundaboutCells(player)
assert(#roundabout == 8)
assert(Hitbox.target(player, { behind }, nil, true) == behind)

local playerForWarp = { cellX = 2, cellY = 3 }
local doorMap = {
  warpPadOrHoleAt = function() return nil end,
}
local holeMap = {
  warpPadOrHoleAt = function() return "hole" end,
}
local padMap = {
  warpPadOrHoleAt = function() return "pad" end,
}
assert(WarpEffects.fallSound({ map = doorMap, player = playerForWarp }, { warp = {} }) == nil)
assert(WarpEffects.fallSound({ map = padMap, player = playerForWarp }, { warp = {} }) == nil)
assert(WarpEffects.fallSound({ map = holeMap, player = playerForWarp }, { warp = {} }) == "TLOZ_LINK_FALL")

local npc = { px = 80, py = 80 }
local first = Feedback.hit(npc, { count = 1, defeated = false })
assert(first.audio == "TLOZ_VILLAGER_HURT_1")
assert(first.particles == nil)
assert(npc.tlozGlowFrames == Feedback.GLOW_FRAMES)
for _ = 1, Feedback.GLOW_FRAMES do Feedback.tick(npc) end
assert(npc.tlozGlowFrames == 0)

local third = Feedback.hit(npc, { count = 3, defeated = true })
assert(third.audio == "TLOZ_VILLAGER_DEATH")
assert(third.particles and #third.particles == Feedback.PARTICLE_COUNT)
assert(third.particles[1].color[1] == 1)
assert(third.particles[1].color[2] < 0.1)
assert(third.particles[1].color[3] < 0.1)

local played = {}
local applied = Feedback.apply(npc, { count = 2, defeated = false },
  function(name) played[#played + 1] = name end)
assert(applied.audio == "TLOZ_VILLAGER_HURT_2")
assert(played[1] == "TLOZ_VILLAGER_HURT_2")

print("tloz-recomp-mania bugfix tests passed")
