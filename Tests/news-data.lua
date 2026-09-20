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

local news, openNews = {}, nil
local function noop() end
local function widget()
  local native = {shown = false}
  function native:Hide() self.shown = false end
  return setmetatable({frame = native,
    Show = function () native.shown = true end,
    Hide = function () native:Hide() end,
  }, {__index = function () return noop end})
end
Core.NewsEntries = {}
Core.Version = "test"
Core.Libs = {AceGUI = {Create = widget}}
Core.GetModule = function () return news end
Core.Localize = function (_, text) return text end
Core.Subscribe = function (_, _, callback) openNews = callback end
UISpecialFrames = {}
loadAddonFile("Glassy/Modules/News.lua", "Glassy", {Core, {EVENTS = {OPEN_NEWS = "news"}}})
news:OnEnable()
openNews()
assert(GlassyNewsFrame.shown)
assert(UISpecialFrames[1] == "GlassyNewsFrame")
_G[UISpecialFrames[1]]:Hide()
assert(not GlassyNewsFrame.shown)
news:OnEnable()
assert(#UISpecialFrames == 1, "Escape registration must not be duplicated")
print("PASS: news window registers for Escape and can reopen")
