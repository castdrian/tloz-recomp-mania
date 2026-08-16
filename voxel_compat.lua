local VoxelCompat = {}

function VoxelCompat.prepare(sprite, imagePath)
  if not sprite then return nil end
  local definition = sprite.def
  if type(definition) ~= "table" then
    definition = {}
    sprite.def = definition
  end
  definition.image = definition.image or imagePath
  definition.frames = definition.frames or 1
  definition.trueColor = true
  if type(sprite.resolveImage) ~= "function" then
    function sprite:resolveImage()
      return self.image
    end
  end
  return sprite
end

return VoxelCompat
