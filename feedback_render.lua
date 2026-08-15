local Render = {}

Render.GLOW_COLORS = {
  { 255, 40, 40 },
  { 255, 24, 24 },
  { 220, 8, 8 },
  { 120, 0, 0 },
}

local function frameFor(sprite, facing, walkPhase, stepFlip, renderer)
  if sprite.def.frames <= 1 then return 0, false end
  local frames = sprite.def.walker and walkPhase == 1
    and renderer.WALK or renderer.STAND
  local frame = frames[facing] or frames.down
  local flip = facing == "right"
  if (facing == "down" or facing == "up") and walkPhase == 1 and stepFlip then
    flip = true
  end
  return frame, flip
end

function Render.drawNpcGlow(npc, npcDraw, camX, camY, paletteFX, renderer)
  local sprite, px, py, facing, walkPhase, stepFlip = npc:pose()
  if not sprite or not sprite.def then
    return npcDraw(npc, camX, camY)
  end
  local image = sprite.resolveImage and sprite:resolveImage() or sprite.image
  local frame, flip = frameFor(sprite, facing, walkPhase, stepFlip, renderer)
  local quad = sprite.frames and (sprite.frames[frame] or sprite.frames[0])
  local x = math.floor(px - camX)
  local y = math.floor(py - camY) - 4
  local drawX = flip and x + 16 or x
  local drawScaleX = flip and -1 or 1
  if image and quad and paletteFX.markSpriteRedraw then
    paletteFX.markSpriteRedraw(image, quad, drawX, y, drawScaleX,
      Render.GLOW_COLORS, false)
  end
  local r, g, b, a = love.graphics.getColor()
  local previousShader = love.graphics.getShader and love.graphics.getShader()
  local shader = paletteFX.shader and paletteFX.shader()
  if shader and love.graphics.setShader then
    paletteFX.sendColors(shader, Render.GLOW_COLORS)
    love.graphics.setShader(shader)
  end
  love.graphics.setColor(1, 1, 1, a)
  if image and quad then
    love.graphics.draw(image, quad, drawX, y, 0, drawScaleX, 1)
  else
    npcDraw(npc, camX, camY)
  end
  if shader and love.graphics.setShader then love.graphics.setShader(previousShader) end
  love.graphics.setColor(r, g, b, a)
end

function Render.drawParticles(state, scale, paletteFX)
  if not love.graphics or not state.tlozParticles then return end
  scale = scale or 1
  local camera = state.camera or { x = 0, y = 0 }
  for _, particle in ipairs(state.tlozParticles) do
    local alpha = math.min(1, particle.life / 8)
    local color = particle.color or { 1, 0.05, 0.05 }
    local x = math.floor((particle.x - camera.x) * scale)
    local y = math.floor((particle.y - camera.y) * scale)
    local width = particle.size * scale
    paletteFX.markTrueColor(x, y, width, width)
    love.graphics.setColor(color[1], color[2], color[3], alpha)
    love.graphics.rectangle("fill", x, y, width, width)
  end
  love.graphics.setColor(1, 1, 1, 1)
end

return Render
