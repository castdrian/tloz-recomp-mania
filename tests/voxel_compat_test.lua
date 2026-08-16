local VoxelCompat = assert(dofile("voxel_compat.lua"))

local firstImage = {}
local sprite = { image = firstImage }
assert(VoxelCompat.prepare(sprite, "fallback.png") == sprite)
assert(sprite.def.image == "fallback.png")
assert(sprite.def.frames == 1)
assert(sprite.def.trueColor)
assert(sprite:resolveImage() == firstImage)

local secondImage = {}
sprite.image = secondImage
assert(sprite:resolveImage() == secondImage)

local existing = {
  image = firstImage,
  def = { image = "existing.png", frames = 2 },
}
VoxelCompat.prepare(existing, "fallback.png")
assert(existing.def.image == "existing.png")
assert(existing.def.frames == 2)
assert(existing.def.trueColor)
assert(existing:resolveImage() == firstImage)

print("voxel compatibility tests passed")
