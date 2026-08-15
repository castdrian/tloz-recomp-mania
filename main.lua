local Game = require("src.core.Game")
local GameVersion = require("src.core.GameVersion")
local Input = require("src.core.Input")
local NPC = require("src.world.NPC")
local Runtime = require("src.mods.Runtime")
local Sound = require("src.core.Sound")
local PaletteFX = require("src.render.PaletteFX")
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
  local Action = loadModule(mod, "action.lua")
  local Movement = loadModule(mod, "movement.lua")
  local Feedback = loadModule(mod, "feedback.lua")
  local FeedbackRender = loadModule(mod, "feedback_render.lua")
  local Hitbox = loadModule(mod, "hitbox.lua")
  local WarpEffects = loadModule(mod, "warp_effects.lua")
  local Environment = loadModule(mod, "environment.lua")
  local assetPath = function(name)
    return mod.assets:path("assets/" .. name)
  end

  local audio = {
    { "TLOZ_LINK_DASH", "mc/MC_Link_Run.wav" },
    { "TLOZ_LINK_DYING", "mc/MC_Link_Die_Tune.wav" },
    { "TLOZ_LINK_FALL", "mc/MC_Link_Fall.wav" },
    { "TLOZ_LINK_HURT", "mc/MC_Link_Hurt.wav" },
    { "TLOZ_LINK_VOICE", "mc/MC_Link_Sword1.wav" },
    { "TLOZ_LINK_VOICE_1", "mc/MC_Link_Sword1.wav" },
    { "TLOZ_LINK_VOICE_2", "mc/MC_Link_Sword2.wav" },
    { "TLOZ_LINK_VOICE_3", "mc/MC_Link_Sword3.wav" },
    { "TLOZ_LINK_VOICE_4", "mc/MC_Link_Sword_Spin1.wav" },
    { "TLOZ_LINK_JUMP", "mc/MC_Link_Jump.wav" },
    { "TLOZ_LINK_LAND", "mc/MC_Link_Run.wav" },
    { "TLOZ_LINK_PICKUP", "mc/MC_Rupee.wav" },
    { "TLOZ_RUPEE_DROP", "mc/MC_Rupee_Bounce.wav" },
    { "TLOZ_RUPEE_COLLECT", "mc/MC_Rupee.wav" },
    { "TLOZ_GRASS_CUT", "mc/MC_Bush.wav" },
    { "TLOZ_POT_BREAK", "mc/MC_Shatter.wav" },
    { "TLOZ_LINK_PUSH", "mc/MC_Link_Push.wav" },
    { "TLOZ_LINK_SHOCK", "mc/MC_Link_Hurt.wav" },
    { "TLOZ_LINK_SHOCK_FAST", "mc/MC_Link_Hurt.wav" },
    { "TLOZ_LINK_THROW", "mc/MC_Link_Lift.wav" },
    { "TLOZ_SWORD_1", "mc/MC_Link_Sword.wav" },
    { "TLOZ_SWORD_2", "mc/MC_Link_Sword.wav" },
    { "TLOZ_SWORD_3", "mc/MC_Link_Sword.wav" },
    { "TLOZ_SWORD_4", "mc/MC_Link_Sword.wav" },
    { "TLOZ_SWORD_CHARGE", "mc/MC_Link_Sword_Charge.wav" },
    { "TLOZ_SWORD_MAGIC", "mc/MC_Link_Sword_Beam.wav" },
    { "TLOZ_SWORD_MAGIC_LOOP", "mc/MC_Link_Sword_Charge.wav" },
    { "TLOZ_SWORD_SPIN", "mc/MC_Link_Sword_Spin.wav" },
    { "TLOZ_SWORD_SPIN_MAGIC", "mc/MC_Link_Sword_Spin.wav" },
    { "TLOZ_SWORD_TAP", "mc/MC_Sword_TapBombWall.wav" },
    { "TLOZ_SHIELD", "mc/MC_Link_Shield.wav" },
    { "TLOZ_ARROW_HIT", "mc/MC_Arrow_Hit.wav" },
    { "TLOZ_ARROW_SHOOT", "mc/MC_Arrow_Shoot.wav" },
    { "TLOZ_BOOMERANG", "mc/MC_Boomerang.wav" },
    { "TLOZ_HOOKSHOT", "mc/MC_Boomerang.wav" },
    { "TLOZ_HAMMER", "mc/MC_Hammer.wav" },
    { "TLOZ_HAMMER_POST", "mc/MC_Hammer.wav" },
    { "TLOZ_SHOVEL", "mc/MC_MoleMitts_Dig.wav" },
    { "TLOZ_MAGIC_POWDER", "mc/MC_GustJar_Blast1.wav" },
    { "TLOZ_FIRE_ROD", "mc/MC_CaneOfPacci_Shoot.wav" },
    { "TLOZ_ICE_ROD", "mc/MC_IceBlock_Slide.wav" },
    { "TLOZ_LAMP", "mc/MC_FlameLantern_On.wav" },
    { "TLOZ_CANE", "mc/MC_CaneOfPacci_Shoot.wav" },
    { "TLOZ_CANE_MAGIC", "mc/MC_CaneOfPacci_Hit.wav" },
    { "TLOZ_BOMB_DROP", "mc/MC_Bomb_Drop.wav" },
    { "TLOZ_BOMB_BLOW", "mc/MC_Bomb_Blow.wav" },
    { "TLOZ_VILLAGER_HURT_1", "Minecraft_Villager_Hurt_1.wav" },
    { "TLOZ_VILLAGER_HURT_2", "Minecraft_Villager_Hurt_2.wav" },
    { "TLOZ_VILLAGER_HURT_3", "Minecraft_Villager_Hurt_3.wav" },
    { "TLOZ_VILLAGER_HURT_4", "Minecraft_Villager_Hurt_4.wav" },
    { "TLOZ_VILLAGER_DEATH", "Minecraft_Villager_Death.wav" },
  }

  for _, entry in ipairs(audio) do
    mod.content.sfx:register(entry[1], { file = assetPath("audio/" .. entry[2]) })
  end

  local playData
  local failedAudio = {}
  local function play(name)
    local data = playData or Game.data
    if not data then return nil end
    local source = Sound.play(data, name)
    if not source and not failedAudio[name] then
      failedAudio[name] = true
      mod.log:warn("audio key %s did not start", name)
    end
    return source
  end

  local environment = Environment.new({
    mod = mod,
    save = mod.save,
    game = Game,
    play = play,
    palette = PaletteFX,
  })

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
  local looseSpriteCache = {}
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

  local function looseSprite(name, seed, anchorX, anchorY, flipRight, assetRoot)
    local key = table.concat({ name, seed or "", anchorX or 0, anchorY or 0,
      flipRight and "flip" or "fixed", assetRoot or "mc/" }, "|")
    if looseSpriteCache[key] then return looseSpriteCache[key] end
    local root = assetRoot == nil and "mc/" or assetRoot
    local image = mod.assets:image("assets/sprites/" .. root .. name)
    local result = { image = image, width = image:getWidth(), height = image:getHeight() }
    result.anchorX = anchorX or 0
    result.anchorY = anchorY or 4
    function result:draw(px, py, camX, camY, facing, walkPhase, stepFlip)
      local x = math.floor(px - camX) - self.anchorX
      local y = math.floor(py - camY) - self.anchorY
      local flip = flipRight and facing == "right"
      if flip then
        love.graphics.draw(self.image, x + self.width, y, 0, -1, 1)
        PaletteFX.markSpriteRedraw(self.image, nil, x + self.width, y, -1)
      else
        love.graphics.draw(self.image, x, y)
        PaletteFX.markSpriteRedraw(self.image, nil, x, y, 1)
      end
    end
    function result:drawTile(path, x, y, flip)
      local tile = mod.assets:image(path)
      local width = tile:getWidth()
      if flip then
        love.graphics.draw(tile, x + width, y, 0, -1, 1)
      else
        love.graphics.draw(tile, x, y)
      end
      PaletteFX.markTrueColor(x, y, width, tile:getHeight())
    end
    looseSpriteCache[key] = result
    return result
  end

  local function movementSprite()
    return {
      movement = Movement.new(),
      draw = function(self, px, py, camX, camY, facing)
        local direction = facing
        local pose = Movement.pose(self.movement)
        local image = mod.assets:image("assets/sprites/mc/move_"
          .. direction .. "_" .. pose .. ".png")
        local x = math.floor(px - camX)
        local y = math.floor(py - camY) - 4
        love.graphics.draw(image, x, y)
        PaletteFX.markSpriteRedraw(image, nil, x, y, 1)
      end,
      drawTile = function(_, path, x, y, flip)
        local image = mod.assets:image(path)
        local width = image:getWidth()
        if flip then
          love.graphics.draw(image, x + width, y, 0, -1, 1)
        else
          love.graphics.draw(image, x, y)
        end
        PaletteFX.markTrueColor(x, y, width, image:getHeight())
      end,
    }
  end

  local swordSwingFrames = {
    left = { 1, 2, 3 },
    down = { 3, 4, 5 },
    right = { 4, 5, 6 },
    up = { 6, 7, 8 },
  }

  local swordSwingAnchors = {
    [1] = { 18, 10 },
    [2] = { 15, 5 },
    [3] = { 8, 3 },
    [4] = { -2, 10 },
    [5] = { 1, 16 },
    [6] = { 8, 17 },
    [7] = { 9, 18 },
    [8] = { 14, 17 },
    [9] = { 16, 10 },
  }

  local swordChargeAnchors = {
    [1] = { 8, 6 },
    [2] = { 7, 6 },
  }

  local swordSpinAnchors = {
    [1] = { 0, 10 },
    [2] = { 1, 17 },
    [3] = { 8, 17 },
    [4] = { 13, 16 },
    [5] = { 16, 10 },
    [6] = { 14, 17 },
    [7] = { 8, 3 },
    [8] = { 2, 6 },
  }

  local function actionAnchor(anchors, frame)
    local anchor = anchors[math.min(frame, #anchors)]
    return anchor[1], anchor[2]
  end

  local function actionSprite(kind, combo, facing, frame)
    local name
    if kind == "sword" then
      local frames = swordSwingFrames[facing] or swordSwingFrames.down
      local sourceFrame = frames[math.min(frame, #frames)]
      name = string.format("sword_swing_%d.png", sourceFrame)
      local anchorX, anchorY = actionAnchor(swordSwingAnchors, sourceFrame)
      return looseSprite(name, "tloz-action-" .. name, anchorX, anchorY, false)
    elseif kind == "sword_charge" then
      name = string.format("sword_charge_%d.png", math.min(frame, 2))
      local anchorX, anchorY = actionAnchor(swordChargeAnchors, frame)
      return looseSprite(name, "tloz-action-" .. name, anchorX, anchorY, true)
    elseif kind == "sword_spin" then
      name = string.format("sword_spin_%d.png", math.min(frame, 8))
      local anchorX, anchorY = actionAnchor(swordSpinAnchors, frame)
      return looseSprite(name, "tloz-action-" .. name, anchorX, anchorY, false)
    elseif kind == "tool" and combo ~= "shield" then
      name = string.format("use_item_%d.png", math.min(frame, 2))
    else
      local assetFacing = facing
      name = string.format("shield_%s_%d.png", assetFacing, frame)
      return looseSprite(name, "tloz-action-" .. name, 0, 4, false, "")
    end
    return sprite(name, 1, false, "tloz-action-" .. name)
  end

  local function targetAt(state)
    local player = state.player
    return Hitbox.target(player, state.npcs, function(npc)
      return npc.def and not npc.def.item and not npc.def.pokemon
        and not npc.def.trainerClass and not npc.tlozDefeated
    end)
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

  local function appendParticles(state, particles)
    state.tlozParticles = state.tlozParticles or {}
    for _, particle in ipairs(particles or {}) do
      state.tlozParticles[#state.tlozParticles + 1] = particle
    end
  end

  local function removeNpc(state, npc, particles)
    npc.tlozDefeated = true
    npc.frozen = true
    appendParticles(state, particles)
  end

  local function purgeNpc(state, npc)
    npc.def.hidden = true
    npc.tlozGlowFrames = 0
    for index = #state.npcs, 1, -1 do
      if state.npcs[index] == npc then table.remove(state.npcs, index) end
    end
    for index = #state.entities, 1, -1 do
      if state.entities[index] == npc then table.remove(state.entities, index) end
    end
    state.tlozRespawns = state.tlozRespawns or {}
    if not npc.tlozRespawnQueued then
      npc.tlozRespawnQueued = true
      npc.tlozRespawn = {
        remaining = Feedback.RESPAWN_SECONDS,
        cellX = npc.tlozSpawnCellX or npc.def.x or npc.cellX,
        cellY = npc.tlozSpawnCellY or npc.def.y or npc.cellY,
        facing = npc.tlozSpawnFacing or npc.facing,
      }
      state.tlozRespawns[#state.tlozRespawns + 1] = npc
    end
  end

  local function containsNpc(list, npc)
    for _, entry in ipairs(list or {}) do
      if entry == npc then return true end
    end
    return false
  end

  local function restoreNpc(state, npc)
    local respawn = npc.tlozRespawn
    if not respawn then return end
    npc.cellX = respawn.cellX
    npc.cellY = respawn.cellY
    npc.px = respawn.cellX * 16
    npc.py = respawn.cellY * 16
    npc.facing = respawn.facing
    npc.targetX = nil
    npc.targetY = nil
    npc.progress = 0
    npc.moving = false
    npc.frozen = false
    npc.tlozDefeated = false
    npc.tlozGlowFrames = 0
    npc.tlozRespawn = nil
    npc.tlozRespawnQueued = nil
    npc.def.hidden = false
    if state.tlozCombat and state.tlozCombat.hits then
      state.tlozCombat.hits[npc.id] = nil
    end
    state.npcs = state.npcs or {}
    state.entities = state.entities or {}
    if not containsNpc(state.npcs, npc) then state.npcs[#state.npcs + 1] = npc end
    if not containsNpc(state.entities, npc) then
      state.entities[#state.entities + 1] = npc
    end
  end

  local function updateRespawns(state, dt)
    local respawns = state.tlozRespawns
    if not respawns then return end
    local elapsed = tonumber(dt) or 0
    if elapsed <= 0 then elapsed = 1 / 60 end
    for index = #respawns, 1, -1 do
      local npc = respawns[index]
      local respawn = npc.tlozRespawn
      if not respawn then
        table.remove(respawns, index)
      else
        respawn.remaining = respawn.remaining - elapsed
        if respawn.remaining <= 0 then
          restoreNpc(state, npc)
          table.remove(respawns, index)
        end
      end
    end
  end

  local function strike(state, action)
    local npc = targetAt(state)
    if npc then
      local result = Combat.registerHit(state.tlozCombat, npc.id)
      local feedback = Feedback.apply(npc, result, play)
      if feedback.defeated then
        removeNpc(state, npc, feedback.particles)
        purgeNpc(state, npc)
      end
      action.hit = true
      return
    end
    if environment:hit(state, { breakPots = true, cutGrass = true }) then
      action.hit = true
    end
  end

  local function startSword(state)
    state.tlozCombat = state.tlozCombat or Combat.new()
    local combo = Combat.nextCombo(state.tlozCombat)
    state.player.tlozAction = Action.new("sword", combo, "TLOZ_SWORD_TAP", 3, 2)
    play("TLOZ_LINK_VOICE_" .. tostring(combo))
    play("TLOZ_SWORD_" .. tostring(combo))
  end

  local function startSwordCharge(state)
    state.player.tlozAction = Action.new("sword_charge", 4, "TLOZ_SWORD_TAP", 2, 2)
    play("TLOZ_SWORD_CHARGE")
  end

  local function startSwordSpin(state, magic)
    state.player.tlozAction = Action.new("sword_spin", 4, "TLOZ_SWORD_TAP", 8, 4)
    play(magic and "TLOZ_SWORD_SPIN_MAGIC" or "TLOZ_SWORD_SPIN")
    if magic then play("TLOZ_SWORD_MAGIC") end
  end

  local function startShield(state)
    state.player.tlozAction = Action.new("shield", "shield")
    play("TLOZ_SHIELD")
  end

  local function startEquipment(state, equipment)
    if equipment.id == "shield" then
      startShield(state)
      return
    end
    state.player.tlozAction = Action.new("tool", equipment.id, equipment.hitAudio)
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
    Action.trackButton(action, bHeld)
    if action.kind == "sword_charge" then
      action.timer = action.timer + 1
      action.frame = 1 + math.floor(action.timer / 6) % 2
      if action.timer == 12 then play("TLOZ_SWORD_MAGIC_LOOP") end
      if not bHeld then startSwordSpin(state, action.timer >= 18) end
      return
    end
    action.timer = action.timer + 1
    local cadence = action.kind == "sword" and 4
      or action.kind == "sword_spin" and 2 or 3
    if action.timer % cadence == 0 then action.frame = action.frame + 1 end
    if action.kind == "tool" and action.combo == "bomb"
       and action.frame == 2 and not action.hit then
      play("TLOZ_BOMB_BLOW")
    end
    if action.frame == action.hitFrame and not action.hit then
      if action.kind == "tool" then
        if action.combo ~= "bomb" then play(action.hitAudio) end
        environment:hit(state, {
          breakPots = action.combo == "hammer" or action.combo == "bomb",
          cutGrass = action.combo == "hammer",
        })
        action.hit = true
      else
        strike(state, action)
      end
    end
    if action.frame > action.maxFrame then
      if Action.canCharge(action, bHeld) then
        startSwordCharge(state)
      else
        state.player.tlozAction = nil
      end
    end
  end

  local function updateNpcGlow(state)
    local defeated = {}
    for _, npc in ipairs(state.npcs or {}) do
      local wasGlowing = (npc.tlozGlowFrames or 0) > 0
      Feedback.tick(npc)
      if wasGlowing and npc.tlozDefeated and npc.tlozGlowFrames == 0 then
        defeated[#defeated + 1] = npc
      end
    end
    for _, npc in ipairs(defeated) do purgeNpc(state, npc) end
  end

  local function setLinkSprites(player)
    local link = player.tlozMovementSprite
    if not link then
      link = movementSprite()
      player.tlozMovementSprite = link
    end
    local active = player.moving or player.stepLanded
      or (player.bumpFrames and player.bumpFrames > 0)
    Movement.sync(link.movement, active, player.animClock or 0,
      player.stepFlip)
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
      NPC.draw = function(npc, camX, camY)
        if npc.tlozGlowFrames and npc.tlozGlowFrames > 0 and love.graphics then
          FeedbackRender.drawNpcGlow(npc, npcDraw, camX, camY, PaletteFX,
            SpriteRenderer)
          return
        end
        return npcDraw(npc, camX, camY)
      end
    end

    if not OverworldState.tlozRecompMania then
      OverworldState.tlozRecompMania = true
      local update = OverworldState.update
      OverworldState.update = function(state, dt)
        state.tlozParticles = state.tlozParticles or {}
        state.tlozCombat = state.tlozCombat or Combat.new()
        updateRespawns(state, dt)
        updateParticles(state)
        updateNpcGlow(state)
        environment:ensureMap(state)
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
        local result = update(state, dt)
        environment:update(state, dt)
        applyPlayerVisual(state.player)
        return result
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
          environment:draw(state, 1)
          FeedbackRender.drawParticles(state, 1, PaletteFX)
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
          environment:draw(state, scale)
          FeedbackRender.drawParticles(state, scale, PaletteFX)
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
    if payload and payload.game then
      playData = payload.game.data
      environment.game = payload.game
      environment:adoptSave()
      install(payload.game)
    end
  end)
  mod.events:on("save.created", function()
    environment:adoptSave()
  end)
  mod.events:on("save.loaded", function()
    environment:adoptSave()
  end)
  mod.events:on("map.entered", function(payload)
    local world = Game.world or Game.overworld
    if world and payload and payload.map then
      environment:enterMap(world, payload.map)
    end
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
    local world = Game.world or Game.overworld
    local sound = WarpEffects.fallSound(world, payload)
    if sound then play(sound) end
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
