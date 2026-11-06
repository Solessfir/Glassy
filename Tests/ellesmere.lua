-- Run from the repository root with Lua 5.1.
CLOSE = "Close"
local reported = {}
geterrorhandler = function () return function (err) reported[#reported + 1] = err end end

local registered
EllesmereUI = {RegisterSkin = function (name, callback) assert(name == "Glassy"); registered = callback end}

local module, dispatched, fontsSelected = {}, {}, 0
local gold = {r = 1, g = 209 / 255, b = 0, a = 0.7}
local core = {
  defaults = {profile = {tabTextColor = gold, tabHighlightTextColor = {r = 1, g = 209 / 255, b = 0, a = 1}}},
  GetModule = function () return module end,
  Dispatch = function (_, _, key) dispatched[#dispatched + 1] = key end,
  SelectDefaultFont = function () fontsSelected = fontsSelected + 1 end,
}
-- The saved label color is the default as WoW's color picker stores it: a 32-bit float, not exactly 209 / 255.
core.db = {profile = {tabTextColor = {r = 1, g = 0.8196079134941101, b = 0, a = 0.7},
  tabHighlightTextColor = {r = 0, g = 1, b = 0, a = 1}}}
local constants = {ACTIONS = {UpdateConfig = function (key) return "update", key end}}
assert(loadfile("Glassy/Modules/Ellesmere.lua"))("Glassy", {core, constants})
module:OnInitialize()

-- Windows created before EllesmereUI's login callback are skinned once it arrives.
local function region(objectType, fields)
  local object = {GetObjectType = function () return objectType end}
  for key, value in pairs(fields or {}) do object[key] = value end
  return object
end
local closeButton = region("Button", {GetText = function () return CLOSE end})
local statusBar = region("Button", {SetBackdrop = function () end})
local window = {frame = {GetChildren = function () return closeButton, statusBar, region("Frame") end}}
local editBox = {type = "EditBox", editbox = {}}
local textBox = {type = "MultiLineEditBox", scrollBG = {}, scrollBar = {}}
module:SkinWindow(window, {editBox, textBox})
assert(core:GetThemeColor("tabTextColor") == core.db.profile.tabTextColor, "Without EllesmereUI colors stay Glassy's")

local skinned, enabled, accent, looksChanged = {}, true, {12 / 255, 210 / 255, 159 / 255}, nil
local function record(name) return function (frame, opts) skinned[#skinned + 1] = {name, frame, opts} end end
local S = {
  Shell = record("Shell"), Button = record("Button"), Panel = record("Panel"),
  EditBox = record("EditBox"), ScrollBar = record("ScrollBar"),
  IsEnabled = function () return enabled end,
  GetAccentColor = function () return unpack(accent) end,
  GetFont = function () return "Fonts\\Ellesmere.ttf" end,
  OnLooksChanged = function (callback) looksChanged = callback end,
}
registered(S)
local function skinnedWith(name, frame)
  for _, entry in ipairs(skinned) do
    if entry[1] == name and entry[2] == frame then return entry end
  end
end
assert(skinnedWith("Shell", window.frame) and skinnedWith("Button", closeButton), "The window and its close button are skinned")
assert(skinnedWith("Panel", statusBar)[3].inset and skinnedWith("EditBox", editBox.editbox))
assert(skinnedWith("Panel", textBox.scrollBG) and skinnedWith("ScrollBar", textBox.scrollBar))
assert(fontsSelected == 1 and module:GetFontPath() == "Fonts\\Ellesmere.ttf", "The default font is re-resolved")
local updates = table.concat(dispatched, ",")
assert(updates:find("tabTextColor", 1, true) and updates:find("emojiDisplay", 1, true), "Themed elements refresh")

-- Untouched colors follow the accent with their own opacity; customized colors stay.
local themed = core:GetThemeColor("tabTextColor")
assert(themed.r == accent[1] and themed.g == accent[2] and themed.b == accent[3] and themed.a == 0.7)
assert(core:GetThemeColor("tabHighlightTextColor") == core.db.profile.tabHighlightTextColor)

accent = {1, 0, 0}
looksChanged()
assert(core:GetThemeColor("tabTextColor").g == 0, "Live accent changes reach Glassy")

enabled = false
assert(core:GetThemeColor("tabTextColor") == core.db.profile.tabTextColor and module:GetFontPath() == nil,
  "Turning Glassy's skin off in EllesmereUI restores Glassy's own looks")

-- Windows created later are skinned straight away, and skin errors never break Glassy.
enabled = true
S.Shell = function () error("skin failed") end
local lateWindow = {frame = {GetChildren = function () end}}
module:SkinWindow(lateWindow)
assert(#reported == 1 and reported[1]:find("skin failed", 1, true))
print("PASS: EllesmereUI skins Glassy windows and drives untouched colors and the default font")
