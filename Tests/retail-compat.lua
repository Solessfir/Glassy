-- Run from the repository root with Lua 5.1. Frame mocks cover both XML layouts.
local function loadAddonFile(file, core, constants)
  assert(loadfile(file))("Glassy", {core, constants or {}, {}})
end

WOW_PROJECT_MAINLINE = 1
for _, project in ipairs({1, 2, 5, 19}) do
  WOW_PROJECT_ID = project
  local constants = {}
  loadAddonFile("Glassy/constants.lua", {}, constants)
  assert(constants.ENV == (project == 1 and "retail" or "classic"))
end

Mixin = function (object, mixin)
  for key, value in pairs(mixin) do object[key] = value end
  object.Init = function () end -- Skip unrelated layout and event setup.
  return object
end
local core = {Components = {}, Libs = {AceHook = {Embed = function (_, object)
  return object
end}}}
loadAddonFile("Glassy/Components/ChatTab.lua", core, {ACTIONS = {}, EVENTS = {}, COLORS = {}})
local function texture()
  return {SetTexture = function (self, value) assert(value == nil); self.cleared = true end}
end
local name = "GlassyTestTab"
for _, retail in ipairs({false, true}) do
  local frame = {GetName = function () return name end}
  local textures = {}
  for _, prefix in ipairs(retail and {"", "Active", "Highlight"} or {"", "Selected", "Highlight"}) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do
      local key, region = prefix..side, texture()
      textures[#textures + 1] = region
      if retail then frame[key] = region else _G[name..key] = region end
    end
  end
  _G[name] = frame
  core.Components.CreateChatTab({chatFrame = {GetName = function () return "GlassyTest" end}}, {})
  frame:ClearBackgroundTextures()
  for _, region in ipairs(textures) do assert(region.cleared, "Tab artwork was not cleared") end
  for _, prefix in ipairs({"", "Selected", "Highlight"}) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do _G[name..prefix..side] = nil end
  end
end

local protected = setmetatable({}, {__tostring = function () error("Protected text was inspected") end})
canaccessvalue = function (value) return value ~= protected end
strfind, strlen, strsub = string.find, string.len, string.sub
date = os.date
local processing = {}
local textCore = {
  GetModule = function () return processing end,
  db = {profile = {timestampsEnabled = false, emojisEnabled = true}},
}
loadAddonFile("Glassy/Modules/TextProcessing.lua", textCore)
assert(processing:ProcessText("Hello :smile:") == "Hello :smile:")
local rendered, original = processing:ProcessText(protected)
assert(rendered == protected and original == protected, "Protected text was changed")
assert(processing:ProcessTextures(protected) == protected)

canaccessvalue = nil
loadAddonFile("Glassy/Modules/TextProcessing.lua", textCore)
assert(processing:ProcessText("Classic chat") == "Classic chat")
print("PASS: Retail/Classic detection, both tab artwork layouts, protected-text passthrough, Classic without canaccessvalue.")
