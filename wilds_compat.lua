local Wilds = {}

Wilds.DEPENDENCY_ID = "overworld_wild_spawns"
Wilds.REMOVED_STATE = "removed"

local function findDependency(mod)
  if not mod or type(mod.find) ~= "function" then return nil end
  local ok, handle = pcall(mod.find, Wilds.DEPENDENCY_ID)
  if ok and handle then return handle end
  ok, handle = pcall(mod.find, mod, Wilds.DEPENDENCY_ID)
  if ok then return handle end
  return nil
end

local function dependencyExports(mod)
  local handle = findDependency(mod)
  return handle and handle.exports or nil
end

local function entityId(entity)
  return entity and (entity.spawnId or entity.id)
end

local function removeFromList(list, entity)
  for index = #list, 1, -1 do
    local entry = list[index]
    if entry == entity or (entity.id and entry and entry.id == entity.id) then
      table.remove(list, index)
    end
  end
end

local function removeId(list, id)
  for index = #list, 1, -1 do
    if list[index] == id then table.remove(list, index) end
  end
end

function Wilds.exports(mod)
  return dependencyExports(mod)
end

function Wilds.isEntity(entity)
  return entity and entity.overworldWildSpawn == true
end

function Wilds.isBattleable(mod, entity)
  if not Wilds.isEntity(entity) or entity.tlozDefeated then return false end
  local exports = dependencyExports(mod)
  local checker = exports and exports.isBattleableWild
  if type(checker) ~= "function" then return false end
  local ok, battleable = pcall(checker, entity)
  return ok and battleable == true
end

function Wilds.targetId(entity)
  local id = entityId(entity)
  if id == nil then return nil end
  return "wild:" .. tostring(id)
end

function Wilds.entities(mod, state)
  local result = {}
  local seen = {}
  local function add(entity)
    if not Wilds.isEntity(entity) or seen[entity] then return end
    seen[entity] = true
    result[#result + 1] = entity
  end
  for _, entity in ipairs(state and state.entities or {}) do add(entity) end
  for _, entity in ipairs(state and state.npcs or {}) do add(entity) end
  local exports = dependencyExports(mod)
  local logic = exports and exports.logic
  for _, entity in pairs(logic and logic.entities or {}) do add(entity) end
  return result
end

function Wilds.record(mod, entity)
  local id = entityId(entity)
  if id == nil then return nil, nil, nil end
  local exports = dependencyExports(mod)
  local logic = exports and exports.logic
  local record = logic and logic.spawns and logic.spawns[id]
  return record, logic, id
end

function Wilds.defeat(mod, state, entity)
  if not Wilds.isEntity(entity) then return false end
  entity.tlozDefeated = true
  entity.wildsDefeated = true
  entity.frozen = true
  entity.canTriggerBattle = false
  entity.state = Wilds.REMOVED_STATE

  local record, logic, id = Wilds.record(mod, entity)
  if record then record.state = Wilds.REMOVED_STATE end
  local despawned = false
  if logic and record and type(logic._despawn) == "function" then
    local ok = pcall(logic._despawn, logic, record.id or id, true)
    despawned = ok
  end

  if logic and id ~= nil then
    if logic.entities then logic.entities[id] = nil end
    if logic.spawns and not despawned then logic.spawns[id] = nil end
    if logic.byMap and not despawned then
      for _, ids in pairs(logic.byMap) do removeId(ids, id) end
    end
  end
  if logic and type(logic._recountRegions) == "function" then
    pcall(logic._recountRegions, logic)
  end

  removeFromList(state and state.entities or {}, entity)
  removeFromList(state and state.npcs or {}, entity)
  return true
end

return Wilds
