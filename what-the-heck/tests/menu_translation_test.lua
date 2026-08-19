local current = "red"
package.loaded["src.core.GameVersion"] = {
  get = function() return current end,
  generation = function() return current == "gold" and 2 or 1 end,
  isBlue = function() return current == "blue" end,
  isYellow = function() return current == "yellow" end,
}

local root = "what-the-heck/"
local wrappers = {}

local function registry()
  return {
    override = function() end,
    patch = function() end,
  }
end

local function makeMod()
  wrappers = {}
  return {
    path = root,
    read = function(_, name)
      local file = assert(io.open(root .. name, "r"))
      local value = file:read("*a")
      file:close()
      return value
    end,
    content = {
      text = registry(),
      strings = registry(),
      pokemon = registry(),
      moves = registry(),
      items = registry(),
      trainers = registry(),
    },
    hooks = {
      wrap = function(_, name, callback)
        wrappers[name] = callback
      end,
    },
    log = { info = function() end, warn = function() end },
  }
end

local start = dofile(root .. "main.lua")
local function nextItems(_, items)
  return items
end

for _, version in ipairs({ "red", "blue", "yellow", "gold" }) do
  current = version
  start(makeMod())
  assert(type(wrappers["ui.title_menu.items"]) == "function",
    version .. " title menu translation hook is missing")
  assert(type(wrappers["ui.start_menu.items"]) == "function",
    version .. " start menu translation hook is missing")

  local titleItems = wrappers["ui.title_menu.items"](nextItems, {}, {
    { label = "SAVE" },
    { label = "CONTINUE" },
  })
  assert(titleItems[1].label == "NOTE",
    version .. " title menu label was not translated")
  assert(titleItems[2].label == "CONTINUE",
    version .. " unchanged title label was altered")

  local startItems = wrappers["ui.start_menu.items"](nextItems, {}, {
    { label = "SWITCH" },
    { label = "CANCEL" },
    { label = "PACK" },
  })
  assert(startItems[1].label == "Important",
    version .. " start menu label was not translated")
  assert(startItems[2].label == "CANCEL",
    version .. " unchanged start label was altered")
  assert(startItems[3].label == "Installation",
    version .. " added menu label was not translated")
end

print("what-the-heck menu translation test passed")
