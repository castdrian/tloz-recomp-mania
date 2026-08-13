local Movement = {}

function Movement.new()
  return {
    active = false,
    clock = 0,
    startClock = 0,
    startPhase = 0,
    stepFlip = false,
  }
end

function Movement.sync(state, active, clock, stepFlip)
  clock = tonumber(clock) or state.clock or 0
  stepFlip = stepFlip and true or false
  if not active then
    state.active = false
    state.clock = clock
    state.stepFlip = stepFlip
    return "stand"
  end
  if not state.active or state.stepFlip ~= stepFlip then
    state.active = true
    state.startClock = clock
    state.startPhase = stepFlip and 1 or 0
  end
  state.stepFlip = stepFlip
  state.clock = clock
end

function Movement.pose(state)
  if not state.active then return "stand" end
  local elapsed = math.max(0, state.clock - state.startClock)
  local phase = (state.startPhase + math.floor(elapsed / 8)) % 2
  return phase == 0 and "walk" or "walk_alt"
end

return Movement
