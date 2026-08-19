local current = "red"
package.loaded["src.core.GameVersion"] = {
  get = function() return current end,
  generation = function() return current == "gold" and 2 or 1 end,
  isBlue = function() return current == "blue" end,
  isYellow = function() return current == "yellow" end,
}

local root = "what-the-heck/"
local applied = {}
local expected = {
  red = { text = 2582, strings = 960, pokemon = 151, moves = 165, items = 152, trainers = 47 },
  blue = { text = 2582, strings = 960, pokemon = 151, moves = 165, items = 152, trainers = 47 },
  yellow = { text = 2706, strings = 960, pokemon = 151, moves = 165, items = 152, trainers = 47 },
  gold = { text = 3042, strings = 960, pokemon = 251, moves = 251, items = 247, trainers = 562 },
}

local function size(values)
  local count = 0
  for _ in pairs(values) do count = count + 1 end
  return count
end

local function hasRelayIArtifact(value)
  return value:find("I[ ]*%-[ ]*") ~= nil
end

local function makeMod()
  applied = { text = {}, strings = {}, pokemon = {}, moves = {}, items = {}, trainers = {} }
  local function registry(name)
    return {
      override = function(_, id, value) applied[name][id] = value end,
      patch = function(_, id, value) applied[name][id] = value.name end,
    }
  end
  return {
    path = root,
    read = function(_, name)
      local file = assert(io.open(root .. name, "r"))
      local value = file:read("*a")
      file:close()
      return value
    end,
    content = {
      text = registry("text"),
      strings = registry("strings"),
      pokemon = registry("pokemon"),
      moves = registry("moves"),
      items = registry("items"),
      trainers = registry("trainers"),
    },
    log = { info = function() end, warn = function() end },
  }
end

local start = dofile(root .. "main.lua")
for _, version in ipairs({ "red", "blue", "yellow", "gold" }) do
  current = version
  start(makeMod())
  assert(size(applied.text) == expected[version].text, version .. " text catalog size changed")
  for _, value in pairs(applied.text) do
    assert(not value:find("/", 1, true), version .. " text contains a relay slash artifact")
    assert(not hasRelayIArtifact(value), version .. " text contains a relay I artifact")
  end
  assert(size(applied.strings) == expected[version].strings, version .. " engine string catalog size changed")
  assert(applied.strings["%s wants\nto fight!"]:find("%s", 1, true), version .. " lost a format directive")
  for _, value in pairs(applied.strings) do
    assert(not hasRelayIArtifact(value), version .. " engine strings contain a relay I artifact")
  end
  if version ~= "gold" then
    assert(applied.text["_AIBattleUseItemText"]:find("{RAM:wTrainerName}", 1, true), version .. " lost a runtime placeholder")
    assert(applied.text["_AIBattleUseItemText"]:find("\n", 1, true), version .. " lost a text control")
  end
  for _, name in ipairs({ "pokemon", "moves", "items", "trainers" }) do
    assert(size(applied[name]) == expected[version][name], version .. " " .. name .. " catalog size changed")
    for _, value in pairs(applied[name]) do
      assert(not value:find("/", 1, true), version .. " " .. name .. " contains an unexpected slash")
      assert(not hasRelayIArtifact(value), version .. " " .. name .. " contains an unexpected I artifact")
    end
  end
end

print("what-the-heck translation mod test passed")
