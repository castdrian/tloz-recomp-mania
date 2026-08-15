local Feedback = {}

Feedback.GLOW_FRAMES = 10
Feedback.PARTICLE_COUNT = 18
Feedback.RESPAWN_SECONDS = 10

local function hurtAudio(count)
  return "TLOZ_VILLAGER_HURT_" .. tostring((count - 1) % 4 + 1)
end

function Feedback.particles(npc)
  local particles = {}
  for index = 1, Feedback.PARTICLE_COUNT do
    local angle = (index / Feedback.PARTICLE_COUNT) * math.pi * 2
    local speed = 0.6 + (index % 4) * 0.35
    particles[#particles + 1] = {
      x = npc.px + 8,
      y = npc.py + 8,
      vx = math.cos(angle) * speed,
      vy = math.sin(angle) * speed - 1.1,
      life = 22 + index % 8,
      maxLife = 30,
      size = 1 + index % 2,
      color = { 1, 0.05, 0.05 },
    }
  end
  return particles
end

function Feedback.hit(npc, result)
  local count = tonumber(result and result.count) or 1
  local defeated = result and result.defeated or count >= 3
  npc.tlozGlowFrames = Feedback.GLOW_FRAMES
  return {
    audio = defeated and "TLOZ_VILLAGER_DEATH" or hurtAudio(count),
    defeated = defeated,
    particles = defeated and Feedback.particles(npc) or nil,
  }
end

function Feedback.apply(npc, result, play)
  local feedback = Feedback.hit(npc, result)
  if play then play(feedback.audio) end
  return feedback
end

function Feedback.wildHit(entity, result)
  local feedback = Feedback.hit(entity, result)
  feedback.audio = nil
  return feedback
end

function Feedback.tick(npc)
  local frames = tonumber(npc.tlozGlowFrames) or 0
  if frames <= 0 then
    npc.tlozGlowFrames = 0
    return false
  end
  npc.tlozGlowFrames = frames - 1
  return true
end

return Feedback
