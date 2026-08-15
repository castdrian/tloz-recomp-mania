local VoxelPlayer = assert(dofile("voxel_player.lua"))

local identity = {
  1, 0, 0, 0,
  0, 1, 0, 0,
  0, 0, 1, 0,
  0, 0, 0, 1,
}

local modelSource = [[
local identity = {1,0,0,0,0,1,0,0,0,0,1,0,0,0,0,1}
local mesh = {vertices={{0,0,0,0,0,1}},indices={1},weights={1,1,0,0,0,0,0,0}}
return {
  version=1, scale=1, bones={"root"},
  body=mesh,
  props={
    sword={bone=1,mesh=mesh},
    shield={bone=1,mesh=mesh},
  },
  actions={
    idle={frames={{identity}}},
    walk={frames={{identity}}},
    sword={frames={{identity}}},
  },
}
]]

local registered
local images = {}
local mod = {
  path = ".",
  read = function(_, name)
    if name == "assets/models/chibi_link.lua" then return modelSource end
    return nil
  end,
  assets = {
    image = function(_, path)
      images[#images + 1] = path
      return { path = path }
    end,
  },
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return {
      exports = {
        registerEntityModel = function(idValue, callback, priority)
          registered = { id = idValue, callback = callback, priority = priority }
        end,
      },
    }
  end,
  log = { warn = function() end },
}

local player = VoxelPlayer.new(mod)
assert(player:install())
assert(registered.id == "tloz-recomp-mania.chibi-link")
assert(registered.priority == 1000)
assert(#images == 2)

local sprite = {}
player:mark(sprite, {
  kind = "sword",
  frame = 1,
  maxFrame = 3,
  clock = 4,
})
assert(sprite.tlozChibiLink)
assert(sprite.def.tlozChibiLink)

local meshes = {}
local draws = {}
local mat4 = {
  translate = function(x, y, z) return { x = x, y = y, z = z } end,
  rotateY = function(angle) return { angle = angle } end,
  mul = function(a, b) return { left = a, right = b } end,
}
local function newMesh(vertices, indices)
  local mesh = { vertices = vertices, indices = indices }
  meshes[#meshes + 1] = mesh
  return mesh
end
local context = {
  pass = "scene",
  sprite = sprite,
  px = 16,
  py = 32,
  facing = "right",
  phase = 0,
  ground = 2,
  lift = 1,
  pull = 4,
  mat4 = mat4,
  newMesh = newMesh,
  draw = function(mesh, texture, model, pull, sunModel)
    draws[#draws + 1] = {
      mesh = mesh, texture = texture, model = model,
      pull = pull, sunModel = sunModel,
    }
  end,
  shadow = function() end,
}
assert(registered.callback(context))
assert(#meshes == 3)
assert(#draws == 3)
assert(draws[1].texture.path == "assets/models/chibi_link_base_color.png")
assert(draws[2].texture.path == "assets/models/chibi_link_props_base_color.png")
assert(draws[1].model.left.x == 24)
assert(draws[1].model.left.y == 3)
assert(draws[1].model.left.z == 40)

assert(registered.callback(context))
assert(#meshes == 3)
assert(#draws == 6)

local legacyDraws = {}
local legacyEntityCalls = 0
local legacyGhostCalls = 0
local function drawEntity(spriteValue)
  legacyEntityCalls = legacyEntityCalls + 1
end
local function drawCast(spriteValue, px, py, facing, phase, flip,
                        ground, colors, lift)
  return drawEntity(spriteValue, px, py, facing, phase, flip, ground,
    colors, lift)
end
local function drawGhost(poseValue)
  legacyGhostCalls = legacyGhostCalls + 1
end
local function legacyRender(spriteValue)
  assert(spriteValue.def and spriteValue.def.image)
  drawCast(spriteValue, 0, 0, "down", 0, false, 0, nil, 0)
  drawGhost({
    sprite = spriteValue, px = 0, py = 0, facing = "down", phase = 0,
    flip = false, gh = 0, colors = nil, lift = 0,
  })
end

local legacyBillboards = {
  shadowQuad = function() return {} end,
}
local legacyVoxel = {
  newMesh = newMesh,
  draw = function(mesh)
    legacyDraws[#legacyDraws + 1] = mesh
  end,
}
local legacyMat4 = mat4
local legacyShadow = {
  draw = function() end,
  snug = function(model) return model end,
}
local legacyState = { angle = 0.2 }
local legacyModules = {
  VoxelScene = { render = legacyRender, pull = function() return 3 end },
  Voxel3D = legacyVoxel,
  Mat4 = legacyMat4,
  ShadowMap = legacyShadow,
  VoxelState = legacyState,
  SpriteBillboards = legacyBillboards,
}
local legacyMod = {
  path = ".",
  read = mod.read,
  assets = mod.assets,
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return { exports = { lib = {
      require = function(name) return legacyModules[name] end,
    } } }
  end,
  log = { warn = function() end },
}
local legacyPlayer = VoxelPlayer.new(legacyMod)
assert(legacyPlayer:install())
legacyRender(sprite)
assert(legacyEntityCalls == 0)
assert(legacyGhostCalls == 0)
assert(#legacyDraws == 6)

local partialBillboards = { shadowQuad = function() return {} end }
local partialModules = {
  VoxelScene = { render = function() end, pull = function() return 3 end },
  Voxel3D = legacyVoxel,
  Mat4 = legacyMat4,
  ShadowMap = legacyShadow,
  VoxelState = legacyState,
  SpriteBillboards = partialBillboards,
}
local partialMod = {
  path = ".",
  read = mod.read,
  assets = mod.assets,
  find = function(id)
    if id ~= "DRAMALESS_SHAPE" then return nil end
    return { exports = { lib = {
      require = function(name) return partialModules[name] end,
    } } }
  end,
  log = { warn = function() end },
}
local partialPlayer = VoxelPlayer.new(partialMod)
assert(not partialPlayer:install())

local retryDependency
local retryMod = {
  path = ".",
  read = mod.read,
  assets = mod.assets,
  find = function() return retryDependency end,
  log = { warn = function() end },
}
local retryPlayer = VoxelPlayer.new(retryMod)
assert(not retryPlayer:install())
assert(not retryPlayer.installed)
retryDependency = {
  exports = { registerEntityModel = function() end },
}
assert(retryPlayer:install())
assert(retryPlayer.installed)

print("voxel player tests passed")
