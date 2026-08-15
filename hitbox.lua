local Hitbox = {}

local DIRECTIONS = {
  up = { 0, -1, 1, 0 },
  down = { 0, 1, 1, 0 },
  left = { -1, 0, 0, 1 },
  right = { 1, 0, 0, 1 },
}

local function occupies(npc, x, y)
  return (npc.cellX == x and npc.cellY == y)
    or (npc.targetX == x and npc.targetY == y)
end

function Hitbox.cells(player)
  local direction = DIRECTIONS[player.facing] or DIRECTIONS.down
  local dx, dy, lateralX, lateralY = direction[1], direction[2],
    direction[3], direction[4]
  local frontX = player.cellX + dx
  local frontY = player.cellY + dy
  return {
    { frontX, frontY },
    { frontX + lateralX, frontY + lateralY },
    { frontX - lateralX, frontY - lateralY },
    { player.cellX + lateralX, player.cellY + lateralY },
    { player.cellX - lateralX, player.cellY - lateralY },
    { frontX + dx, frontY + dy },
    { frontX + dx + lateralX, frontY + dy + lateralY },
    { frontX + dx - lateralX, frontY + dy - lateralY },
  }
end

function Hitbox.roundaboutCells(player)
  local x, y = player.cellX, player.cellY
  return {
    { x - 1, y - 1 },
    { x, y - 1 },
    { x + 1, y - 1 },
    { x - 1, y },
    { x + 1, y },
    { x - 1, y + 1 },
    { x, y + 1 },
    { x + 1, y + 1 },
  }
end

function Hitbox.target(player, npcs, valid, roundabout)
  local cells = roundabout and Hitbox.roundaboutCells(player)
    or Hitbox.cells(player)
  for _, cell in ipairs(cells) do
    for _, npc in ipairs(npcs or {}) do
      if (not valid or valid(npc)) and occupies(npc, cell[1], cell[2]) then
        return npc
      end
    end
  end
  return nil
end

return Hitbox
