local Combat = {}

function Combat.new()
  return { combo = 0, hits = {} }
end

function Combat.nextCombo(state)
  state.combo = (state.combo % 4) + 1
  return state.combo
end

function Combat.registerHit(state, targetId)
  local count = (state.hits[targetId] or 0) + 1
  state.hits[targetId] = count
  return { count = count, defeated = count >= 3 }
end

return Combat
