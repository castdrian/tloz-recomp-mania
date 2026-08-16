local Environment = require("environment")

assert(Environment.rupeeValue("green") == 1)
assert(Environment.rupeeValue("blue") == 5)
assert(Environment.rupeeValue("red") == 20)
assert(Environment.rupeeValue("purple") == 50)
assert(Environment.rupeeValue("silver") == 100)
assert(Environment.rupeeValue("gold") == 300)
assert(Environment.pokedollarValue("green") == 10)
assert(Environment.pokedollarValue("blue") == 50)
assert(Environment.pokedollarValue("red") == 200)
assert(Environment.pokedollarValue("purple") == 500)
assert(Environment.pokedollarValue("silver") == 1000)
assert(Environment.pokedollarValue("gold") == 3000)
assert(Environment.GRASS_DROP_CHANCE == 0.5)
assert(Environment.NPC_ITEM_DROP_CHANCE == 0.3)
assert(Environment.NPC_PURPLE_RUPEE_CHANCE == 0.1)
assert(Environment.NPC_SILVER_RUPEE_CHANCE == 0.05)
assert(Environment.NPC_GOLD_RUPEE_CHANCE == 0.01)
local itemPalette = Environment.buildItemPalette({
  POTION = { id = "POTION", name = "POTION" },
  FLOOR_11F = { id = "FLOOR_11F", name = "11F" },
  MASTER_KEY = { id = "MASTER_KEY", name = "MASTER KEY", keyItem = true },
  TM_CUT = { id = "TM_CUT", name = "TM01", machine = {} },
  BADGE_1 = { id = "BADGE_1", name = "BADGE 1" },
})
assert(#itemPalette == 1 and itemPalette[1] == "POTION")
assert(Environment.itemType(function() return 0 end, itemPalette) == "POTION")
local itemKind, itemValue = Environment.killDropType(function() return 0 end,
  itemPalette)
assert(itemKind == "item" and itemValue == "POTION")
local purpleKind, purpleValue = Environment.killDropType(function() return 0.3 end,
  itemPalette)
assert(purpleKind == "rupee" and purpleValue == "purple")
local silverKind, silverValue = Environment.killDropType(function() return 0.4 end,
  itemPalette)
assert(silverKind == "rupee" and silverValue == "silver")
local goldKind, goldValue = Environment.killDropType(function() return 0.4501 end,
  itemPalette)
assert(goldKind == "rupee" and goldValue == "gold")
assert(Environment.killDropType(function() return 0.4601 end, itemPalette) == nil)
assert(Environment.dropType(function() return 0.6 end, "grass") == nil)
assert(Environment.dropType(function() return 0.1 end, "grass") == "green")
assert(Environment.dropType(function()
  return 0.05
end, "pot") == "green")
assert(Environment.dropType(function() return 0 end, "npc") == "purple")
assert(Environment.dropType(function() return 0 end, "wild") == "purple")
assert(Environment.dropType(function() return 0.1 end, "npc") == "silver")
assert(Environment.dropType(function() return 0.1 end, "wild") == "silver")
assert(Environment.dropType(function() return 0.1501 end, "npc") == "gold")
assert(Environment.dropType(function() return 0.1501 end, "wild") == "gold")
assert(Environment.dropType(function() return 0.1601 end, "npc") == nil)
assert(Environment.dropType(function() return 0.1601 end, "wild") == nil)
assert(Environment.rupeeType(function() return 0.98 end) == "purple")
assert(Environment.rupeeType(function() return 0.995 end) == "silver")
assert(Environment.rupeeType(function() return 0.9995 end) == "gold")

local map = {
  id = "TEST_HOUSE",
  def = {
    id = "TEST_HOUSE",
    tileset = "HOUSE",
    width = 6,
    height = 6,
    objects = {
      { x = 4, y = 4 },
    },
  },
  widthCells = 12,
  heightCells = 12,
}

function map:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 11 and y < 11
end

function map:isCounterCell()
  return false
end

function map:warpAtCell()
  return nil
end

function map:signAtCell()
  return nil
end

function map:isGrassCell(x, y)
  return x == 2 and y == 2
end

local first = Environment.findPotCells(map, {}, 3, Environment.randomFor(77))
local second = Environment.findPotCells(map, {}, 3, Environment.randomFor(77))
assert(#first == 3)
assert(#second == #first)
for index = 1, #first do
  assert(first[index].x == second[index].x)
  assert(first[index].y == second[index].y)
end
assert(Environment.isHouseMap(map))
assert(not Environment.isHouseMap({ id = "POKEMON_MANSION_1F", def = {} }))
assert(Environment.potCount(36) == 3)

local migrationPersisted = {
  environment = {
    maps = {
      TEST_HOUSE = {
        cutGrass = {},
        pots = { { x = 1, y = 1, destroyed = false } },
        potsInitialized = true,
      },
    },
  },
}
local migrationSave = {
  get = function(_, key, default)
    if migrationPersisted[key] == nil then return default end
    return migrationPersisted[key]
  end,
  set = function(_, key, value)
    migrationPersisted[key] = value
  end,
}
local migrationEnvironment = Environment.new({
  save = migrationSave,
  random = Environment.randomFor(77),
})
local migrationPlayer = { cellX = 1, cellY = 1 }
local migrationState = {
  map = map,
  player = migrationPlayer,
  npcs = {},
  entities = { migrationPlayer },
}
migrationEnvironment:enterMap(migrationState, map)
local migrationPotCount = 0
for _, entity in ipairs(migrationState.entities) do
  if entity.tlozEnvironmentType == "pot" then
    migrationPotCount = migrationPotCount + 1
  end
end
assert(migrationPotCount >= 2)

local persisted = {}
local save = {
  get = function(_, key, default)
    if persisted[key] == nil then return default end
    return persisted[key]
  end,
  set = function(_, key, value)
    persisted[key] = value
  end,
}
local game = { save = { money = 10 } }
local sounds = {}
local environment = Environment.new({
  save = save,
  game = game,
  random = function() return 0.05 end,
  play = function(name) sounds[#sounds + 1] = name end,
})
local player = {
  cellX = 1,
  cellY = 1,
  px = 16,
  py = 16,
  facingCell = function() return 2, 1 end,
}
local state = { map = map, player = player, npcs = {}, entities = { player } }

environment:enterMap(state, map)
assert(#state.entities == 5)
local pot = state.entities[2]
assert(pot.tlozEnvironmentType == "pot")
assert(environment:destroyPot(state, pot.cellX, pot.cellY))
assert(pot.data == nil)
local rupee
for _, entity in ipairs(state.entities) do
  if entity.tlozEnvironmentType == "rupee" then rupee = entity end
end
assert(rupee and rupee.value == 10)
assert(sounds[1] == "TLOZ_POT_BREAK")
assert(sounds[2] == "TLOZ_RUPEE_DROP")

player.cellX, player.cellY = rupee.cellX, rupee.cellY
player.px, player.py = rupee.px, rupee.py
environment:update(state, 1 / 60)
assert(game.save.money == 20)
assert(sounds[3] == "TLOZ_RUPEE_COLLECT")

local carriedPot
for _, entity in ipairs(state.entities) do
  if entity.tlozEnvironmentType == "pot" then carriedPot = entity break end
end
assert(carriedPot)
player.facingCell = function() return carriedPot.cellX, carriedPot.cellY end
assert(environment:potAtFacing(state) == environment:potAt(
  carriedPot.cellX, carriedPot.cellY))
assert(environment:pickUpPot(state))
assert(environment:isHoldingPot(state))
local carriedPotPresent = false
for _, entity in ipairs(state.entities) do
  if entity == carriedPot then carriedPotPresent = true end
end
assert(not carriedPotPresent)
player.facingCell = function() return 3, 1 end
assert(environment:throwPot(state))
assert(not environment:isHoldingPot(state))

local itemInventory = {}
local itemSounds = {}
local itemGame = {
  data = {
    items = {
      POTION = { id = "POTION", name = "POTION" },
      MASTER_KEY = { id = "MASTER_KEY", name = "MASTER KEY", keyItem = true },
    },
  },
  save = { money = 0, inventory = itemInventory },
}
local itemEnvironment = Environment.new({
  game = itemGame,
  bag = {
    add = function(saveData, id, quantity)
      saveData.inventory[id] = (saveData.inventory[id] or 0) + quantity
      return true
    end,
  },
  random = function() return 0.05 end,
  play = function(name) itemSounds[#itemSounds + 1] = name end,
})
local itemState = { player = player, entities = { player } }
assert(itemEnvironment:drop(itemState, "npc", 3, 3) == "POTION")
local itemDrop
local itemDropCount = 0
for _, entity in ipairs(itemState.entities) do
  if entity.tlozEnvironmentType == "item" then
    itemDrop = entity
    itemDropCount = itemDropCount + 1
  end
  assert(entity.tlozEnvironmentType ~= "rupee")
end
assert(itemDrop and itemDropCount == 1)
player.cellX, player.cellY = itemDrop.cellX, itemDrop.cellY
itemEnvironment:collectItem(itemState, itemDrop)
assert(itemInventory.POTION == 1)
assert(itemSounds[1] == "TLOZ_LINK_PICKUP")

local wildItemState = { player = player, entities = { player } }
assert(itemEnvironment:drop(wildItemState, "wild", 6, 6) == "POTION")
local wildItemDrop
for _, entity in ipairs(wildItemState.entities) do
  if entity.tlozEnvironmentType == "item" then wildItemDrop = entity end
end
assert(wildItemDrop and wildItemDrop.item == "POTION")

local exclusiveState = { player = player, entities = { player } }
local exclusiveEnvironment = Environment.new({
  game = { save = { money = 0 } },
  itemPalette = { "POTION" },
  random = function() return 0.4001 end,
})
assert(exclusiveEnvironment:drop(exclusiveState, "wild", 4, 4) == "silver")
local exclusiveRupee
for _, entity in ipairs(exclusiveState.entities) do
  if entity.tlozEnvironmentType == "rupee" then exclusiveRupee = entity end
  assert(entity.tlozEnvironmentType ~= "item")
end
assert(exclusiveRupee and exclusiveRupee.color == "silver")

local reachSave = {
  get = function(_, _, default) return default end,
  set = function() end,
}
local reachEnvironment = Environment.new({
  save = reachSave,
  game = game,
  random = function() return 0.05 end,
  play = function(name) sounds[#sounds + 1] = name end,
})
local reachPlayer = {
  cellX = 1,
  cellY = 2,
  facingCell = function() return 1, 1 end,
}
local reachState = {
  map = map,
  player = reachPlayer,
  npcs = {},
  entities = { reachPlayer },
}
reachEnvironment:enterMap(reachState, map)
assert(reachEnvironment:hit(reachState, {
  cutGrass = true,
  cells = { { 1, 1 }, { 2, 1 }, { 0, 1 }, { 2, 2 }, { 0, 2 } },
}))
assert(reachEnvironment:cutGrass(reachState, 2, 2) == false)

local occupiedMap = {
  id = "OCCUPIED_HOUSE",
  def = { id = "OCCUPIED_HOUSE", tileset = "HOUSE", width = 3, height = 3,
    objects = {} },
  widthCells = 6,
  heightCells = 6,
}
function occupiedMap:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 5 and y < 5
end
function occupiedMap:isCounterCell() return false end
function occupiedMap:warpAtCell() return nil end
function occupiedMap:signAtCell() return nil end
function occupiedMap:isGrassCell(x, y) return x == 2 and y == 2 end
local occupiedPlayer = {
  cellX = 2,
  cellY = 2,
  facingCell = function() return 2, 3 end,
}
local occupiedState = {
  map = occupiedMap,
  player = occupiedPlayer,
  npcs = {},
  entities = { occupiedPlayer },
}
local occupiedEnvironment = Environment.new({
  save = save,
  game = game,
  random = function() return 0.99 end,
})
occupiedEnvironment:enterMap(occupiedState, occupiedMap)
assert(occupiedEnvironment:hit(occupiedState, {
  cutGrass = true,
  cells = { { 2, 3 } },
}))
assert(not occupiedEnvironment:cutGrass(occupiedState, 2, 2))

assert(environment:cutGrass(state, 2, 2))
assert(not environment:cutGrass(state, 2, 2))
assert(persisted.environment.maps.TEST_HOUSE.cutGrass["2:2"])
local grassSound
for _, name in ipairs(sounds) do
  if name == "TLOZ_GRASS_CUT" then grassSound = name end
end
assert(grassSound == "TLOZ_GRASS_CUT")

local originalLove = _G.love
local rupeeDraws = {}
_G.love = {
  graphics = {
    draw = function(image, x, y, rotation, sx, sy)
      rupeeDraws[#rupeeDraws + 1] = {
        image = image, x = x, y = y, rotation = rotation, sx = sx, sy = sy,
      }
    end,
  },
}
local rupeeImage = {
  getWidth = function() return 18 end,
  getHeight = function() return 18 end,
}
local drawEnvironment = Environment.new({
  mod = { assets = { image = function() return rupeeImage end } },
})
local visualRupee = drawEnvironment:createRupee("green", 2, 2)
visualRupee:draw(0, 0)
assert(#rupeeDraws == 1)
assert(rupeeDraws[1].sx == 7 / 9 and rupeeDraws[1].sy == 7 / 9)
_G.love = originalLove

print("tloz-recomp-mania environment tests passed")
