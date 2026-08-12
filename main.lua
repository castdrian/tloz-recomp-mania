local Game = require("src.core.Game")
local GameVersion = require("src.core.GameVersion")
local Input = require("src.core.Input")
local NPC = require("src.world.NPC")
local Runtime = require("src.mods.Runtime")
local Sound = require("src.core.Sound")
local SpriteRenderer = require("src.render.SpriteRenderer")

local isGen2 = GameVersion.generation and GameVersion.generation() == 2 or false

local function loadModule(mod, name)
  local source = assert(mod:read(name), name .. " is missing")
  local chunk = assert(load(source, "@" .. mod.path .. "/" .. name))
  return chunk()
end

local function readOptionalMember(object, name)
  return object[name]
end

local function writeMember(object, name, value)
  object[name] = value
end

return function(mod)
  local Combat = loadModule(mod, "combat.lua")
  local assetPath = function(name)
    return mod.assets:path("assets/" .. name)
  end

  local audio = {
    { "TLOZ_LINK_DASH", "LTTP_Link_Dash.wav" },
    { "TLOZ_LINK_DYING", "LTTP_Link_Dying.wav" },
    { "TLOZ_LINK_FALL", "LTTP_Link_Fall.wav" },
    { "TLOZ_LINK_HURT", "LTTP_Link_Hurt.wav" },
    { "TLOZ_LINK_JUMP", "LTTP_Link_Jump.wav" },
    { "TLOZ_LINK_LAND", "LTTP_Link_Land.wav" },
    { "TLOZ_LINK_PICKUP", "LTTP_Link_Pickup.wav" },
    { "TLOZ_LINK_PUSH", "LTTP_Link_Push.wav" },
    { "TLOZ_LINK_SHOCK", "LTTP_Link_Shock.wav" },
    { "TLOZ_LINK_SHOCK_FAST", "LTTP_Link_Shock_Fast.wav" },
    { "TLOZ_LINK_THROW", "LTTP_Link_Throw.wav" },
    { "TLOZ_SWORD_1", "LTTP_Sword1.wav" },
    { "TLOZ_SWORD_2", "LTTP_Sword2.wav" },
    { "TLOZ_SWORD_3", "LTTP_Sword3.wav" },
    { "TLOZ_SWORD_4", "LTTP_Sword4.wav" },
    { "TLOZ_SWORD_CHARGE", "LTTP_Sword_Charge.wav" },
    { "TLOZ_SWORD_MAGIC", "LTTP_Sword_Magic.wav" },
    { "TLOZ_SWORD_MAGIC_LOOP", "LTTP_Sword_Magic_Loop.wav" },
    { "TLOZ_SWORD_SPIN", "LTTP_Sword_Spin.wav" },
    { "TLOZ_SWORD_SPIN_MAGIC", "LTTP_Sword_SpinMagic.wav" },
    { "TLOZ_SWORD_TAP", "LTTP_Sword_Tap.wav" },
    { "TLOZ_SHIELD", "LTTP_Shield.wav" },
    { "TLOZ_ARROW_HIT", "LTTP_Arrow_Hit.wav" },
    { "TLOZ_ARROW_SHOOT", "LTTP_Arrow_Shoot.wav" },
    { "TLOZ_BOOMERANG", "LTTP_Boomerang.wav" },
    { "TLOZ_HOOKSHOT", "LTTP_Hookshot.wav" },
    { "TLOZ_HAMMER", "LTTP_Hammer.wav" },
    { "TLOZ_HAMMER_POST", "LTTP_Hammer_Post.wav" },
    { "TLOZ_SHOVEL", "LTTP_Shovel.wav" },
    { "TLOZ_MAGIC_POWDER", "LTTP_MagicPowder.wav" },
    { "TLOZ_FIRE_ROD", "LTTP_FireRod.wav" },
    { "TLOZ_ICE_ROD", "LTTP_IceRod.wav" },
    { "TLOZ_LAMP", "LTTP_Lamp.wav" },
    { "TLOZ_CANE", "LTTP_Cane.wav" },
    { "TLOZ_CANE_MAGIC", "LTTP_Cane_Magic.wav" },
    { "TLOZ_BOMB_DROP", "LTTP_Bomb_Drop.wav" },
    { "TLOZ_BOMB_BLOW", "LTTP_Bomb_Blow.wav" },
    { "TLOZ_VILLAGER_HURT_1", "hit1.ogg" },
    { "TLOZ_VILLAGER_HURT_2", "hit2.ogg" },
    { "TLOZ_VILLAGER_HURT_3", "hit3.ogg" },
    { "TLOZ_VILLAGER_HURT_4", "hit4.ogg" },
    { "TLOZ_VILLAGER_DEATH", "death.ogg" },
  }

  for _, entry in ipairs(audio) do
    mod.content.sfx:register(entry[1], { file = assetPath("audio/" .. entry[2]) })
  end

  local function play(name)
    if Game.data then Sound.play(Game.data, name) end
  end

  local function currentPlayer()
    local world = Game.world or Game.overworld
    return world and world.player
  end

  local function isPlayerSubject(payload, subject)
    local target = subject or (payload and payload.target)
    local side = payload and payload.side
    return (target and target.isPlayer)
      or side == "player"
      or (type(side) == "table" and side.key == "player")
  end

  local spriteCache = {}
  local function sprite(name, frames, walker, seed)
    local key = table.concat({ name, frames, walker and "walker" or "fixed", seed or "" }, "|")
    if not spriteCache[key] then
      spriteCache[key] = SpriteRenderer.new({
        image = assetPath("sprites/" .. name),
        frames = frames,
        walker = walker,
        trueColor = true,
      }, seed or key)
    end
    return spriteCache[key]
  end

  local function actionSprite(kind, combo, facing, frame)
    local name
    if kind == "sword" then
      name = string.format("sword_%d_%s_%d.png", combo, facing, frame)
    elseif kind == "sword_charge" then
      name = string.format("sword_1_%s_%d.png", facing, frame)
    elseif kind == "sword_spin" then
      name = string.format("sword_4_%s_%d.png", facing, frame)
    elseif kind == "tool" and combo ~= "shield" then
      name = string.format("tool_%s_%s_%d.png", combo, facing, frame)
    else
      name = string.format("shield_%s_%d.png", facing, frame)
    end
    return sprite(name, 1, false, "tloz-action-" .. name)
  end

  local function targetAt(state)
    local player = state.player
    local x, y = player:facingCell()
    local npc = state:npcAtCell(x, y)
    if npc and npc.def and not npc.def.item and not npc.def.pokemon
       and not npc.def.trainerClass and not npc.tlozDefeated then
      return npc
    end
    return nil
  end

  local function hasInteractionTarget(state)
    local player = state.player
    local x, y = player:facingCell()
    if state:npcAtCell(x, y) then return true end
    if state.map and state.map:isCounterCell(x, y) then
      local nx, ny = x, y
      if player.facing == "up" then ny = ny - 1 end
      if player.facing == "down" then ny = ny + 1 end
      if player.facing == "left" then nx = nx - 1 end
      if player.facing == "right" then nx = nx + 1 end
      if state:npcAtCell(nx, ny) then return true end
    end
    return state.map and state.map:signAtCell(x, y) ~= nil
  end

  local function spawnParticles(state, npc)
    state.tlozParticles = state.tlozParticles or {}
    for index = 1, 18 do
      local angle = (index / 18) * math.pi * 2
      local speed = 0.6 + (index % 4) * 0.35
      state.tlozParticles[#state.tlozParticles + 1] = {
        x = npc.px + 8,
        y = npc.py + 8,
        vx = math.cos(angle) * speed,
        vy = math.sin(angle) * speed - 1.1,
        life = 22 + index % 8,
        maxLife = 30,
        size = 1 + index % 2,
      }
    end
  end

  local function removeNpc(state, npc)
    npc.tlozDefeated = true
    npc.tlozGlowFrames = 10
    npc.frozen = true
    spawnParticles(state, npc)
  end

  local function purgeNpc(state, npc)
    npc.def.hidden = true
    for index = #state.npcs, 1, -1 do
      if state.npcs[index] == npc then table.remove(state.npcs, index) end
    end
    for index = #state.entities, 1, -1 do
      if state.entities[index] == npc then table.remove(state.entities, index) end
    end
  end

  local function strike(state, action)
    local npc = targetAt(state)
    if not npc then return end
    local result = Combat.registerHit(state.tlozCombat, npc.id)
    npc.tlozGlowFrames = 10
    play(action.hitAudio or "TLOZ_SWORD_TAP")
    if result.defeated then
      play("TLOZ_VILLAGER_DEATH")
      removeNpc(state, npc)
    else
      play("TLOZ_VILLAGER_HURT_" .. tostring((result.count - 1) % 4 + 1))
    end
    action.hit = true
  end

  local function newAction(kind, combo, hitAudio)
    return {
      kind = kind,
      combo = combo,
      frame = 1,
      timer = 0,
      hit = false,
      hitAudio = hitAudio,
    }
  end

  local function startSword(state)
    state.tlozCombat = state.tlozCombat or Combat.new()
    local combo = Combat.nextCombo(state.tlozCombat)
    state.player.tlozAction = newAction("sword", combo, "TLOZ_SWORD_TAP")
    play("TLOZ_SWORD_" .. tostring(combo))
  end

  local function startSwordCharge(state)
    state.player.tlozAction = newAction("sword_charge", 4, "TLOZ_SWORD_TAP")
    play("TLOZ_SWORD_CHARGE")
  end

  local function startSwordSpin(state, magic)
    state.player.tlozAction = newAction("sword_spin", 4, "TLOZ_SWORD_TAP")
    play(magic and "TLOZ_SWORD_SPIN_MAGIC" or "TLOZ_SWORD_SPIN")
    if magic then play("TLOZ_SWORD_MAGIC") end
  end

  local function startShield(state)
    state.player.tlozAction = newAction("shield", "shield")
    play("TLOZ_SHIELD")
  end

  local function startEquipment(state, equipment)
    if equipment.id == "shield" then
      startShield(state)
      return
    end
    state.player.tlozAction = newAction("tool", equipment.id, equipment.hitAudio)
    play(equipment.audio)
  end

  local function selectEquipment(state)
    state.tlozCombat = state.tlozCombat or Combat.new()
    local equipment = Combat.nextEquipment(state.tlozCombat)
    state.tlozSelectedEquipment = equipment.id
    return equipment
  end

  local function updateParticles(state)
    for index = #state.tlozParticles, 1, -1 do
      local particle = state.tlozParticles[index]
      particle.life = particle.life - 1
      particle.x = particle.x + particle.vx
      particle.y = particle.y + particle.vy
      particle.vy = particle.vy + 0.08
      if particle.life <= 0 then table.remove(state.tlozParticles, index) end
    end
  end

  local function updateAction(state)
    local action = state.player and state.player.tlozAction
    if not action then return end
    if action.kind == "shield" then
      action.frame = 1 + math.floor(action.timer / 6) % 2
      action.timer = action.timer + 1
      if not Game.input:isDown("a") then state.player.tlozAction = nil end
      return
    end
    local bHeld = Game.input and Game.input.isDown and Game.input:isDown("b")
    if action.kind == "sword_charge" then
      action.timer = action.timer + 1
      action.frame = 1 + math.floor(action.timer / 6) % 2
      if action.timer == 12 then play("TLOZ_SWORD_MAGIC_LOOP") end
      if not bHeld then startSwordSpin(state, action.timer >= 18) end
      return
    end
    action.timer = action.timer + 1
    if action.timer % 3 == 0 then action.frame = action.frame + 1 end
    if action.kind == "tool" and action.combo == "bomb"
       and action.frame == 2 and not action.hit then
      play("TLOZ_BOMB_BLOW")
    end
    if action.frame == 2 and not action.hit then
      if action.kind == "tool" then
        if action.combo ~= "bomb" then play(action.hitAudio) end
        action.hit = true
      else
        strike(state, action)
      end
    end
    if action.frame > 2 then
      if action.kind == "sword" and bHeld then
        startSwordCharge(state)
      else
        state.player.tlozAction = nil
      end
    end
  end

  local function updateNpcGlow(state)
    local defeated = {}
    for _, npc in ipairs(state.npcs or {}) do
      if npc.tlozGlowFrames and npc.tlozGlowFrames > 0 then
        npc.tlozGlowFrames = npc.tlozGlowFrames - 1
        if npc.tlozDefeated and npc.tlozGlowFrames == 0 then
          defeated[#defeated + 1] = npc
        end
      end
    end
    for _, npc in ipairs(defeated) do purgeNpc(state, npc) end
  end

  local function drawParticles(state, scale)
    if not love.graphics or not state.tlozParticles then return end
    scale = scale or 1
    local camera = state.camera
    for _, particle in ipairs(state.tlozParticles) do
      local alpha = math.min(1, particle.life / 8)
      love.graphics.setColor(1, 0.05, 0.05, alpha)
      love.graphics.rectangle("fill",
        math.floor((particle.x - camera.x) * scale),
        math.floor((particle.y - camera.y) * scale),
        particle.size * scale, particle.size * scale)
    end
    love.graphics.setColor(1, 1, 1, 1)
  end

  local function setLinkSprites(player)
    local link = sprite("link-walk.png", 6, true, "tloz-link")
    player.sprite = link
    player.surfSprite = link
    player.surfPikachuSprite = link
    player.bikeSprite = link
  end

  local function applyPlayerVisual(player)
    if not player then return end
    local action = player.tlozAction
    if action then
      player.sprite = actionSprite(action.kind, action.combo,
        player.facing, action.frame)
      return
    end
    setLinkSprites(player)
  end

  local function install(game)
    local OverworldState = require("src.world.OverworldController")

    if not NPC.tlozRecompMania then
      NPC.tlozRecompMania = true
      local npcDraw = NPC.draw
      NPC.draw = function(npc, ...)
        if npc.tlozGlowFrames and npc.tlozGlowFrames > 0 and love.graphics then
          local r, g, b, a = love.graphics.getColor()
          love.graphics.setColor(1, 0.08, 0.08, a)
          npcDraw(npc, ...)
          love.graphics.setColor(r, g, b, a)
          return
        end
        return npcDraw(npc, ...)
      end
    end

    if not OverworldState.tlozRecompMania then
      OverworldState.tlozRecompMania = true
      local update = OverworldState.update
      OverworldState.update = function(state, dt)
        state.tlozParticles = state.tlozParticles or {}
        state.tlozCombat = state.tlozCombat or Combat.new()
        updateParticles(state)
        updateNpcGlow(state)
        if isGen2 then
          local input = game.input
          local player = state.player
          local busy = game.world and game.world.busy and game.world:busy()
          if input and player and not busy and not player.inputLocked
             and not player.moving and not player.tlozAction then
            if input.tlozPressedSelect then
              selectEquipment(state)
            elseif input:wasPressed("b") and not player.onBike
               and not player.surfing and not player.fishing then
              startSword(state)
            elseif input:isDown("a") and not hasInteractionTarget(state)
               and not player.onBike and not player.surfing
               and not player.fishing then
              local equipment = Combat.currentEquipment(state.tlozCombat)
              startEquipment(state, equipment)
            end
          end
        end
        updateAction(state)
        applyPlayerVisual(state.player)
        return update(state, dt)
      end

      if not isGen2 then
        local handleInput = OverworldState.handleInput
        local drawWorld = readOptionalMember(OverworldState, "drawWorld")
        OverworldState.handleInput = function(state)
          local input = game.input
          local player = state.player
          if not input or not player or player.inputLocked then
            return handleInput(state)
          end
          if player.tlozAction then return end
          if player.moving then return handleInput(state) end
          if input.tlozPressedSelect or input:wasPressed("select") then
            selectEquipment(state)
            return
          end
          if input:wasPressed("b") and not player.onBike and not player.surfing
             and not player.fishing then
            startSword(state)
            return
          end
          if input:isDown("a") and not hasInteractionTarget(state)
             and not player.onBike and not player.surfing
             and not player.fishing then
            local equipment = Combat.currentEquipment(state.tlozCombat)
            startEquipment(state, equipment)
            return
          end
          return handleInput(state)
        end
        writeMember(OverworldState, "drawWorld", function(state, ...)
          local result = drawWorld(state, ...)
          drawParticles(state)
          return result
        end)
      end
    end

    if isGen2 then
      local Gen2World = require("src.world.gen2.World")
      if not Gen2World.tlozRecompMania then
        Gen2World.tlozRecompMania = true
        local pollInput = Gen2World.pollInput
        Gen2World.pollInput = function(state, input)
          if state.player and state.player.tlozAction then
            state.heldDir = nil
            return
          end
          return pollInput(state, input)
        end
        local draw = Gen2World.draw
        Gen2World.draw = function(state, ...)
          local result = draw(state, ...)
          local scale = state.zoomScale and state:zoomScale() or 1
          drawParticles(state, scale)
          return result
        end
      end
    end

    if not Input.tlozRecompMania then
      Input.tlozRecompMania = true
      local inputStep = Input.step
      Input.step = function(input, ...)
        inputStep(input, ...)
        input.tlozPressedSelect = input:wasPressed("select")
        if isGen2 and input.tlozPressedSelect then input.pressed.select = nil end
      end
    end
  end

  mod.events:on("game.ready", function(payload)
    if payload and payload.game then install(payload.game) end
  end)
  local previousStep
  mod.events:on("world.stepped", function(payload)
    local player = currentPlayer()
    local jumped = payload and previousStep
      and payload.mapId == previousStep.mapId
      and type(payload.x) == "number" and type(payload.y) == "number"
      and math.abs(payload.x - previousStep.x)
        + math.abs(payload.y - previousStep.y) > 1
    if jumped then
      play("TLOZ_LINK_JUMP")
    else
      play(player and player.onBike and "TLOZ_LINK_DASH" or "TLOZ_LINK_LAND")
    end
    if payload and type(payload.x) == "number" and type(payload.y) == "number" then
      previousStep = { mapId = payload.mapId, x = payload.x, y = payload.y }
    end
  end)
  mod.events:on("world.interacted", function(payload)
    local kind = payload and payload.kind
    if kind == "itemball" or kind == "hidden" then
      play("TLOZ_LINK_PICKUP")
    elseif kind == "fieldmove" then
      play("TLOZ_LINK_THROW")
    end
  end)
  mod.events:on("world.boulder_moved", function()
    play("TLOZ_LINK_PUSH")
  end)
  mod.events:on("player.warped", function(payload)
    if payload and payload.warp then play("TLOZ_LINK_FALL") end
  end)
  mod.events:on("world.blacked_out", function()
    play("TLOZ_LINK_DYING")
  end)
  mod.events:on("battle.damage_dealt", function(payload)
    if isPlayerSubject(payload) and (payload.damage or 0) > 0 then
      play("TLOZ_LINK_HURT")
    end
  end)
  mod.events:on("battle.status_inflicted", function(payload)
    if isPlayerSubject(payload) then
      local status = payload.status
      play((status == "PAR" or status == "paralyze")
        and "TLOZ_LINK_SHOCK_FAST" or "TLOZ_LINK_SHOCK")
    end
  end)
  mod.events:on("battle.fainted", function(payload)
    if payload and payload.battler
       and isPlayerSubject(payload, payload.battler) then
      play("TLOZ_LINK_DYING")
    end
  end)

  mod.exports.controls = {
    sword = "B",
    equipment = "Select cycles equipment; hold A away from an interaction target",
    shield = "default equipment",
  }

  Runtime.emit("mod.tloz-recomp-mania.ready", { version = mod.version })
end
