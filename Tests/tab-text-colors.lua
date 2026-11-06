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
  GetThemeColor = function (self, key) return self.db.profile[key] end,
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

local function createFamily(members)
  local family = CreateFont()
  family.members = {}
  for _, info in ipairs(members) do
    family.members[info.alphabet] = CreateFont()
    family.members[info.alphabet].path = info.file
  end
  family.GetFontObjectForAlphabet = function (self, alphabet) return self.members[alphabet] end
  return family
end
ChatFontNormal = createFamily({})
for _, alphabet in ipairs({"roman", "korean", "simplifiedchinese", "traditionalchinese", "russian"}) do
  ChatFontNormal.members[alphabet] = {GetFont = function () return alphabet .. ".ttf", 14, "" end}
end
CreateFontFamily = function (_, members) return createFamily(members) end
local familyListeners = {}
core.Subscribe = function (_, _, callback) familyListeners[#familyListeners + 1] = callback end
fonts = {}
profile.messageFontSize = 15
assert(loadfile("Glassy/Modules/Fonts.lua"))("Glassy", {core, constants})
fonts:OnInitialize()
fonts:OnEnable()
local messageFamily = fonts.fonts.GlassyMessageFont.members
assert(messageFamily.roman.path == "inherited.ttf", "Custom fonts apply to Latin text")
for _, alphabet in ipairs({"korean", "simplifiedchinese", "traditionalchinese", "russian"}) do
  assert(messageFamily[alphabet].path == alphabet .. ".ttf", "Other alphabets keep native chat fonts")
  assert(messageFamily[alphabet].size == profile.messageFontSize)
end
equals(fonts.fonts.GlassyCombatLogNormalFont.members.russian.color, {1, 0, 0, 1})
ChatFontNormal, CreateFontFamily = nil, nil

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
tab.glassyHovered = false

-- Unread counts grow the tab only while it is unselected, and selecting it clears them.
text.ClearAllPoints, text.SetPoint = noop, noop
local count = {SetPoint = noop}
function count:SetTextColor() end
function count:SetText(value) self.value = value end
function count:SetShown(shown) self.shown = not not shown end
function count:IsShown() return self.shown end
function count:GetStringWidth() return #(self.value or "") * 6 end
local relayouts = 0
tab.CreateFontString = function () return count end
tab.GetTextWidth = function () return 40 end
tab.SetWidth = function (self, width) self.width = width end
-- A count can change inside Blizzard's own tab update, so the dock only schedules its layout.
tab.glassyDock = {
  UpdateTabOrder = function () error("Tab layout must not run inside Blizzard's tab update") end,
  ScheduleTabOrder = function () relayouts = relayouts + 1 end,
}
local otherFrame = {}
GENERAL_CHAT_DOCK = {selected = otherFrame}
tab.chatFrame.isDocked = true
profile.textLeftPadding = 0
core.defaults = {profile = {textLeftPadding = 0}}
constants.TEXT_RIGHT_PADDING = 5
tab:AddUnreadMessage()
assert(tab.glassyUnreadCount == nil and count.value == nil, "Counts stay off by default")
profile.tabUnreadCount = true
tab:AddUnreadMessage()
tab:AddUnreadMessage()
assert(count.value == "2" and count.shown and tab.width == 40 + 5 + 4 + 6, "The count widens the tab")
assert(relayouts == 1, "Only a width change re-lays out the dock")
tab.glassyUnreadCount = 99
tab:AddUnreadMessage()
assert(count.value == "99+")
GENERAL_CHAT_DOCK.selected = tab.chatFrame
tab:AddUnreadMessage()
assert(tab.glassyUnreadCount == 100, "The selected tab does not count")
tab:UpdateVisualState()
assert(tab.glassyUnreadCount == 0 and not count.shown and tab.width == 45, "Selecting the tab clears its count")
GENERAL_CHAT_DOCK.selected = otherFrame
tab.chatFrame.isTemporary = true
tab:AddUnreadMessage()
GENERAL_CHAT_DOCK.selected = tab.chatFrame
tab:UpdateVisualState()
assert(tab.glassyUnreadCount == 0, "Whisper tabs clear their count once read")
tab.chatFrame.isTemporary = nil
GENERAL_CHAT_DOCK = nil

-- Whisper tabs place Blizzard's conversation icon before the name and widen the tab for it.
local iconPoints, textPoint = {}, nil
tab.conversationIcon = {
  IsShown = function () return true end, GetWidth = function () return 16 end,
  ClearAllPoints = function () iconPoints = {} end,
  SetPoint = function (_, ...) iconPoints[#iconPoints + 1] = {...} end,
}
text.SetPoint = function (_, point, x) textPoint = {point, x} end
tab:UpdateTextLayout()
assert(#iconPoints == 1 and iconPoints[1][1] == "LEFT" and iconPoints[1][3] == "LEFT" and iconPoints[1][5] == 0,
  "The icon keeps one centered anchor instead of Blizzard's two")
assert(textPoint[1] == "LEFT" and textPoint[2] == 16 + 3, "The name starts after the icon")
assert(tab.width == 16 + 3 + 40 + 5, "The tab is widened by the icon")
tab.conversationIcon = nil

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
