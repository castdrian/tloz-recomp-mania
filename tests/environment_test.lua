local Environment = require("environment")

assert(Environment.rupeeValue("green") == 1)
assert(Environment.rupeeValue("blue") == 5)
assert(Environment.rupeeValue("red") == 20)
assert(Environment.dropType(function() return 0.2 end, "grass") == nil)
assert(Environment.dropType(function() return 0.05 end, "grass") == "green")
assert(Environment.dropType(function()
  return 0.05
end, "pot") == "green")

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
assert(rupee and rupee.value == 1)
assert(sounds[1] == "TLOZ_POT_BREAK")
assert(sounds[2] == "TLOZ_RUPEE_DROP")

player.cellX, player.cellY = rupee.cellX, rupee.cellY
player.px, player.py = rupee.px, rupee.py
environment:update(state, 1 / 60)
assert(game.save.money == 11)
assert(sounds[3] == "TLOZ_RUPEE_COLLECT")

assert(environment:cutGrass(state, 2, 2))
assert(not environment:cutGrass(state, 2, 2))
assert(persisted.environment.maps.TEST_HOUSE.cutGrass["2:2"])
assert(sounds[4] == "TLOZ_GRASS_CUT")

print("tloz-recomp-mania environment tests passed")
