---@diagnostic disable: undefined-global

local unpack = unpack or table.unpack

local function loadAddonFile(path, ...)
  local chunk = assert(loadfile(path))
  return chunk(...)
end

local Core = {}
loadAddonFile("Glassy/Modules/NewsData.lua", "Glassy", {Core})

assert(type(Core.NewsEntries) == "table", "news entries should load")
local latest = assert(io.open("LATEST.md", "r"))
local heading = latest:read("*l")
latest:close()
assert(Core.NewsEntries[1].name == heading:match("^# (.+)$"), "newest release should match LATEST.md")

for index, entry in ipairs(Core.NewsEntries) do
  assert(type(entry.name) == "string" and entry.name ~= "", "release " .. index .. " needs a name")
  assert(type(entry.items) == "table" and type(entry.items[1]) == "string", "release " .. index .. " needs notes")
end

print("PASS: release-note data loads independently from the news window.")
