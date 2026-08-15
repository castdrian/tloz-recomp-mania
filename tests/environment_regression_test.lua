local Hitbox = require("hitbox")
local Environment = require("environment")

local player = { cellX = 5, cellY = 5, facing = "right" }
local roundabout = Hitbox.roundaboutCells(player)
assert(#roundabout == 8)
local roundaboutCells = {}
for _, cell in ipairs(roundabout) do
  roundaboutCells[Environment.cellKey(cell[1], cell[2])] = true
end
for y = 4, 6 do
  for x = 4, 6 do
    if not (x == player.cellX and y == player.cellY) then
      assert(roundaboutCells[Environment.cellKey(x, y)])
    end
  end
end

local standingMap = {
  id = "STANDING_GRASS",
  def = { id = "STANDING_GRASS", tileset = "OVERWORLD", width = 3, height = 3,
    objects = {} },
  widthCells = 6,
  heightCells = 6,
}
function standingMap:isGrassCell(x, y)
  return (x == 2 and y == 2) or (x == 3 and y == 2)
end
local standingSave = {
  get = function(_, _, default) return default end,
  set = function() end,
}
local standingPlayer = { cellX = 2, cellY = 2, facing = "right" }
local standingState = {
  map = standingMap,
  player = standingPlayer,
  npcs = {},
  entities = { standingPlayer },
}
local standingEnvironment = Environment.new({
  save = standingSave,
  game = { save = { money = 0 } },
  random = function() return 0.99 end,
})
standingEnvironment:enterMap(standingState, standingMap)
assert(standingEnvironment:hit(standingState, {
  cutGrass = true,
  cells = { { 3, 2 } },
}))
assert(standingState.tlozEnvironmentMapState.cutGrass["2:2"])

local compactMap = {
  id = "COMPACT_HOUSE",
  def = { id = "COMPACT_HOUSE", tileset = "HOUSE", width = 2, height = 2,
    objects = {} },
  widthCells = 4,
  heightCells = 4,
}
function compactMap:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 3 and y < 3
end
function compactMap:isCounterCell() return false end
function compactMap:warpAtCell() return nil end
function compactMap:signAtCell() return nil end
local compactPots = Environment.findPotCells(compactMap, {}, nil, function() return 0 end)
assert(#compactPots >= 2)
local compactPlayer = { cellX = 1, cellY = 1 }
local compactState = {
  map = compactMap,
  player = compactPlayer,
  npcs = {},
  entities = { compactPlayer },
}
local compactEnvironment = Environment.new({
  save = standingSave,
  game = { save = { money = 0 } },
})
compactEnvironment:enterMap(compactState, compactMap)
local compactEntities = 0
for _, entity in ipairs(compactState.entities) do
  if entity.tlozEnvironmentType == "pot" then compactEntities = compactEntities + 1 end
end
assert(compactEntities >= 2)

print("tloz-recomp-mania environment regression tests passed")
