local Action = require("action")

local heldSword = Action.new("sword", 1, "hit", 3, 2)
Action.trackButton(heldSword, true)
assert(Action.canCharge(heldSword, true))

local tappedSword = Action.new("sword", 1, "hit", 3, 2)
Action.trackButton(tappedSword, false)
Action.trackButton(tappedSword, true)
assert(not Action.canCharge(tappedSword, true))

local tool = Action.new("tool", "bomb", "hit")
assert(not Action.canCharge(tool, true))

print("tloz-recomp-mania action tests passed")
