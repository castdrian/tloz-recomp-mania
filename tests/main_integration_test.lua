local sounds = {}
local marks = {}
local draws = {}
local input = { pressed = {} }
local registered = {}

function input:wasPressed(name)
  local pressed = self.pressed[name]
  self.pressed[name] = nil
  return pressed == true
end

function input:isDown()
  return false
end

local Game = { data = { audio = { sfx = {} } }, input = input }
local GameVersion = { generation = function() return 1 end }
local Input = { step = function() end }
local NPC = { draw = function() end }
local Runtime = { emit = function() end }
local Sound = {
  play = function(_, name)
    local definition = assert(registered[name], "unregistered sound " .. name)
    local file = assert(io.open(definition.file, "rb"))
    file:close()
    sounds[#sounds + 1] = name
    return { name = name }
  end,
}
local PaletteFX = {
  markSpriteRedraw = function() end,
  markTrueColor = function(x, y, w, h)
    marks[#marks + 1] = { x = x, y = y, w = w, h = h }
  end,
}
local SpriteRenderer = {
  STAND = { down = 0, up = 1, left = 2, right = 2 },
  WALK = { down = 3, up = 4, left = 5, right = 5 },
  new = function(def)
    return {
      def = def,
      image = {
        path = def.image,
        getWidth = function() return 16 end,
        getHeight = function() return 16 end,
      },
      frames = { [0] = {}, [2] = {}, [5] = {} },
      resolveImage = function(self) return self.image end,
      draw = function(self)
        if self.def.trueColor then PaletteFX.markTrueColor(0, 0, 16, 16) end
      end,
    }
  end,
}
local OverworldState = {
  update = function() end,
  handleInput = function() end,
  drawWorld = function() end,
}

local function imageAsset(path)
  return {
    path = path,
    getWidth = function() return 16 end,
    getHeight = function() return 16 end,
  }
end

_G.love = {
  graphics = {
    getColor = function() return 1, 1, 1, 1 end,
    setColor = function() end,
    draw = function(image, quad, x, y, rotation, sx, sy)
      draws[#draws + 1] = {
        image = image, quad = quad, x = x, y = y,
        rotation = rotation, sx = sx, sy = sy,
      }
    end,
    rectangle = function() end,
  },
}

package.loaded["src.core.Game"] = Game
package.loaded["src.core.GameVersion"] = GameVersion
package.loaded["src.core.Input"] = Input
package.loaded["src.world.NPC"] = NPC
package.loaded["src.mods.Runtime"] = Runtime
package.loaded["src.core.Sound"] = Sound
package.loaded["src.render.PaletteFX"] = PaletteFX
package.loaded["src.render.SpriteRenderer"] = SpriteRenderer
package.loaded["src.world.OverworldController"] = OverworldState

local listeners = {}
local mod = {
  path = ".",
  version = "0.1.0",
  read = function(_, name)
    local file = assert(io.open(name, "rb"))
    local body = file:read("*a")
    file:close()
    return body
  end,
  assets = {
    path = function(_, path) return path end,
    image = function(_, path) return imageAsset(path) end,
  },
  content = {
    sfx = {
      register = function(_, name, definition)
        registered[name] = definition
      end,
    },
  },
  events = {
    on = function(_, name, callback)
      listeners[name] = callback
    end,
  },
  log = { warn = function() end },
  exports = {},
}

local factory = assert(loadfile("main.lua"))()
factory(mod)

local game = { data = Game.data, input = input, world = nil,
  save = { money = 10 } }
listeners["game.ready"]({ game = game })

assert(registered.TLOZ_VILLAGER_HURT_1.file:match("Minecraft_Villager_Hurt_1%.wav$"))
assert(registered.TLOZ_VILLAGER_HURT_2.file:match("Minecraft_Villager_Hurt_2%.wav$"))
assert(registered.TLOZ_VILLAGER_HURT_3.file:match("Minecraft_Villager_Hurt_3%.wav$"))
assert(registered.TLOZ_VILLAGER_HURT_4.file:match("Minecraft_Villager_Hurt_4%.wav$"))
assert(registered.TLOZ_VILLAGER_DEATH.file:match("Minecraft_Villager_Death%.wav$"))
assert(registered.TLOZ_RUPEE_DROP.file:match("MC_Rupee_Bounce%.wav$"))
assert(registered.TLOZ_RUPEE_COLLECT.file:match("MC_Rupee%.wav$"))
assert(registered.TLOZ_GRASS_CUT.file:match("MC_Bush%.wav$"))
assert(registered.TLOZ_POT_BREAK.file:match("OOT_Pot_Shatter%.wav$"))

local frontX, frontY = 1, 0
local player = {
  cellX = 0,
  cellY = 0,
  facing = "right",
  moving = false,
  stepLanded = false,
  bumpFrames = 0,
  animClock = 0,
  stepFlip = false,
}
function player:facingCell()
  return frontX, frontY
end
local sprite = {
  def = { frames = 6, walker = true },
  image = {},
  frames = { [0] = {}, [2] = {}, [5] = {} },
  resolveImage = function(self) return self.image end,
}
local npc = {
  id = "npc",
  cellX = 1,
  cellY = 0,
  px = 16,
  py = 0,
  def = {},
  pose = function()
    return sprite, 16, 0, "right", 0, false, false
  end,
}
local state = {
  player = player,
  npcs = { npc },
  entities = { player, npc },
  camera = { x = 0, y = 0 },
}

local function hitOnce(ticks)
  input.pressed.b = true
  OverworldState.handleInput(state)
  for _ = 1, ticks or 12 do OverworldState.update(state, 0) end
end

hitOnce()
hitOnce()
hitOnce(4)

local function contains(list, value)
  for _, entry in ipairs(list) do
    if entry == value then return true end
  end
  return false
end

local npcSounds = {}
for _, name in ipairs(sounds) do
  if name:match("TLOZ_VILLAGER") then npcSounds[#npcSounds + 1] = name end
end
assert(npcSounds[1] == "TLOZ_VILLAGER_HURT_1")
assert(npcSounds[2] == "TLOZ_VILLAGER_HURT_2")
assert(npcSounds[3] == "TLOZ_VILLAGER_DEATH")
assert(npc.tlozDefeated)
assert(not contains(state.npcs, npc), "defeated npc remained in npc list")
assert(not contains(state.entities, npc), "defeated npc remained in entity list")
assert(#state.tlozParticles == 18)

local respawnPlayer = {
  cellX = 0,
  cellY = 0,
  facing = "right",
  moving = false,
  stepLanded = false,
  bumpFrames = 0,
  animClock = 0,
  stepFlip = false,
}
local respawnNpc = {
  id = "respawn-npc",
  cellX = 1,
  cellY = 0,
  px = 16,
  py = 0,
  def = {},
  pose = function()
    return sprite, 16, 0, "right", 0, false, false
  end,
}
local respawnState = {
  player = respawnPlayer,
  npcs = { respawnNpc },
  entities = { respawnPlayer, respawnNpc },
  camera = { x = 0, y = 0 },
}

local function hitRespawnNpc(ticks)
  input.pressed.b = true
  OverworldState.handleInput(respawnState)
  for _ = 1, ticks do OverworldState.update(respawnState, 1 / 60) end
end

hitRespawnNpc(20)
hitRespawnNpc(20)
hitRespawnNpc(14)
assert(respawnNpc.tlozDefeated, "respawn npc was not defeated")
assert(not contains(respawnState.npcs, respawnNpc), "respawn npc was not purged")
local remainingFrames = math.floor(respawnNpc.tlozRespawn.remaining * 60 + 0.5)
for _ = 1, remainingFrames - 1 do OverworldState.update(respawnState, 1 / 60) end
assert(not contains(respawnState.npcs, respawnNpc))
OverworldState.update(respawnState, 1 / 60)
assert(contains(respawnState.npcs, respawnNpc))
assert(not respawnNpc.tlozDefeated)

marks = {}
npc.tlozGlowFrames = 10
NPC.draw(npc, 0, 0)
assert(#marks == 0)

marks = {}
OverworldState.drawWorld(state)
assert(#marks == 18)

player.facing = "right"
player.tlozAction = {
  kind = "tool", combo = "shield", frame = 1, timer = 0,
  hit = false, maxFrame = 2, hitFrame = 2,
}
OverworldState.update(state, 0)
assert(player.sprite.image.path:match("assets/sprites/shield_right_1%.png$"))
marks = {}
player.sprite:draw(0, 0, 0, 0, "right", 0, false)
assert(#marks == 0, "shield action marked a backdrop redraw rectangle")

player.tlozAction = {
  kind = "sword_spin", combo = 4, frame = 1, timer = 0,
  hit = false, maxFrame = 8, hitFrame = 4,
}
OverworldState.update(state, 0)
draws = {}
player.sprite:draw(0, 0, 0, 0, "right", 0, false)
assert(draws[#draws].sx ~= -1, "spin sprite was mirrored for right-facing Link")

local environmentMap = {
  id = "TEST_HOUSE",
  def = { id = "TEST_HOUSE", tileset = "HOUSE", width = 4, height = 4,
    objects = {} },
  widthCells = 8,
  heightCells = 8,
}
function environmentMap:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 7 and y < 7
end
function environmentMap:isCounterCell() return false end
function environmentMap:warpAtCell() return nil end
function environmentMap:signAtCell() return nil end
function environmentMap:isGrassCell(x, y)
  return (x == 2 and y == 2) or (x == 3 and y == 3)
end

state.map = environmentMap
state.npcs = {}
state.entities = { player }
player.tlozAction = nil
player.cellX, player.cellY = 1, 1
player.px, player.py = 16, 16
Game.overworld = state
listeners["map.entered"]({ map = environmentMap })
local housePotCount = 0
for _, entity in ipairs(state.entities) do
  if entity.tlozEnvironmentType == "pot" then housePotCount = housePotCount + 1 end
end
assert(housePotCount >= 2, "house map did not receive multiple pots")
local pot
for _, entity in ipairs(state.entities) do
  if entity.tlozEnvironmentType == "pot" then pot = entity end
end
assert(pot, "house map did not receive a pot")
frontX, frontY = pot.cellX, pot.cellY
player.cellX, player.cellY = pot.cellX - 1, pot.cellY
player.px, player.py = player.cellX * 16, player.cellY * 16
player.facing = "right"
input.pressed.b = true
OverworldState.handleInput(state)
for _ = 1, 12 do OverworldState.update(state, 1 / 60) end
assert(not contains(state.entities, pot), "sword did not break the pot")
local potBreakSounds = 0
for _, name in ipairs(sounds) do
  if name == "TLOZ_POT_BREAK" then potBreakSounds = potBreakSounds + 1 end
end
assert(potBreakSounds == 1, "pot break did not play its Zelda sound")
local rupee
for _, entity in ipairs(state.entities) do
  if entity.tlozEnvironmentType == "rupee" then rupee = entity end
end
if rupee then
  player.cellX, player.cellY = rupee.cellX, rupee.cellY
  player.px, player.py = rupee.px, rupee.py
  OverworldState.update(state, 1 / 60)
  assert(game.save.money > 10, "rupee did not update the wallet")
end

local grassMap = {
  id = "TEST_GRASS",
  def = { id = "TEST_GRASS", tileset = "OVERWORLD", width = 4, height = 4,
    objects = {} },
  widthCells = 8,
  heightCells = 8,
}
function grassMap:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 7 and y < 7
end
function grassMap:isCounterCell() return false end
function grassMap:warpAtCell() return nil end
function grassMap:signAtCell() return nil end
function grassMap:isGrassCell(x, y)
  return (x == 2 and y == 2) or (x == 3 and y == 3)
    or (x == 3 and y == 4)
end
state.map = grassMap
state.entities = { player }
state.npcs = {}
listeners["map.entered"]({ map = grassMap })

frontX, frontY = 1, 1
player.cellX, player.cellY = 1, 2
player.px, player.py = 16, 32
player.facing = "up"
player.tlozAction = nil
state.npcs = {}
state.entities = { player }
input.pressed.b = true
OverworldState.handleInput(state)
for _ = 1, 12 do OverworldState.update(state, 1 / 60) end
assert(state.tlozEnvironmentMapState.cutGrass["2:2"])

frontX, frontY = 3, 4
player.cellX, player.cellY = 3, 3
player.px, player.py = 48, 48
player.facing = "down"
player.tlozAction = nil
input.pressed.b = true
OverworldState.handleInput(state)
for _ = 1, 12 do OverworldState.update(state, 1 / 60) end
assert(state.tlozEnvironmentMapState.cutGrass["3:3"])

local spinMap = {
  id = "TEST_SPIN_GRASS",
  def = { id = "TEST_SPIN_GRASS", tileset = "OVERWORLD", width = 4, height = 4,
    objects = {} },
  widthCells = 8,
  heightCells = 8,
}
function spinMap:isWalkableCell(x, y)
  return x > 0 and y > 0 and x < 7 and y < 7
end
function spinMap:isCounterCell() return false end
function spinMap:warpAtCell() return nil end
function spinMap:signAtCell() return nil end
function spinMap:isGrassCell(x, y) return x == 1 and y == 1 end
state.map = spinMap
state.entities = { player }
state.npcs = {}
listeners["map.entered"]({ map = spinMap })
player.cellX, player.cellY = 2, 2
player.px, player.py = 32, 32
player.facing = "right"
frontX, frontY = 3, 2
player.tlozAction = {
  kind = "sword_spin", combo = 4, frame = 3, timer = 0,
  hit = false, maxFrame = 8, hitFrame = 4,
}
OverworldState.update(state, 1 / 60)
OverworldState.update(state, 1 / 60)
assert(state.tlozEnvironmentMapState.cutGrass["1:1"],
  "spin attack did not reach rear diagonal grass")

print("tloz-recomp-mania main integration tests passed")
