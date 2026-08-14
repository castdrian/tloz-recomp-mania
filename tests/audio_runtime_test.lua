local engineRoot = os.getenv("TLOZ_ENGINE_ROOT")
  or "/Users/adrian/Documents/Codex/2026-07-30/thi/work/gen1recomp"
package.path = engineRoot .. "/?.lua;" .. engineRoot .. "/?/init.lua;" .. package.path

local created = {}
_G.love = {
  audio = {
    newSource = function(file, kind)
      assert(kind == "static")
      local source = { file = file, volume = 0, played = false }
      function source:getChannelCount() return 2 end
      function source:setVolume(value) self.volume = value end
      function source:stop() self.stopped = true end
      function source:play() self.played = true end
      created[#created + 1] = source
      return source
    end,
  },
}

package.loaded["src.render.Assets"] = { register = function() end }
package.loaded["src.core.Logger"] = { warn = function() end }
package.loaded["src.mods.Runtime"] = {
  wants = function() return false end,
  reportError = function() end,
}
package.loaded["src.core.Music"] = { duckForFanfare = function() end }

local Sound = require("src.core.Sound")
local root = "."
local function audio(name)
  return root .. "/assets/audio/" .. name .. ".wav"
end
local data = {
  audio = {
    sfx = {
      TLOZ_VILLAGER_HURT_1 = { file = audio("Minecraft_Villager_Hurt_1") },
      TLOZ_VILLAGER_DEATH = { file = audio("Minecraft_Villager_Death") },
    },
  },
}

local hurt = Sound.play(data, "TLOZ_VILLAGER_HURT_1")
local death = Sound.play(data, "TLOZ_VILLAGER_DEATH")
assert(hurt and hurt.played and hurt.volume == 0.8)
assert(death and death.played and death.volume == 0.8)
assert(created[1].file:match("Minecraft_Villager_Hurt_1%.wav$"))
assert(created[2].file:match("Minecraft_Villager_Death%.wav$"))

print("tloz-recomp-mania audio runtime tests passed")
