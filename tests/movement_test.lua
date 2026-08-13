local Movement = require("movement")

local function assertEqual(actual, expected, label)
  assert(actual == expected,
    string.format("%s: expected %s, got %s", label, expected, actual))
end

local function assertSequence(actual, expected, label)
  assert(#actual == #expected, string.format("%s: length mismatch", label))
  for index = 1, #expected do
    assertEqual(actual[index], expected[index],
      string.format("%s[%d]", label, index))
  end
end

local state = Movement.new()
local poses = {}
for clock = 1, 16 do
  Movement.sync(state, true, clock, false)
  poses[clock] = Movement.pose(state)
end
assertSequence(poses,
  { "walk", "walk", "walk", "walk", "walk", "walk", "walk", "walk",
    "walk_alt", "walk_alt", "walk_alt", "walk_alt", "walk_alt", "walk_alt",
    "walk_alt", "walk_alt" },
  "walking cadence")

Movement.sync(state, false, 16, false)
assertEqual(Movement.pose(state), "stand", "stand reset")
Movement.sync(state, true, 17, true)
assertEqual(Movement.pose(state), "walk_alt", "step phase seed")
Movement.sync(state, true, 25, true)
assertEqual(Movement.pose(state), "walk", "step phase cadence")

print("tloz-recomp-mania movement tests passed")
