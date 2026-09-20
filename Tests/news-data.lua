---@diagnostic disable: undefined-global

local unpack = unpack or table.unpack

local function loadAddonFile(path, ...)
  local chunk = assert(loadfile(path))
  return chunk(...)
end

local Core = {}
loadAddonFile("Glassy/Modules/NewsData.lua", "Glassy", {Core})

assert(type(Core.NewsEntries) == "table", "news entries should load")
assert(Core.NewsEntries[1].name == "1.9.3 (2026-09-20)", "newest release should be first")

for index, entry in ipairs(Core.NewsEntries) do
  assert(type(entry.name) == "string" and entry.name ~= "", "release " .. index .. " needs a name")
  assert(type(entry.items) == "table" and type(entry.items[1]) == "string", "release " .. index .. " needs notes")
end

print("PASS: release-note data loads independently from the news window.")
