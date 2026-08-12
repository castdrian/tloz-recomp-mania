local file = io.open("combat.lua", "r")
local path = file and "combat.lua" or "mods/tloz-recomp-mania/combat.lua"
if file then file:close() end

local Combat = dofile(path)
local state = Combat.new()

assert(Combat.nextCombo(state) == 1)
assert(Combat.nextCombo(state) == 2)
assert(Combat.nextCombo(state) == 3)
assert(Combat.nextCombo(state) == 4)
assert(Combat.nextCombo(state) == 1)

local first = Combat.registerHit(state, "npc")
local second = Combat.registerHit(state, "npc")
local third = Combat.registerHit(state, "npc")

assert(first.count == 1 and not first.defeated)
assert(second.count == 2 and not second.defeated)
assert(third.count == 3 and third.defeated)
assert(Combat.registerHit(state, "other").count == 1)

assert(Combat.currentEquipment(state).id == "shield")
assert(Combat.nextEquipment(state).id == "bow")
assert(Combat.nextEquipment(state).id == "boomerang")
assert(#Combat.equipment == 12)
for _, equipment in ipairs(Combat.equipment) do
  assert(equipment.audio)
  if equipment.id ~= "shield" then assert(equipment.hitAudio) end
end
for _ = 1, 10 do Combat.nextEquipment(state) end
assert(Combat.currentEquipment(state).id == "shield")

print("tloz-recomp-mania combat tests passed")
