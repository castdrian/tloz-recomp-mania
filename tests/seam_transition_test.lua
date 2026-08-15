local SeamTransition = require("seam_transition")

local function frame(state, x, y)
  state.camera.x = x
  state.camera.y = y
  SeamTransition.update(state)
end

local state = { camera = { x = 10, y = 20 } }
assert(SeamTransition.begin(state, "right", 160, 144))
assert(SeamTransition.active(state))
frame(state, 10, 20)
assert(state.camera.x > 10)
assert(state.camera.y == 20)

for _ = 2, SeamTransition.DURATION_FRAMES do frame(state, 10, 20) end
assert(state.camera.x == 90)
assert(state.camera.y == 20)
assert(not SeamTransition.active(state))

state = { camera = { x = 10, y = 20 } }
assert(SeamTransition.begin(state, "up", 160, 144))
frame(state, 10, 20)
assert(state.camera.x == 10)
assert(state.camera.y < 20)

state = { camera = { x = 10, y = 20 } }
assert(not SeamTransition.begin(state, "diagonal", 160, 144))
assert(not SeamTransition.active(state))

print("tloz-recomp-mania seam transition tests passed")
