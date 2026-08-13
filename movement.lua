local Movement = {}

function Movement.new()
  return { walking = false, frame = 0 }
end

function Movement.pose(state, walkPhase, stepFlip)
  if walkPhase ~= 1 then
    state.walking = false
    state.frame = 0
    return "stand"
  end
  if not state.walking then
    state.walking = true
    state.frame = stepFlip and 2 or 0
  end
  local pose = state.frame < 2 and "walk" or "walk_alt"
  state.frame = (state.frame + 1) % 4
  return pose
end

return Movement
