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
for index = 1, 8 do
  poses[index] = Movement.pose(state, 1, false)
end
assertSequence(poses,
  { "walk", "walk", "walk_alt", "walk_alt", "walk", "walk", "walk_alt", "walk_alt" },
  "walking cadence")

assertEqual(Movement.pose(state, 0, false), "stand", "stand reset")
assertEqual(Movement.pose(state, 1, true), "walk_alt", "step phase seed")

print("tloz-recomp-mania movement tests passed")
