local function noop() end
local function texture()
  return {
    SetColorTexture = noop, SetGradient = noop, SetTexture = noop, ClearAllPoints = noop, SetPoint = noop,
    AddMaskTexture = function (self, mask) self.mask = mask end,
    RemoveMaskTexture = function (self, mask) assert(self.mask == mask) self.mask = nil end,
  }
end
Mixin = function (object, ...)
  for index = 1, select("#", ...) do
    for key, value in pairs(select(index, ...)) do object[key] = value end
  end
  return object
end
CreateColor = function () return {} end
CreateObjectPool = function (factory, reset) return {factory = factory, reset = reset} end
local scripts = {}
CreateFrame = function (_, _, parent)
  return {
    alpha = 1, GetParent = function () return parent end,
    GetAlpha = function (self) return self.alpha end,
    SetWidth = noop, SetHyperlinksEnabled = noop,
    SetScript = function (self, name, callback) scripts[self] = scripts[self] or {} scripts[self][name] = callback end,
    GetTop = function () error("Read secret geometry") end,
    GetHeight = function () error("Read secret geometry") end,
    CreateMaskTexture = texture, DisableDrawLayer = noop, EnableDrawLayer = noop,
    CreateFontString = function () return {
      ClearText = noop, ClearAllPoints = noop, SetIndentedWordWrap = noop,
      SetAlpha = function (self, alpha) self.alpha = alpha end,
    } end,
  }
end
local dispatches = 0
local callbacks = {}
local core = {
  Components = {
    FadingFrameMixin = {Init = noop, QuickHide = noop},
    GradientBackgroundMixin = {Init = noop, SetGradientBackground = function (self)
      self.leftBg, self.centerBg, self.rightBg = texture(), texture(), texture()
    end},
  },
  Libs = {AceHook = {}, LibEasing = {StopEasing = noop}},
  db = {profile = {frameWidth = 600, messageFontSize = 12, chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0.4}}},
  GetModule = function () return {} end,
  Dispatch = function () dispatches = dispatches + 1 end,
  Subscribe = function (_, event, callback) callbacks[event] = callback return callback end,
}
local constants = {ACTIONS = {HyperlinkClick = function () return {} end}, EVENTS = {UPDATE_CONFIG = "config",
  EDIT_BOX_LAYOUT_CHANGED = "layout", EDIT_BOX_VISIBILITY_CHANGED = "edit", MOUSE_ENTER = "enter", MOUSE_LEAVE = "leave"}}
for _, file in ipairs({"MessageLine", "SlidingMessageFrame", "SlidingMessageFrameLayout", "SlidingMessageFrameNative"}) do
  assert(loadfile("Glassy/Components/"..file..".lua"))("Glassy", {core, constants, {}})
end
local view = setmetatable({config = {height = 200}, state = {messages = {}, scrollAtBottom = true, scrollIndex = 1},
  slider = {ClearAllPoints = noop, SetPoint = noop, SetHeight = noop},
  gapBackground = {leftBg = texture(), centerBg = texture(), rightBg = texture(), CreateMaskTexture = texture},
  shown = true, SetHeight = noop, IsMouseOver = function () return true end,
  IsShown = function (self) return self.shown end,
}, {__index = core.Components.SlidingMessageFrameMixin})
local parent = {GetParent = function () return view end}
local function row(height)
  local message = core.Components.CreateMessageLine(parent)
  message.glassyHeight = height
  message.IsChainedTo = function () return true end
  message.ClearChainAnchor, message.SetChainAnchor = noop, noop
  return message
end
for _ = 1, 11 do table.insert(view.state.messages, row(20)) end
local messages = view.state.messages
view:UpdateTopFade()
assert(not messages[1].glassyTopMasked, "Absent profile setting keeps the feature off")
core.db.profile.topFade = true
view.shown = false
view:UpdateTopFade()
assert(not messages[1].glassyTopMask, "Hidden tabs must defer mask creation")
view.shown = true
view:UpdateTopFade()
assert(messages[1].text.alpha == 0 and messages[4].text.alpha > 0 and messages[4].text.alpha < 1)
assert(messages[11].text.alpha == 1 and messages[1].alpha == 1, "Top fading must preserve the inactivity alpha")
assert(messages[1].leftBg.mask == messages[1].glassyTopMask and view.gapBackground.leftBg.mask,
  "Both row backgrounds and the continuous gap background need the top mask")
scripts[messages[1]].OnHyperlinkClick(nil, "link", "text", "LeftButton")
assert(dispatches == 0, "Invisible text must not receive hyperlink clicks")
scripts[messages[11]].OnHyperlinkClick(nil, "link", "text", "LeftButton")
assert(dispatches == 1)
local alpha = messages[4].text.alpha
view:SetSlideOffset(-20)
assert(messages[4].text.alpha > alpha, "Sliding rows must recompute their fade from the animated offset")
view.state.scrollAtBottom = false
view:UpdateTopFade()
for _, message in ipairs(messages) do assert(message.text.alpha == 1 and not message.leftBg.mask) end
assert(not view.gapBackground.leftBg.mask, "Scrollback restores all background opacity")
view.state.scrollAtBottom = true
view:SetSlideOffset(0)
messages[3].glassyHeight = nil
view:UpdateTopFade()
assert(messages[1].text.alpha == 1 and messages[3].text.alpha == 1, "Secret heights must not be guessed")
assert(messages[4].text.alpha < 1, "Readable rows below secret text still fade")
messages[3].glassyHeight = 20
view.config.height = 35
view:UpdateViewportHeight()
for _, message in ipairs(messages) do assert(message.text.alpha == 1) end
assert(not messages[1].leftBg.mask, "Short windows must keep the newest lines readable")
view.config.height = 200
view:UpdateViewportHeight()
view.state.jumpingToBottom = true
view:UpdateTopFade()
assert(messages[1].text.alpha == 1 and not messages[1].leftBg.mask)
view.state.jumpingToBottom = false
view.detachedContainer = {}
view:LayoutMessages()
assert(messages[1].text.alpha == 0 and messages[1].leftBg.mask, "Detached chats and history layout must refresh fading")
view:SubscribeToEvents()
core.db.profile.topFade = false
callbacks.config("topFade")
assert(messages[1].text.alpha == 1 and not messages[1].leftBg.mask, "Changing the setting restores existing rows immediately")
view.state.isCombatLog = true
core.db.profile.topFade = true
view:UpdateTopFade()
assert(not messages[1].leftBg.mask, "Combat log rendering must remain unchanged")
local pool = core.Components.CreateMessageLinePool(parent)
messages[1]:SetTopAlpha(0)
messages[1]:SetTopMask(view, 80)
pool.reset(nil, messages[1])
assert(messages[1].text.alpha == 1 and not messages[1].leftBg.mask, "Pooled rows must lose their old fade state")
print("PASS: top fade follows layout and animation without reading secret geometry or changing inactivity fading")
