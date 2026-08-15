local SeamTransition = {}

SeamTransition.DURATION_FRAMES = 16

local function viewSize(width, height)
  width = tonumber(width) or 160
  height = tonumber(height) or 144
  return math.max(1, width), math.max(1, height)
end

local function directionOffset(direction, width, height)
  if direction == "left" then return -width / 2, 0 end
  if direction == "right" then return width / 2, 0 end
  if direction == "up" then return 0, -height / 2 end
  if direction == "down" then return 0, height / 2 end
  return nil, nil
end

function SeamTransition.begin(state, direction, width, height)
  if not (state and state.camera) then return false end
  local viewW, viewH = viewSize(width, height)
  local offsetX, offsetY = directionOffset(direction, viewW, viewH)
  if not offsetX then return false end
  if state.tlozSeamTransition then return false end
  state.tlozSeamTransition = {
    direction = direction,
    offsetX = offsetX,
    offsetY = offsetY,
    elapsed = 0,
    duration = SeamTransition.DURATION_FRAMES,
  }
  return true
end

function SeamTransition.update(state)
  local transition = state and state.tlozSeamTransition
  if not transition or not state.camera then return false end
  transition.elapsed = transition.elapsed + 1
  local progress = math.min(1, transition.elapsed / transition.duration)
  state.camera.x = state.camera.x + transition.offsetX * progress
  state.camera.y = state.camera.y + transition.offsetY * progress
  if progress >= 1 then state.tlozSeamTransition = nil end
  return true
end

function SeamTransition.active(state)
  return state and state.tlozSeamTransition ~= nil or false
end

return SeamTransition
