local Wilds = require("wilds_compat")

local logic = {
  spawns = {},
  entities = {},
  byMap = { PALLET_TOWN = {} },
  recounted = false,
}

function logic:_despawn(id)
  self.spawns[id] = nil
  self.entities[id] = nil
  for _, ids in pairs(self.byMap) do
    for index = #ids, 1, -1 do
      if ids[index] == id then table.remove(ids, index) end
    end
  end
end

function logic:_recountRegions()
  self.recounted = true
end

local exports = {
  logic = logic,
  isBattleableWild = function(entity)
    return entity.state == "available" and not entity.tlozDefeated
  end,
}

local mod = {
  find = function(first, second)
    local id = second or first
    if id == Wilds.DEPENDENCY_ID then return { exports = exports } end
    return nil
  end,
}

local entity = {
  id = "wild-1",
  spawnId = "wild-1",
  overworldWildSpawn = true,
  state = "available",
}
local record = { id = "wild-1", state = "available", mapId = "PALLET_TOWN" }
logic.entities[entity.id] = entity
logic.spawns[entity.id] = record
logic.byMap.PALLET_TOWN[1] = entity.id

local state = { entities = { entity }, npcs = { entity } }

assert(Wilds.exports(mod) == exports)
assert(Wilds.isEntity(entity))
assert(Wilds.isBattleable(mod, entity))
assert(Wilds.targetId(entity) == "wild:wild-1")
assert(#Wilds.entities(mod, state) == 1)
local foundRecord, foundLogic, foundId = Wilds.record(mod, entity)
assert(foundRecord == record and foundLogic == logic and foundId == entity.id)
assert(Wilds.defeat(mod, state, entity))
assert(entity.tlozDefeated and entity.wildsDefeated)
assert(entity.state == Wilds.REMOVED_STATE)
assert(record.state == Wilds.REMOVED_STATE)
assert(logic.entities[entity.id] == nil)
assert(logic.spawns[entity.id] == nil)
assert(#logic.byMap.PALLET_TOWN == 0)
assert(logic.recounted)
assert(#state.entities == 0 and #state.npcs == 0)

print("tloz-recomp-mania wilds compatibility tests passed")
