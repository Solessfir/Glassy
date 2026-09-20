local fonts, listeners = {}, {}
local profile = {
  tabTextColor = {r = 0.1, g = 0.2, b = 0.3, a = 0.4},
  tabHighlightTextColor = {r = 0.2, g = 0.4, b = 0.6, a = 0.7},
  activeTabHighlightStrength = 0.5, hoverHighlightStrength = 1,
}
local function noop() end
local core = {Components = {}, db = {profile = profile}, Libs = {AceHook = {}, LSM = {
  MediaType = {FONT = "font"}, Fetch = function () return "test.ttf" end,
}}, GetModule = function () return fonts end,
  Subscribe = function (_, _, callback) listeners[#listeners + 1] = callback end}
local constants = {ACTIONS = {}, EVENTS = {UPDATE_CONFIG = "update"}, COLORS = {apache = {r = 1, g = 1, b = 1}}}
function CreateFont()
  return setmetatable({SetTextColor = function (self, ...) self.color = {...} end}, {__index = function () return noop end})
end
assert(loadfile("Glassy/Modules/Fonts.lua"))("Glassy", {core, constants})
fonts:OnInitialize()
fonts:OnEnable()
local function equals(actual, expected)
  for i = 1, 4 do assert(math.abs(actual[i] - expected[i]) < 0.00001) end
end
equals(fonts.fonts.GlassyCombatLogNormalFont.color, {0.1, 0.2, 0.3, 1})
equals(fonts.fonts.GlassyCombatLogActiveFont.color, {0.2, 0.4, 0.6, 1})
equals(fonts.fonts.GlassyCombatLogHighlightFont.color, {0.4, 0.8, 1, 1})
profile.tabTextColor = {r = 1, g = 0, b = 0, a = 0.25}
listeners[1]("tabTextColor")
equals(fonts.fonts.GlassyCombatLogNormalFont.color, {1, 0, 0, 1})
profile.tabHighlightTextColor = {r = 0, g = 0.1, b = 0.2, a = 0.3}
listeners[1]("tabHighlightTextColor")
equals(fonts.fonts.GlassyCombatLogActiveFont.color, {0, 0.1, 0.2, 1})
equals(fonts.fonts.GlassyCombatLogHighlightFont.color, {0, 0.2, 0.4, 1})

function Mixin(frame, mixin)
  for key, value in pairs(mixin) do if key ~= "Init" then frame[key] = value end end
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
equals(text.color, {0, 0.2, 0.4, 1})
assert(text.alpha == 0.3)
print("PASS: tab and Combat Log text colors preserve opacity, highlight strength, and live updates")
