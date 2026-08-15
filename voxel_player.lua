local VoxelPlayer = {}
VoxelPlayer.__index = VoxelPlayer

local MODEL_ID = "tloz-recomp-mania.chibi-link"
local FALLBACK_IMAGE = "assets/sprites/mc/move_down_stand.png"
local SPECIAL_IMAGE = "tloz-recomp-mania-chibi-link"
local FACING_YAW = {
  down = 0,
  left = math.pi / 2,
  right = -math.pi / 2,
  up = math.pi,
}

local function findUpvalue(functionValue, wanted)
  if type(debug) ~= "table" or type(functionValue) ~= "function"
     or type(debug.getupvalue) ~= "function" then
    return nil, nil
  end
  for index = 1, 256 do
    local name, value = debug.getupvalue(functionValue, index)
    if not name then return nil, nil end
    if name == wanted then return index, value end
  end
  return nil, nil
end

local function setUpvalue(functionValue, index, value)
  if type(debug) ~= "table" or type(debug.setupvalue) ~= "function" then
    return false
  end
  return debug.setupvalue(functionValue, index, value) ~= nil
end

local function identity()
  return { 1, 0, 0, 0,
           0, 1, 0, 0,
           0, 0, 1, 0,
           0, 0, 0, 1 }
end

local function transform(matrix, x, y, z)
  return matrix[1] * x + matrix[2] * y + matrix[3] * z + matrix[4],
    matrix[5] * x + matrix[6] * y + matrix[7] * z + matrix[8],
    matrix[9] * x + matrix[10] * y + matrix[11] * z + matrix[12]
end

local function pointFor(matrix, vertex, scale)
  local x, y, z = transform(matrix, vertex[1], vertex[2], vertex[3])
  return { x * scale, y * scale, z * scale,
           vertex[4], vertex[5], vertex[6] }
end

local function actionFrame(pose, action, count)
  if count <= 1 then return 1 end
  local source = tonumber(pose.frame) or 1
  local maximum = tonumber(pose.maxFrame) or count
  if maximum <= 1 then return 1 end
  local progress = math.max(0, math.min(1, (source - 1) / (maximum - 1)))
  return 1 + math.floor(progress * (count - 1) + 0.5)
end

function VoxelPlayer.new(mod)
  return setmetatable({
    mod = mod,
    model = nil,
    linkTexture = nil,
    propsTexture = nil,
    meshes = {},
    shadowMeshes = {},
    clock = 0,
    active = false,
    installed = false,
    warned = {},
  }, VoxelPlayer)
end

function VoxelPlayer:warn(message)
  if self.warned[message] then return end
  self.warned[message] = true
  if self.mod.log and type(self.mod.log.warn) == "function" then
    self.mod.log:warn("voxel player: " .. message)
  end
end

function VoxelPlayer:loadImage(path)
  if not self.mod.assets or type(self.mod.assets.image) ~= "function" then
    return nil
  end
  local ok, image = pcall(self.mod.assets.image, self.mod.assets, path)
  if not ok then return nil end
  if image and type(image.setFilter) == "function" then
    pcall(image.setFilter, image, "nearest", "nearest")
  end
  return image
end

function VoxelPlayer:loadModel()
  if self.model then return true end
  if not self.mod or type(self.mod.read) ~= "function" then return false end
  local source = self.mod:read("assets/models/chibi_link.lua")
  if not source then
    self:warn("model data is missing")
    return false
  end
  local chunk, compileError = load(source,
    "@" .. tostring(self.mod.path) .. "/assets/models/chibi_link.lua")
  if not chunk then
    self:warn(tostring(compileError))
    return false
  end
  local ok, model = pcall(chunk)
  if not ok or type(model) ~= "table" then
    self:warn("model data could not be loaded")
    return false
  end
  self.model = model
  self.linkTexture = self:loadImage(
    "assets/models/chibi_link_base_color.png")
  self.propsTexture = self:loadImage(
    "assets/models/chibi_link_props_base_color.png")
  if not self.linkTexture or not self.propsTexture then
    self:warn("model textures are missing")
    self.model = nil
    return false
  end
  return true
end

function VoxelPlayer:mark(sprite, pose)
  if not sprite then return sprite end
  sprite.tlozChibiLink = true
  local definition = sprite.def
  if type(definition) ~= "table" then
    definition = {
      image = SPECIAL_IMAGE,
      frames = 1,
      trueColor = true,
    }
    sprite.def = definition
  end
  definition.tlozChibiLink = true
  definition.tlozVoxelPose = pose or {}
  definition.image = definition.image or SPECIAL_IMAGE
  definition.frames = definition.frames or 1
  definition.trueColor = true
  if type(sprite.resolveImage) ~= "function" then
    local image = sprite.image or self:loadImage(FALLBACK_IMAGE)
    sprite.image = image
    function sprite:resolveImage()
      return self.image
    end
  end
  sprite.tlozVoxelPose = pose or {}
  return sprite
end

function VoxelPlayer:step()
  self.clock = self.clock + 1
end

function VoxelPlayer:isLinkSprite(sprite)
  return sprite and (sprite.tlozChibiLink
    or (sprite.def and sprite.def.tlozChibiLink)) == true
end

function VoxelPlayer:pose(context)
  local sprite = context.sprite
  local pose = sprite and sprite.tlozVoxelPose or {}
  local kind = pose.kind or "idle"
  local actionName = "idle"
  if kind == "sword" or kind == "sword_spin"
     or kind == "sword_charge" then
    actionName = "sword"
  elseif pose.moving or pose.walkPose == "walk"
     or pose.walkPose == "walk_alt" or context.phase == 1 then
    actionName = "walk"
  end
  local action = self.model.actions[actionName]
  if not action then actionName, action = "idle", self.model.actions.idle end
  local frame
  if actionName == "sword" then
    frame = actionFrame(pose, action, #action.frames)
  elseif actionName == "walk" then
    frame = 1 + (math.floor((tonumber(pose.movementClock)
      or tonumber(pose.clock) or 0) / 4)
      + (pose.stepFlip and 2 or 0)) % #action.frames
  else
    frame = 1 + math.floor((tonumber(pose.clock) or 0) / 12) % #action.frames
  end
  local key = actionName .. ":" .. tostring(frame)
  return actionName, action.frames[frame], key,
    FACING_YAW[context.facing] or FACING_YAW.down
end

function VoxelPlayer:buildBody(actionFrameData)
  local source = self.model.body
  local values = {}
  local weights = source.weights or {}
  local scale = self.model.scale or 1
  for index, vertex in ipairs(source.vertices or {}) do
    local x, y, z = 0, 0, 0
    local weightOffset = (index - 1) * 8
    for slot = 0, 3 do
      local boneIndex = weights[weightOffset + slot * 2 + 1]
      local weight = weights[weightOffset + slot * 2 + 2] or 0
      if boneIndex and weight > 0 then
        local matrix = actionFrameData[boneIndex] or identity()
        local tx, ty, tz = transform(matrix, vertex[1], vertex[2], vertex[3])
        x = x + tx * weight
        y = y + ty * weight
        z = z + tz * weight
      end
    end
    values[index] = { x * scale, y * scale, z * scale,
                      vertex[4], vertex[5], vertex[6] }
  end
  return values, source.indices
end

function VoxelPlayer:buildProp(prop, actionFrameData)
  local source = prop.mesh
  local matrix = actionFrameData[prop.bone] or identity()
  local values = {}
  local scale = self.model.scale or 1
  for index, vertex in ipairs(source.vertices or {}) do
    values[index] = pointFor(matrix, vertex, scale)
  end
  return values, source.indices
end

function VoxelPlayer:meshesFor(context, actionFrameData, key)
  local cacheKey = key .. ":" .. tostring(context.newMesh)
  local cached = self.meshes[cacheKey]
  if cached then return cached end
  if type(context.newMesh) ~= "function" then return nil end
  local bodyVertices, bodyIndices = self:buildBody(actionFrameData)
  local swordVertices, swordIndices = self:buildProp(
    self.model.props.sword, actionFrameData)
  local shieldVertices, shieldIndices = self:buildProp(
    self.model.props.shield, actionFrameData)
  local body = context.newMesh(bodyVertices, bodyIndices)
  local sword = context.newMesh(swordVertices, swordIndices)
  local shield = context.newMesh(shieldVertices, shieldIndices)
  if not body or not sword or not shield then return nil end
  cached = { body = body, sword = sword, shield = shield }
  self.meshes[cacheKey] = cached
  self.shadowMeshes[body] = true
  return cached
end

function VoxelPlayer:modelMatrix(context, yaw)
  local translate = context.mat4.translate(
    (context.px or 0) + 8,
    (context.ground or 0) + (context.lift or 0),
    (context.py or 0) + 8)
  return context.mat4.mul(translate, context.mat4.rotateY(yaw))
end

function VoxelPlayer:drawMesh(context, mesh, texture, model, sunModel)
  if not mesh then return end
  if context.pass == "shadow" then
    local shadowModel = model
    if self.shadowMap and type(self.shadowMap.snug) == "function" then
      shadowModel = self.shadowMap.snug(model)
    end
    context.shadow(mesh, texture, shadowModel)
    return
  end
  context.draw(mesh, texture, model, context.pull, sunModel)
end

function VoxelPlayer:draw(context)
  if not self:isLinkSprite(context.sprite) or not self.model then return false end
  self.newMesh = context.newMesh or self.newMesh
  self.voxel = context.voxel or self.voxel
  self.mat4 = context.mat4 or self.mat4
  local _, actionFrameData, key, yaw = self:pose(context)
  local meshes = self:meshesFor(context, actionFrameData, key)
  if not meshes then return false end
  local model = self:modelMatrix(context, yaw)
  local sunModel = model
  self:drawMesh(context, meshes.body, self.linkTexture, model, sunModel)
  self:drawMesh(context, meshes.sword, self.propsTexture, model, sunModel)
  self:drawMesh(context, meshes.shield, self.propsTexture, model, sunModel)
  return true
end

function VoxelPlayer:context(pass, sprite, px, py, facing, phase, flip,
                              ground, lift, pull)
  return {
    pass = pass,
    sprite = sprite,
    def = sprite and sprite.def,
    px = px,
    py = py,
    facing = facing,
    phase = phase,
    flip = flip,
    ground = ground,
    lift = lift or 0,
    colors = nil,
    voxel = self.voxel,
    mat4 = self.mat4,
    newMesh = self.newMesh,
    draw = self.voxel and self.voxel.draw,
    shadow = self.shadowMap and self.shadowMap.draw,
    pull = pull or 0,
  }
end

function VoxelPlayer:dependency()
  if not self.mod or type(self.mod.find) ~= "function" then return nil end
  local ok, handle = pcall(self.mod.find, "DRAMALESS_SHAPE")
  if ok and handle then return handle end
  ok, handle = pcall(self.mod.find, self.mod, "DRAMALESS_SHAPE")
  if ok then return handle end
  return nil
end

function VoxelPlayer:installPublic(handle)
  local exports = handle and handle.exports or handle
  local register = exports and exports.registerEntityModel
  if type(register) ~= "function" then return false end
  local ok, unregister = pcall(register, MODEL_ID,
    function(context) return self:draw(context) end, 1000)
  if not ok then
    self:warn(tostring(unregister))
    return false
  end
  self.unregister = unregister
  return true
end

function VoxelPlayer:installLegacy(lib)
  if not lib or type(lib.require) ~= "function" then return false end
  local ok, scene = pcall(lib.require, "VoxelScene")
  if not ok or type(scene) ~= "table" then return false end
  local okVoxel, voxel = pcall(lib.require, "Voxel3D")
  local okMat4, mat4 = pcall(lib.require, "Mat4")
  local okShadow, shadowMap = pcall(lib.require, "ShadowMap")
  local okState, voxelState = pcall(lib.require, "VoxelState")
  if not okVoxel or not okMat4 or not okShadow then return false end
  self.voxel, self.mat4, self.shadowMap = voxel, mat4, shadowMap
  local pull = 0
  if type(scene.pull) == "function" then
    local angle = okState and tonumber(voxelState.angle) or 0.05
    pull = scene.pull(math.max(angle or 0.05, 0.05))
  end
  local drawCastIndex, originalDrawEntity = findUpvalue(scene.render, "drawCast")
  local drawEntityIndex, drawEntity = findUpvalue(originalDrawEntity, "drawEntity")
  local scenePatched = false
  if drawCastIndex and type(originalDrawEntity) == "function"
     and drawEntityIndex and type(drawEntity) == "function" then
    local original = drawEntity
    local replacement = function(sprite, px, py, facing, phase, flip, ground,
                                 colors, lift)
      if self:isLinkSprite(sprite) then
        self.newMesh = voxel.newMesh
        local context = self:context("scene", sprite, px, py, facing,
          phase, flip, ground, lift, pull)
        context.colors = colors
        if self:draw(context) then return true end
      end
      return original(sprite, px, py, facing, phase, flip, ground, colors,
        lift)
    end
    scenePatched = setUpvalue(originalDrawEntity, drawEntityIndex, replacement)
  end
  local ghostIndex, originalGhost = findUpvalue(scene.render, "drawGhost")
  local ghostPatched = false
  if ghostIndex and type(originalGhost) == "function" then
    local original = originalGhost
    local replacement = function(p)
      if self:isLinkSprite(p.sprite) then
        self.newMesh = voxel.newMesh
        local context = self:context("ghost", p.sprite, p.px, p.py,
          p.facing, p.phase, p.flip, p.gh, p.lift, pull)
        context.colors = p.colors
        if self:draw(context) then return end
      end
      return original(p)
    end
    ghostPatched = setUpvalue(scene.render, ghostIndex, replacement)
  end
  local okBillboards, billboards = pcall(lib.require, "SpriteBillboards")
  if okBillboards and type(billboards) == "table"
     and type(billboards.shadowQuad) == "function" then
    local originalShadowQuad = billboards.shadowQuad
    billboards.shadowQuad = function(def, frame)
      if def and def.tlozChibiLink then
        local sprite = { def = def, tlozChibiLink = true,
                         tlozVoxelPose = def.tlozVoxelPose }
        self.newMesh = voxel.newMesh
        local context = self:context("shadow", sprite, 0, 0, "down", 0,
          false, 0, 0, pull)
        local _, actionFrameData, key = self:pose(context)
        local meshes = self:meshesFor(context, actionFrameData, key)
        if meshes then
          self.shadowMeshes[meshes.body] = true
          return meshes.body
        end
      end
      return originalShadowQuad(def, frame)
    end
    self.billboards = billboards
  end
  if type(shadowMap.draw) == "function" and not shadowMap.tlozChibiLinkDraw then
    local originalShadowDraw = shadowMap.draw
    shadowMap.draw = function(mesh, texture, model)
      if self.shadowMeshes[mesh] then texture = self.linkTexture end
      return originalShadowDraw(mesh, texture, model)
    end
    shadowMap.tlozChibiLinkDraw = true
  end
  if scenePatched and ghostPatched then return true end
  return false
end

function VoxelPlayer:install()
  if self.installed then return self.active end
  local handle = self:dependency()
  if not handle or not self:loadModel() then return false end
  if self:installPublic(handle) then
    self.installed = true
    self.active = true
    return true
  end
  local exports = handle.exports or handle
  local lib = exports and exports.lib
  if self:installLegacy(lib) then
    self.installed = true
    self.active = true
    return true
  end
  self:warn("DRAMALESS renderer hook is unavailable")
  return false
end

return VoxelPlayer
