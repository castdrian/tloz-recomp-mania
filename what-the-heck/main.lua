local NAMED_CATALOGS = { "pokemon", "moves", "items", "trainers" }

local function loadVersionModule()
  local names = { "src.core.GameVersion", "src.gen2.core.GameVersion" }
  for _, name in ipairs(names) do
    local ok, value = pcall(require, name)
    if ok and type(value) == "table" then return value end
  end
  return {}
end

local function activeVersion()
  local version = loadVersionModule()
  local generation = type(version.generation) == "function" and version.generation()
  local id = type(version.get) == "function" and version.get() or ""
  id = tostring(id):lower()
  if generation == 2 or id == "gold" or id == "gen2" then return "gold" end
  if id == "blue" or (type(version.isBlue) == "function" and version.isBlue()) then
    return "blue"
  end
  if id == "yellow" or (type(version.isYellow) == "function" and version.isYellow()) then
    return "yellow"
  end
  return "red"
end

local function readCatalog(mod, name)
  local source = mod:read("lang/" .. name .. ".lua")
  if type(source) ~= "string" then return {} end
  local chunk, err = loadstring(source, "@what-the-heck/lang/" .. name .. ".lua")
  if not chunk then
    mod.log:warn("could not load translation catalog %s: %s", name, tostring(err))
    return {}
  end
  local ok, catalog = pcall(chunk)
  if not ok or type(catalog) ~= "table" then
    mod.log:warn("translation catalog %s did not return a table", name)
    return {}
  end
  return catalog
end

local function applyCatalog(registry, catalog)
  if not registry then return 0 end
  local count = 0
  for id, value in pairs(catalog) do
    if type(id) == "string" and type(value) == "string" and value ~= "" then
      registry:override(id, value)
      count = count + 1
    end
  end
  return count
end

local function applyNamedCatalog(mod, version, name)
  local registry = mod.content and mod.content[name]
  if not registry or type(registry.patch) ~= "function" then return 0 end
  local count = 0
  for id, value in pairs(readCatalog(mod, version .. "_" .. name)) do
    if type(id) == "string" and type(value) == "string" and value ~= "" then
      registry:patch(id, { name = value })
      count = count + 1
    end
  end
  return count
end

return function(mod)
  local version = activeVersion()
  local textCount = applyCatalog(mod.content.text, readCatalog(mod, version))
  local stringCount = applyCatalog(mod.content.strings, readCatalog(mod, "strings"))
  local namedCounts = {}
  for _, name in ipairs(NAMED_CATALOGS) do
    namedCounts[name] = applyNamedCatalog(mod, version, name)
  end
  local namedCount = namedCounts.pokemon + namedCounts.moves + namedCounts.items + namedCounts.trainers
  mod.log:info("loaded %d %s nonsense text entries, %d engine strings, and %d named records", textCount, version, stringCount, namedCount)
end
