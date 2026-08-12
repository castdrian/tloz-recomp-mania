local Combat = {}

Combat.equipment = {
  { id = "shield", audio = "TLOZ_SHIELD" },
  { id = "bow", audio = "TLOZ_ARROW_SHOOT" },
  { id = "boomerang", audio = "TLOZ_BOOMERANG" },
  { id = "hookshot", audio = "TLOZ_HOOKSHOT" },
  { id = "hammer", audio = "TLOZ_HAMMER" },
  { id = "shovel", audio = "TLOZ_SHOVEL" },
  { id = "magic_powder", audio = "TLOZ_MAGIC_POWDER" },
  { id = "fire_rod", audio = "TLOZ_FIRE_ROD" },
  { id = "ice_rod", audio = "TLOZ_ICE_ROD" },
  { id = "lamp", audio = "TLOZ_LAMP" },
  { id = "cane", audio = "TLOZ_CANE" },
  { id = "bomb", audio = "TLOZ_BOMB_DROP" },
}

function Combat.new()
  return { combo = 0, hits = {}, equipment = 1 }
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

function Combat.currentEquipment(state)
  return Combat.equipment[state.equipment]
end

function Combat.nextEquipment(state)
  state.equipment = (state.equipment % #Combat.equipment) + 1
  return Combat.currentEquipment(state)
end

return Combat
