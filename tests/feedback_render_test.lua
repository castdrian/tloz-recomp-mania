local Render = require("feedback_render")

local calls = {}
local currentColor = { 1, 1, 1, 1 }
local activeShader
local shaderColors

_G.love = {
  graphics = {
    getColor = function()
      return currentColor[1], currentColor[2], currentColor[3], currentColor[4]
    end,
    getShader = function() return activeShader end,
    setShader = function(shader)
      activeShader = shader
      calls[#calls + 1] = { kind = "shader", shader = shader }
    end,
    setColor = function(r, g, b, a)
      currentColor = { r, g, b, a }
      calls[#calls + 1] = { kind = "color", r = r, g = g, b = b, a = a }
    end,
    draw = function(image, quad, x, y, rotation, sx, sy)
      calls[#calls + 1] = {
        kind = "draw", image = image, quad = quad, x = x, y = y,
        rotation = rotation, sx = sx, sy = sy, shader = activeShader,
      }
    end,
    rectangle = function(mode, x, y, w, h)
      calls[#calls + 1] = { kind = "rectangle", mode = mode, x = x, y = y,
        w = w, h = h }
    end,
  },
}

local marks = {}
local spriteRedraws = {}
local keyedRequested = false
local palette = {
  markTrueColor = function(x, y, w, h)
    marks[#marks + 1] = { x = x, y = y, w = w, h = h }
  end,
  markSpriteRedraw = function(image, quad, x, y, sx, colors, keyed)
    spriteRedraws[#spriteRedraws + 1] = {
      image = image, quad = quad, x = x, y = y, sx = sx,
      colors = colors, keyed = keyed,
    }
  end,
  shader = function() return "shader" end,
  keyedShader = function()
    keyedRequested = true
    return "keyed"
  end,
  sendColors = function(shader, colors)
    shaderColors = { shader = shader, colors = colors }
  end,
}

local image = {}
local quads = { [0] = {}, [2] = {}, [5] = {} }
local sprite = {
  def = { frames = 6, walker = true },
  frames = { [0] = quads[0], [2] = quads[2], [5] = quads[5] },
  resolveImage = function() return image end,
}
local npc = {
  pose = function()
    return sprite, 32, 48, "right", 1, true, false
  end,
}

local fallback = false
Render.drawNpcGlow(npc, function() fallback = true end, 16, 16, palette,
  { STAND = { right = 2 }, WALK = { right = 5 } })

assert(not fallback)
assert(#marks == 0)
assert(#spriteRedraws == 1)
assert(spriteRedraws[1].image == image)
assert(spriteRedraws[1].quad == quads[5])
assert(spriteRedraws[1].x == 32 and spriteRedraws[1].y == 28)
assert(spriteRedraws[1].sx == -1)
assert(spriteRedraws[1].colors == Render.GLOW_COLORS)
assert(spriteRedraws[1].keyed == false)
assert(not keyedRequested)
local drawCall
local restoredShader
for _, call in ipairs(calls) do
  if call.kind == "draw" then drawCall = call end
  if call.kind == "shader" and call.shader == nil then restoredShader = call end
end
assert(drawCall and drawCall.image == image)
assert(drawCall.quad == quads[5])
assert(drawCall.sx == -1 and drawCall.sy == 1)
assert(drawCall.shader == "shader")
assert(shaderColors and shaderColors.shader == "shader")
assert(shaderColors.colors[1][1] > shaderColors.colors[1][2])
assert(restoredShader)

marks = {}
calls = {}
currentColor = { 1, 1, 1, 1 }
Render.drawParticles({
  camera = { x = 10, y = 20 },
  tlozParticles = {
    { x = 12, y = 24, life = 8, size = 2, color = { 1, 0.05, 0.05 } },
  },
}, 1, palette)

assert(#marks == 1)
assert(marks[1].x == 2 and marks[1].y == 4)
assert(marks[1].w == 2 and marks[1].h == 2)
assert(calls[1].kind == "color")
assert(calls[1].r == 1 and calls[1].g < 0.1 and calls[1].b < 0.1)
assert(calls[2].kind == "rectangle" and calls[2].mode == "fill")

print("tloz-recomp-mania feedback render tests passed")
