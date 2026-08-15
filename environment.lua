local Environment = {}

Environment.GRASS_DROP_CHANCE = 0.5
Environment.POT_DROP_CHANCE = 0.2
Environment.NPC_KILL_RED_DROP_CHANCE = 0.01
Environment.MONEY_CAP = 999999
Environment.RUPEE_VALUES = {
  green = 1,
  blue = 5,
  red = 20,
}

local EFFECT_FRAMES = {
  grass = 18,
  pot = 18,
}

local EFFECT_FRAME_LENGTH = 3
local RUPEE_BOB = { 0, -1, -2, -1 }

local function defaultRandom()
  if love and love.math and love.math.random then
    return love.math.random()
  end
  return math.random()
end

local function clampRandom(value)
  value = tonumber(value) or 0
  if value < 0 then return 0 end
  if value >= 1 then return 0.999999 end
  return value
end

local function copyList(list)
  local result = {}
  for index, value in ipairs(list or {}) do result[index] = value end
  return result
end

local function cellPattern(map, x, y)
  local result = {}
  for row = 0, 1 do
    for column = 0, 1 do
      result[#result + 1] = map:tileAt(x * 2 + column, y * 2 + row)
    end
  end
  return result
end

local function mapCellKey(x, y)
  return tostring(x) .. ":" .. tostring(y)
end

local function parseCellKey(key)
  local x, y = tostring(key):match("^(%-?%d+):(%-?%d+)$")
  return tonumber(x), tonumber(y)
end

local function mapId(map)
  return map and (map.id or (map.def and map.def.id))
end

local function mapDefinition(map)
  return map and (map.def or map)
end

local function objectCellKey(object)
  local x = object and (object.x or object.cellX)
  local y = object and (object.y or object.cellY)
  if type(x) ~= "number" or type(y) ~= "number" then
    return nil
  end
  return mapCellKey(x, y)
end

local function houseName(id)
  return id and (id:find("HOUSE", 1, true) ~= nil
    or id:find("MANSION", 1, true) ~= nil)
end

function Environment.cellKey(x, y)
  return mapCellKey(x, y)
end

function Environment.rupeeValue(color)
  return Environment.RUPEE_VALUES[color] or 0
end

function Environment.rupeeType(random)
  local roll = clampRandom((random or defaultRandom)())
  if roll < 0.7 then return "green" end
  if roll < 0.95 then return "blue" end
  return "red"
end

function Environment.rollDrop(random, chance)
  return clampRandom((random or defaultRandom)()) < chance
end

function Environment.dropType(random, source)
  if source == "npc" then
    if Environment.rollDrop(random, Environment.NPC_KILL_RED_DROP_CHANCE) then
      return "red"
    end
    return nil
  end
  local chance = source == "pot"
    and Environment.POT_DROP_CHANCE or Environment.GRASS_DROP_CHANCE
  if not Environment.rollDrop(random, chance) then return nil end
  return Environment.rupeeType(random)
end

function Environment.isHouseMap(map)
  local definition = mapDefinition(map)
  local id = mapId(map)
  if not definition or not id then return false end
  if id:find("POKEMON_MANSION", 1, true) then return false end
  return houseName(id) or definition.tileset == "HOUSE"
    or definition.tileset == "REDS_HOUSE"
end

function Environment.potCount(candidateCount)
  if candidateCount <= 0 then return 0 end
  return math.min(4, math.max(2, math.floor(candidateCount / 12)))
end

function Environment.seedFor(value)
  local seed = 17
  value = tostring(value or "")
  for index = 1, #value do
    seed = (seed * 131 + value:byte(index)) % 2147483647
  end
  return seed
end

function Environment.randomFor(seed)
  local value = (tonumber(seed) or 1) % 2147483647
  if value <= 0 then value = 1 end
  return function()
    value = (value * 48271) % 2147483647
    return value / 2147483647
  end
end

function Environment.findPotCells(map, objects, count, random)
  local definition = mapDefinition(map)
  if not definition or not map or not map.isWalkableCell then return {} end
  local blocked = {}
  for _, object in ipairs(definition.objects or {}) do
    local key = objectCellKey(object)
    if key then blocked[key] = true end
  end
  for _, object in ipairs(objects or {}) do
    local key = objectCellKey(object)
    if key then blocked[key] = true end
  end
  local candidates = {}
  local width = tonumber(map.widthCells) or ((definition.width or 0) * 2)
  local height = tonumber(map.heightCells) or ((definition.height or 0) * 2)
  for y = 1, height - 2 do
    for x = 1, width - 2 do
      local key = mapCellKey(x, y)
      local counter = map.isCounterCell and map:isCounterCell(x, y)
      local warp = map.warpAtCell and map:warpAtCell(x, y)
      local sign = map.signAtCell and map:signAtCell(x, y)
      if not blocked[key] and not counter and not warp and not sign
         and map:isWalkableCell(x, y) then
        candidates[#candidates + 1] = { x = x, y = y }
      end
    end
  end
  local rng = random or defaultRandom
  for index = #candidates, 2, -1 do
    local other = math.floor(clampRandom(rng()) * index) + 1
    candidates[index], candidates[other] = candidates[other], candidates[index]
  end
  local result = {}
  local selected = {}
  local desired = math.min(tonumber(count) or Environment.potCount(#candidates),
    #candidates)
  for _, candidate in ipairs(candidates) do
    if #result >= desired then break end
    local separated = true
    for _, chosen in ipairs(result) do
      if math.abs(candidate.x - chosen.x) + math.abs(candidate.y - chosen.y) < 3 then
        separated = false
        break
      end
    end
    if separated then
      result[#result + 1] = candidate
      selected[mapCellKey(candidate.x, candidate.y)] = true
    end
  end
  if #result < desired then
    for _, candidate in ipairs(candidates) do
      if #result >= desired then break end
      local key = mapCellKey(candidate.x, candidate.y)
      if not selected[key] then
        result[#result + 1] = candidate
        selected[key] = true
      end
    end
  end
  return result
end

local function removeEntity(state, entity)
  for index = #state.entities, 1, -1 do
    if state.entities[index] == entity then
      table.remove(state.entities, index)
      return true
    end
  end
  return false
end

local function storageState(save, fallback)
  local value = save and save:get("environment", nil) or fallback
  if type(value) ~= "table" then value = {} end
  value.maps = type(value.maps) == "table" and value.maps or {}
  return value
end

local function normalizeMapState(value)
  value = type(value) == "table" and value or {}
  value.cutGrass = type(value.cutGrass) == "table" and value.cutGrass or {}
  value.pots = type(value.pots) == "table" and value.pots or {}
  return value
end

function Environment.new(config)
  config = config or {}
  local self = setmetatable({
    mod = config.mod,
    save = config.save,
    game = config.game,
    playSound = config.play,
    palette = config.palette,
    random = config.random or defaultRandom,
    stateData = storageState(config.save, config.state),
    images = {},
    activeMapId = nil,
    activeMapState = nil,
    activePots = {},
  }, { __index = Environment })
  return self
end

function Environment:saveState()
  if self.save then self.save:set("environment", self.stateData) end
end

function Environment:adoptSave()
  self.stateData = storageState(self.save, self.stateData)
  self.activeMapId = nil
  self.activeMapState = nil
  self.activePots = {}
end

function Environment:mapState(map)
  local id = mapId(map)
  local value = normalizeMapState(self.stateData.maps[id])
  self.stateData.maps[id] = value
  return value
end

function Environment:image(name)
  if self.images[name] ~= nil then return self.images[name] or nil end
  if not self.mod or not self.mod.assets or not self.mod.assets.image then
    self.images[name] = false
    return nil
  end
  local ok, image = pcall(function()
    return self.mod.assets:image("assets/sprites/environment/" .. name .. ".png")
  end)
  self.images[name] = ok and image or false
  return self.images[name] or nil
end

function Environment:markTrueColor(x, y, width, height)
  if self.palette and self.palette.markTrueColor then
    self.palette.markTrueColor(x, y, width, height)
  end
end

function Environment:drawImage(image, x, y, scale)
  if not image or not love or not love.graphics then return end
  scale = scale or 1
  local width, height = image:getWidth(), image:getHeight()
  love.graphics.draw(image, x, y, 0, scale, scale)
  self:markTrueColor(x, y, width * scale, height * scale)
end

function Environment:replaceGrassCell(map, x, y)
  if not (map and map.def and map.tileset and map.tileset.blocks
          and map.def.blocks and map.tileAt) then return false end
  if not map:isGrassCell(x, y) then return false end
  local source
  for radius = 1, 8 do
    for dy = -radius, radius do
      for dx = -radius, radius do
        if math.abs(dx) + math.abs(dy) == radius then
          local sx, sy = x + dx, y + dy
          if map:inBounds(sx, sy) and map:isWalkableCell(sx, sy)
             and not map:isGrassCell(sx, sy) then
            source = cellPattern(map, sx, sy)
            break
          end
        end
      end
      if source then break end
    end
    if source then break end
  end
  if not source then return false end
  local blockX, blockY = math.floor(x / 2), math.floor(y / 2)
  local blockIndex = blockY * map.def.width + blockX + 1
  local blockId = map.def.blocks[blockIndex]
  local original = map.tileset.blocks[blockId + 1]
  if not original then return false end
  local replacement = copyList(original)
  local localX, localY = x % 2, y % 2
  local tileX, tileY = localX * 2, localY * 2
  for row = 0, 1 do
    for column = 0, 1 do
      local blockOffset = (tileY + row) * 4 + tileX + column + 1
      replacement[blockOffset] = source[row * 2 + column + 1]
    end
  end
  local replacementId = #map.tileset.blocks
  map.tileset.blocks[replacementId + 1] = replacement
  map.def.blocks[blockIndex] = replacementId
  if map.renderer and map.renderer.rebuild then map.renderer:rebuild() end
  return true
end

function Environment:applySavedGrass(map, mapState)
  for key, value in pairs(mapState.cutGrass or {}) do
    if value then
      local x, y = parseCellKey(key)
      if x and y then self:replaceGrassCell(map, x, y) end
    end
  end
end

function Environment:createPot(map, pot)
  local environment = self
  local entity = {
    tlozEnvironment = true,
    tlozEnvironmentType = "pot",
    cellX = pot.x,
    cellY = pot.y,
    px = pot.x * 16,
    py = pot.y * 16,
    passable = false,
  }
  function entity:draw(camX, camY)
    local image = environment:image("pot")
    if not image then return end
    local width, height = image:getWidth(), image:getHeight()
    local x = math.floor(self.px - camX + (16 - width) / 2)
    local y = math.floor(self.py - camY + 16 - height)
    environment:drawImage(image, x, y)
  end
  return entity
end

function Environment:createRupee(color, x, y)
  local environment = self
  local entity = {
    tlozEnvironment = true,
    tlozEnvironmentType = "rupee",
    color = color,
    value = Environment.rupeeValue(color),
    cellX = x,
    cellY = y,
    px = x * 16,
    py = y * 16,
    passable = true,
    age = 0,
  }
  function entity:draw(camX, camY)
    local image = environment:image("rupee_" .. self.color)
    if not image then return end
    local bob = RUPEE_BOB[math.floor(self.age / 6) % #RUPEE_BOB + 1]
    local width, height = image:getWidth(), image:getHeight()
    local x = math.floor(self.px - camX + (16 - width) / 2)
    local y = math.floor(self.py - camY + (16 - height) / 2 + bob)
    environment:drawImage(image, x, y)
  end
  return entity
end

function Environment:removeEnvironmentEntities(state)
  for index = #state.entities, 1, -1 do
    if state.entities[index].tlozEnvironment then
      table.remove(state.entities, index)
    end
  end
end

function Environment:enterMap(state, map)
  if not state or not map then return end
  self:removeEnvironmentEntities(state)
  self.activeMapId = mapId(map)
  self.activeMapState = self:mapState(map)
  self.activePots = {}
  self:applySavedGrass(map, self.activeMapState)
  if Environment.isHouseMap(map) then
    local random = Environment.randomFor(Environment.seedFor(self.activeMapId))
    local candidates = Environment.findPotCells(map, state.npcs, nil, random)
    local potCells = {}
    for _, pot in ipairs(self.activeMapState.pots) do
      if type(pot.x) == "number" and type(pot.y) == "number" then
        potCells[mapCellKey(pot.x, pot.y)] = true
      end
    end
    local potsChanged = not self.activeMapState.potsInitialized
    for _, cell in ipairs(candidates) do
      if #self.activeMapState.pots >= #candidates then break end
      local key = mapCellKey(cell.x, cell.y)
      if not potCells[key] then
        self.activeMapState.pots[#self.activeMapState.pots + 1] = {
          x = cell.x,
          y = cell.y,
          destroyed = false,
        }
        potCells[key] = true
        potsChanged = true
      end
    end
    if potsChanged then
      self.activeMapState.potsInitialized = true
      self:saveState()
    end
    for _, pot in ipairs(self.activeMapState.pots) do
      if not pot.destroyed then
        local key = mapCellKey(pot.x, pot.y)
        local entity = self:createPot(map, pot)
        self.activePots[key] = { data = pot, entity = entity }
        state.entities[#state.entities + 1] = entity
      end
    end
  end
  state.tlozEnvironmentMapId = self.activeMapId
  state.tlozEnvironmentMapState = self.activeMapState
  state.tlozEnvironmentEffects = state.tlozEnvironmentEffects or {}
end

function Environment:ensureMap(state)
  if not state or not state.map then return end
  local id = mapId(state.map)
  if self.activeMapId ~= id or state.tlozEnvironmentMapId ~= id then
    self:enterMap(state, state.map)
  end
end

function Environment:spawnEffect(state, kind, x, y)
  state.tlozEnvironmentEffects = state.tlozEnvironmentEffects or {}
  state.tlozEnvironmentEffects[#state.tlozEnvironmentEffects + 1] = {
    kind = kind,
    x = x * 16,
    y = y * 16,
    age = 0,
    duration = EFFECT_FRAMES[kind] or EFFECT_FRAMES.grass,
  }
end

function Environment:spawnRupee(state, color, x, y)
  for _, entity in ipairs(state.entities or {}) do
    if entity.tlozEnvironmentType == "rupee"
       and entity.cellX == x and entity.cellY == y then
      return entity
    end
  end
  local entity = self:createRupee(color, x, y)
  state.entities[#state.entities + 1] = entity
  self:play("TLOZ_RUPEE_DROP")
  return entity
end

function Environment:play(name)
  if self.playSound then self.playSound(name) end
end

function Environment:drop(state, source, x, y)
  local color = Environment.dropType(self.random, source)
  if color then self:spawnRupee(state, color, x, y) end
  return color
end

function Environment:cutGrass(state, x, y)
  self:ensureMap(state)
  local map = state and state.map
  local mapState = self.activeMapState
  if not (map and mapState and map:isGrassCell(x, y)) then return false end
  local key = mapCellKey(x, y)
  if mapState.cutGrass[key] then return false end
  mapState.cutGrass[key] = true
  self:replaceGrassCell(map, x, y)
  self:spawnEffect(state, "grass", x, y)
  self:play("TLOZ_GRASS_CUT")
  self:drop(state, "grass", x, y)
  self:saveState()
  return true
end

function Environment:potAt(x, y)
  return self.activePots[mapCellKey(x, y)]
end

function Environment:destroyPot(state, x, y)
  self:ensureMap(state)
  local found = self:potAt(x, y)
  if not found or found.data.destroyed then return false end
  found.data.destroyed = true
  removeEntity(state, found.entity)
  self:spawnEffect(state, "pot", x, y)
  self:play("TLOZ_POT_BREAK")
  self:drop(state, "pot", x, y)
  self:saveState()
  return true
end

function Environment:hit(state, options)
  options = options or {}
  local player = state and state.player
  if not player then return false end
  local cells = options.cells
  if type(cells) ~= "table" or #cells == 0 then
    local x, y = player:facingCell()
    cells = { { x, y } }
  end
  local targets = {}
  local seen = {}
  local function addTarget(x, y)
    if type(x) ~= "number" or type(y) ~= "number" then return end
    local key = mapCellKey(x, y)
    if seen[key] then return end
    seen[key] = true
    targets[#targets + 1] = { x, y }
  end
  if options.cutGrass and type(player.cellX) == "number"
     and type(player.cellY) == "number" then
    addTarget(player.cellX, player.cellY)
  end
  for _, cell in ipairs(cells) do
    local x = cell[1] or cell.x
    local y = cell[2] or cell.y
    addTarget(x, y)
  end
  for _, target in ipairs(targets) do
    if options.breakPots and self:destroyPot(state, target[1], target[2]) then
      return true
    end
    if options.cutGrass and self:cutGrass(state, target[1], target[2]) then
      return true
    end
  end
  return false
end

function Environment:playerTouches(player, entity)
  if player.cellX == entity.cellX and player.cellY == entity.cellY then
    return true
  end
  if player.targetX == entity.cellX and player.targetY == entity.cellY then
    return true
  end
  local px = (player.px or 0) + 8
  local py = (player.py or 0) + 8
  local ex = entity.px + 8
  local ey = entity.py + 8
  return math.abs(px - ex) <= 6 and math.abs(py - ey) <= 6
end

function Environment:collectRupee(state, entity)
  local save = self.game and self.game.save
  if not save then return false end
  save.money = math.min(Environment.MONEY_CAP,
    (tonumber(save.money) or 0) + entity.value)
  entity.collected = true
  removeEntity(state, entity)
  self:play("TLOZ_RUPEE_COLLECT")
  return true
end

function Environment:update(state, dt)
  self:ensureMap(state)
  local elapsed = tonumber(dt) or 1 / 60
  local frames = math.max(1, elapsed * 60)
  local effects = state.tlozEnvironmentEffects or {}
  for index = #effects, 1, -1 do
    effects[index].age = effects[index].age + frames
    if effects[index].age >= effects[index].duration then
      table.remove(effects, index)
    end
  end
  local player = state.player
  for index = #state.entities, 1, -1 do
    local entity = state.entities[index]
    if entity.tlozEnvironmentType == "rupee" then
      entity.age = entity.age + frames
      if not entity.collected and player and self:playerTouches(player, entity) then
        self:collectRupee(state, entity)
      end
    end
  end
end

function Environment:draw(state, scale)
  if not love or not love.graphics then return end
  local camera = state.camera or { x = 0, y = 0 }
  scale = scale or 1
  for _, effect in ipairs(state.tlozEnvironmentEffects or {}) do
    local frame = math.floor(effect.age / EFFECT_FRAME_LENGTH) + 1
    local imageName = effect.kind == "pot" and "pot_fx_" or "grass_fx_"
    local image = self:image(imageName .. tostring(math.min(frame, 6)))
    if image then
      local width, height = image:getWidth(), image:getHeight()
      local x = math.floor((effect.x - camera.x) * scale
        + (16 * scale - width * scale) / 2)
      local y = math.floor((effect.y - camera.y) * scale
        + (16 * scale - height * scale) / 2)
      self:drawImage(image, x, y, scale)
    end
  end
end

return Environment
