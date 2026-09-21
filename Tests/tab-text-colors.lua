local fonts, listeners = {}, {}
local profile = {
  font = "inherited.ttf",
  fontFlags = "OUTLINE",
  tabFontFlags = "INHERIT",
  tabFontSize = 13,
  tabTextColor = {r = 0.1, g = 0.2, b = 0.3, a = 0.4},
  tabHighlightTextColor = {r = 0.2, g = 0.4, b = 0.6, a = 0.7},
  activeTabHighlightStrength = 0.5, hoverHighlightStrength = 1,
}
local function noop() end
local core = {Components = {}, db = {profile = profile}, Libs = {AceHook = {}, LSM = {
  MediaType = {FONT = "font"}, Fetch = function (_, _, name) return name end,
}}, GetModule = function () return fonts end,
  Subscribe = function (_, _, callback) listeners[#listeners + 1] = callback end}
local constants = {ACTIONS = {}, EVENTS = {UPDATE_CONFIG = "update"}, COLORS = {apache = {r = 1, g = 1, b = 1}}}
function CreateFont()
  return setmetatable({SetTextColor = function (self, ...) self.color = {...} end,
    SetShadowColor = function (self, _, _, _, alpha) self.shadowAlpha = alpha end,
    SetShadowOffset = function (self, x, y) self.shadowX, self.shadowY = x, y end,
    SetFont = function (self, path, size, flags) self.path, self.size, self.flags = path, size, flags end}, {__index = function () return noop end})
end
assert(loadfile("Glassy/Modules/Fonts.lua"))("Glassy", {core, constants})
fonts:OnInitialize()
fonts:OnEnable()
for _, font in pairs(fonts.fonts) do
  assert(font.flags == "", "Legacy shared flags and INHERIT must resolve to None")
  assert(font.shadowAlpha == 0, "No section should add a shadow by default")
end
profile.tabFontFlags, profile.messageFontFlags, profile.editBoxFontFlags = "", "THICKOUTLINE", "MONOCHROME,OUTLINE"
listeners[1]("font")
assert(fonts.fonts.GlassyChatDockFont.flags == "")
assert(fonts.fonts.GlassyCombatLogNormalFont.flags == "")
assert(fonts.fonts.GlassyCombatLogActiveFont.flags == "")
assert(fonts.fonts.GlassyCombatLogHighlightFont.flags == "")
assert(fonts.fonts.GlassyMessageFont.flags == "THICKOUTLINE")
assert(fonts.fonts.GlassyEditBoxFont.flags == "MONOCHROME,OUTLINE")
for _, style in ipairs({"SHADOW", "SHADOWOUTLINE", "SHADOWTHICKOUTLINE", ""}) do
  profile.tabFontFlags, profile.messageFontFlags, profile.editBoxFontFlags = style, style, style
  listeners[1]("font")
  for _, font in pairs(fonts.fonts) do
    assert(font.flags == style:gsub("^SHADOW", ""), "Only native outline flags may reach SetFont")
    assert(font.shadowAlpha == (style == "" and 0 or 1))
    assert(font.shadowX == (style == "" and 0 or 1))
    assert(font.shadowY == (style == "" and 0 or -1))
  end
end
assert(fonts.fonts.GlassyMessageFont.path == "inherited.ttf")
assert(fonts.fonts.GlassyChatDockFont.path == "inherited.ttf")
assert(fonts.fonts.GlassyEditBoxFont.path == "inherited.ttf")
profile.tabFont, profile.messageFont, profile.editBoxFont = "tabs.ttf", "messages.ttf", "input.ttf"
listeners[1]("font")
assert(fonts.fonts.GlassyMessageFont.path == "messages.ttf")
assert(fonts.fonts.GlassyEditBoxFont.path == "input.ttf")
for _, name in ipairs({"GlassyChatDockFont", "GlassyCombatLogNormalFont", "GlassyCombatLogActiveFont", "GlassyCombatLogHighlightFont"}) do
  assert(fonts.fonts[name].path == "tabs.ttf")
end
profile.messageFont = ""
listeners[1]("font")
assert(fonts.fonts.GlassyMessageFont.path == "inherited.ttf")
assert(fonts.fonts.GlassyEditBoxFont.path == "input.ttf")
for _, name in ipairs({"GlassyChatDockFont", "GlassyCombatLogNormalFont", "GlassyCombatLogActiveFont", "GlassyCombatLogHighlightFont"}) do
  assert(fonts.fonts[name].size == 13)
end
profile.tabFontSize = 18
listeners[1]("tabFontSize")
for _, name in ipairs({"GlassyChatDockFont", "GlassyCombatLogNormalFont", "GlassyCombatLogActiveFont", "GlassyCombatLogHighlightFont"}) do
  assert(fonts.fonts[name].size == 18, "Tab size changes must update all header fonts")
end
local function equals(actual, expected)
  for i = 1, 4 do assert(math.abs(actual[i] - expected[i]) < 0.00001) end
end
equals(fonts.fonts.GlassyCombatLogNormalFont.color, {0.1, 0.2, 0.3, 1})
equals(fonts.fonts.GlassyCombatLogActiveFont.color, {0.2, 0.4, 0.6, 1})
equals(fonts.fonts.GlassyCombatLogHighlightFont.color, {0.2, 0.4, 0.6, 1})
profile.tabTextColor = {r = 1, g = 0, b = 0, a = 0.25}
listeners[1]("tabTextColor")
equals(fonts.fonts.GlassyCombatLogNormalFont.color, {1, 0, 0, 1})
profile.tabHighlightTextColor = {r = 0, g = 0.1, b = 0.2, a = 0.3}
listeners[1]("tabHighlightTextColor")
equals(fonts.fonts.GlassyCombatLogActiveFont.color, {0, 0.1, 0.2, 1})
equals(fonts.fonts.GlassyCombatLogHighlightFont.color, {0, 0.1, 0.2, 1})

function Mixin(frame, ...)
  for index = 1, select("#", ...) do
    for key, value in pairs(select(index, ...)) do if key ~= "Init" then frame[key] = value end end
  end
  return frame
end
local text = {SetAlpha = function (self, alpha) self.alpha = alpha end}
TestTab = {Init = noop, Text = text, chatFrame = {GetName = function () return "Test" end},
  glassyHooks = {hooks = {[text] = {SetTextColor = function (_, ...) text.color = {...} end}}}}
assert(loadfile("Glassy/Components/ChatTab.lua"))("Glassy", {core, constants, {}})
local tab = core.Components.CreateChatTab({chatFrame = TestTab.chatFrame}, {})
tab:UpdateVisualState()
equals(text.color, {1, 0, 0, 1})
assert(text.alpha == 0.25)
SELECTED_CHAT_FRAME = tab.chatFrame
tab:UpdateVisualState()
equals(text.color, {0, 0.1, 0.2, 1})
assert(text.alpha == 0.3)
tab.glassyHovered = true
tab:UpdateVisualState()
equals(text.color, {0, 0.1, 0.2, 1})
assert(text.alpha == 0.3)

local alertText = {
  ClearAllPoints = noop, SetPoint = noop, GetLineHeight = function () return 13 end,
  SetText = function (self, value) self.value = value end,
  SetTextColor = function (self, ...) self.color = {...} end,
  SetAlpha = function (self, alpha) self.alpha = alpha end,
}
local alertParent = {
  icon = {SetVertexColor = noop, SetAlpha = noop},
  SetUnreadRowHeight = noop,
}
CreateFrame = function (_, _, parent)
  return {parent = parent, SetPoint = noop, SetHeight = noop,
    GetParent = function (self) return self.parent end,
    CreateFontString = function () return alertText end}
end
core.Localize = function (_, value) return value end
core.Components.CreateSeparatorFrame = function () return {SetPoint = noop, SetSeparatorColor = noop} end
core.Components.FadingFrameMixin = {
  Init = noop, SetFadeInDuration = noop, SetFadeOutDuration = noop,
  Show = function (self) self.shown = true end,
}
profile.messageFontSize = 13
profile.unreadMessageSeparatorColor = {}
assert(loadfile("Glassy/Components/NewMessageAlertFrame.lua"))("Glassy", {core, constants})
local alert = core.Components.CreateNewMessageAlertFrame(alertParent)
assert(alertText.value == "Jump to latest")
alert:SetUnread(true)
assert(alertText.value == "Unread messages")
print("PASS: tab and Combat Log text colors preserve opacity, highlight strength, and live updates")
