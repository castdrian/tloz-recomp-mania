local WarpEffects = {}

function WarpEffects.fallSound(world, payload)
  if not (world and world.map and world.player and payload and payload.warp) then
    return nil
  end
  local map = world.map
  local player = world.player
  if not map.warpPadOrHoleAt then return nil end
  if map:warpPadOrHoleAt(player.cellX, player.cellY) == "hole" then
    return "TLOZ_LINK_FALL"
  end
  return nil
end

return WarpEffects
