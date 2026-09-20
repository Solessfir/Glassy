-- Run from the repository root with Lua 5.1 and the bundled AceHook library.
strmatch = string.match
issecurevariable = function () return false end
GetTime = function () return 100 end
local function noop() end
C_Timer = {NewTimer = function () return {Cancel = noop} end}
local methodHooks = {}
hooksecurefunc = function (object, method, callback)
  if type(object) == "string" then callback, method, object = method, object, _G end
  local fn = object[method]
  methodHooks[fn] = methodHooks[fn] or {}
  table.insert(methodHooks[fn], callback)
end
local function nativeMethod(fn)
  local wrapper
  wrapper = function (...)
    local result = fn(...)
    for _, callback in ipairs(methodHooks[wrapper] or {}) do callback(...) end
    return result
  end
  return wrapper
end
dofile("libs/LibStub/LibStub.lua")
dofile("libs/AceHook-3.0/AceHook-3.0.lua")
local AceHook = LibStub("AceHook-3.0")
local queuedUpdates = 0
local uiManager = {QueueFrameForUpdate = function () queuedUpdates = queuedUpdates + 1 end}
local function frame(name)
  local object = {scripts = {}, postHooks = {}, shown = false, name = name}
  function object:GetName() return self.name end
  function object:GetScript(key) return self.scripts[key] end
  function object:SetScript(key, callback) self.scripts[key] = callback end
  function object:HasScript() return true end
  -- Keep native scripts separate, just as a secure post-hook must do in the game.
  function object:HookScript(key, callback)
    self.postHooks[key] = self.postHooks[key] or {}
    table.insert(self.postHooks[key], callback)
  end
  function object:Fire(key, ...)
    if self.scripts[key] then self.scripts[key](self, ...) end
    for _, callback in ipairs(self.postHooks[key] or {}) do callback(self, ...) end
  end
  function object:IsShown() return self.shown end
  function object:IsVisible() return self.shown end
  function object:Show()
    if not self.shown then self.shown = true; self:Fire("OnShow") end
  end
  function object:Hide()
    if self.shown then self.shown = false; self:Fire("OnHide") end
  end
  function object:SetShown(shown)
    if shown then self:Show() else self:Hide() end
  end
  object.ClearAllPoints, object.SetPoint, object.SetHeight = noop, noop, noop
  object.SetWidth, object.SetAlpha, object.SetNormalFontObject = noop, noop, noop
  object.SetHighlightFontObject = noop
  object.RegisterForDrag, object.SetTextColor = noop, noop
  object.GetTextWidth = function () return 30 end
  function object:GetParent() return self.parent end
  function object:SetParent(parent) self.parent = parent end
  object.SetIgnoreParentAlpha, object.SetFrameStrata = noop, noop
  for key, fn in pairs(object) do
    if type(fn) == "function" then object[key] = nativeMethod(fn) end
  end
  return object
end
Mixin = function (object, ...)
  for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do object[key] = value end
  end
  return object
end
CreateFrame = function (_, name) return frame(name) end
local constants = {ENV = "retail", ACTIONS = {}, EVENTS = {}, COLORS = {apache = {r = 1, g = 1, b = 1}}, DOCK_HEIGHT = 24, TEXT_RIGHT_PADDING = 5}
local core = {
  Libs = {AceHook = AceHook, LibEasing = {}}, Components = {},
  GetModule = function (_, name) return name == "UIManager" and uiManager or {} end,
  db = {profile = {activeTabHighlightStrength = 0.2, chatAlwaysVisible = false, chatHoldTime = 10, hoverHighlightStrength = 0.8, frameHeight = 230, frameWidth = 450, tabMessageSpacing = 0, textLeftPadding = 0}},
  defaults = {profile = {frameHeight = 230, frameWidth = 450, tabMessageSpacing = 0, textLeftPadding = 0}}, Subscribe = noop,
}
local utils = {}
assert(loadfile("Glassy/utils.lua"))("Glassy", {core, constants, utils})
local function loadComponent(name)
  assert(loadfile("Glassy/Components/"..name..".lua"))("Glassy", {core, constants, utils})
end

loadComponent("SlidingMessageFrame")
loadComponent("SlidingMessageFrameLayout")
loadComponent("SlidingMessageFrameNative")
local detachedContainer = frame("DetachedContainer")
local primaryContainer = frame("PrimaryContainer")
uiManager.container = primaryContainer
local layout = core.Components.CreateSlidingMessageFrame()
layout.state = {incomingMessages = {}, incomingScrollbackMessages = {}, isCombatLog = false, messages = {}}
layout.config = {height = 1, width = 1, overflowHeight = 60}
layout.slider = frame("Slider")
layout.overlay = {UpdateFrame = noop, Hide = noop, HideNewMessageAlert = noop}
layout.CancelDynamicEditBoxLayout = noop
layout.UpdateScrollChildRect = noop
layout.SetVerticalScroll = noop
layout.GetVerticalScrollRange = function () return 0 end
layout:SetLayout(detachedContainer, 320, 200, false, detachedContainer)
assert(layout.parent == detachedContainer and layout.config.width == 320 and layout.config.height == 176)
core.db.profile.tabMessageSpacing = 20
assert(layout:GetMessageFrameHeight() == 156, "Tab offset did not reduce the message area")
core.db.profile.tabMessageSpacing = 0
local persistentMessage = frame("PersistentMessage")
persistentMessage.shown = true
layout.state.messages = {persistentMessage}
core.db.profile.chatAlwaysVisible = true
layout:ScheduleMessageHides(layout.state.messages)
assert(persistentMessage.glassyHideAt == nil, "Always visible scheduled a message fade")
core.db.profile.chatAlwaysVisible = false
layout:ScheduleMessageHides(layout.state.messages)
assert(persistentMessage.glassyHideAt == 110, "Normal message fading was not restored")
layout:CancelMessageHideTimer(true)
layout.state.messages = {}
layout.chatFrame = {isDocked = false}
assert(layout:GetNativeLayoutParent() == detachedContainer and layout:GetNativeLayoutWidth() == 320)
local forwardedWidth
layout.hooks[layout.chatFrame] = {SetWidth = function (_, width) forwardedWidth = width end}
constants.ENV = "classic"
assert(layout:KeepDetachedNativeLayout("SetWidth", 375) and forwardedWidth == 375,
  "Classic detached layout did not preserve the native call")
constants.ENV = "retail"
forwardedWidth = nil
assert(layout:KeepDetachedNativeLayout("SetWidth", 400) and forwardedWidth == nil,
  "Retail detached layout repeated its native call")
layout.chatFrame.isDocked = true
assert(layout:GetNativeLayoutParent() == primaryContainer and layout:GetNativeLayoutWidth() == 450,
  "Docking retained the detached frame as the native anchor")
assert(not layout:KeepDetachedNativeLayout("SetWidth", 500), "Docked layout skipped Glassy's override")
layout:SetGlassyShown(true)
assert(detachedContainer:IsShown(), "Detached container did not follow its message frame visibility")
layout:SetLayout(primaryContainer, nil, nil, true, nil)
assert(layout.parent == primaryContainer and layout.config.width == 450 and layout.config.height == 206)
assert(not detachedContainer:IsShown(), "Docking left the detached container visible")

local typingFrame = core.Components.CreateSlidingMessageFrame()
local overlayShows, overlayHides = 0, 0
typingFrame.state = {editBoxVisible = false, messages = {}, mouseOver = false, scrollAtBottom = false, typing = false}
typingFrame.overlay = {
  Show = function () overlayShows = overlayShows + 1 end,
  HideDelay = function () overlayHides = overlayHides + 1 end,
}
typingFrame.CancelMessageHideTimer = noop
typingFrame.ScheduleVisibleMessageHides = noop
core.db.profile.chatShowWhileTyping = false
typingFrame:SetTyping(true)
assert(overlayShows == 1 and typingFrame.state.editBoxVisible, "Open edit box did not keep the unread row visible")
typingFrame:SetTyping(false)
assert(overlayHides == 1 and not typingFrame.state.editBoxVisible, "Closed edit box did not restore unread-row fading")

local batched = core.Components.CreateSlidingMessageFrame()
batched.state = {incomingMessages = {}, incomingScrollbackMessages = {}}
for index = 1, 40 do batched.state.incomingMessages[index] = index end
local processed = {}
batched.Update = function (_, incoming, reverse)
  assert(not reverse and #incoming <= 16, "Live messages exceeded the per-frame batch")
  for _, message in ipairs(incoming) do processed[#processed + 1] = message end
end
batched:OnFrame()
assert(#processed == 16 and #batched.state.incomingMessages == 24 and queuedUpdates == 1, "Live messages were not deferred")
batched:OnFrame()
batched:OnFrame()
assert(#processed == 40 and #batched.state.incomingMessages == 0 and queuedUpdates == 2, "Deferred live messages were lost")
for index = 1, 20 do batched.state.incomingScrollbackMessages[index] = index end
batched.Update = function (_, incoming, reverse)
  assert(reverse and #incoming <= 16, "Scrollback messages exceeded the per-frame batch")
end
batched:OnFrame()
assert(#batched.state.incomingScrollbackMessages == 4 and queuedUpdates == 3, "Scrollback messages were not deferred")

local scheduledLayout = core.Components.CreateSlidingMessageFrame()
scheduledLayout.state = {incomingMessages = {}, incomingScrollbackMessages = {}}
local layoutRefreshes, reprocessedText = 0, false
scheduledLayout.RefreshLayout = function (_, reprocessText)
  layoutRefreshes = layoutRefreshes + 1
  reprocessedText = reprocessText
end
scheduledLayout:ScheduleLayoutRefresh(false)
scheduledLayout:ScheduleLayoutRefresh(true)
assert(queuedUpdates == 4, "Repeated layout refreshes were not coalesced")
scheduledLayout:OnFrame()
assert(layoutRefreshes == 1 and reprocessedText, "The coalesced layout refresh lost text reprocessing")

for _, environment in ipairs({"retail", "classic"}) do
  constants.ENV = environment
  for _, combatLog in ipairs({true, false}) do
    local native = frame("NativeChat")
    native.isDocked = true
    local smf = core.Components.CreateSlidingMessageFrame()
    smf.chatFrame, smf.state = native, {isCombatLog = combatLog}
    local nativeShows, layouts = 0, 0
    native:SetScript("OnShow", function () nativeShows = nativeShows + 1 end)
    local show, hide, setShown, onShow = native.Show, native.Hide, native.SetShown, native:GetScript("OnShow")
    smf.ApplyPendingDynamicEditBoxLayout = function () layouts = layouts + 1 end
    smf.ClearMessages, smf.ReloadMessagesFromChatFrame = noop, noop
    smf:HookChatFrameVisibility(native)
    if environment == "retail" then
      assert(native.Show == show and native.Hide == hide and native.SetShown == setShown, "Retail native visibility was replaced")
      assert(native:GetScript("OnShow") == onShow, "Retail native OnShow was wrapped")
      assert(nativeShows == 0, "Installing Glassy invoked native OnShow")
      native:SetShown(true)
      assert(nativeShows == 1 and smf:IsShown() and layouts == 1)
      if combatLog then
        core.db.profile.combatLogHidden = true
        smf:ApplyCombatLogVisibility()
        assert(native:IsShown() and not smf:IsShown(), "Hiding Glassy changed Retail native visibility")
        core.db.profile.combatLogHidden = false
        smf:ApplyCombatLogVisibility()
      end
      assert(smf:IsShown() and nativeShows == 1, "Settings reapplied native filters")
      native:Hide()
      assert(not smf:IsShown())
    else
      native:Show()
      assert(smf:IsShown())
      assert(native:IsShown() == combatLog, "Classic/regular chat visibility changed")
      native:Hide()
      assert(not smf:IsShown())
    end
    smf:UnhookAll()
  end
end

constants.ENV = "classic"
local detachedNative = frame("DetachedNativeChat")
detachedNative.isDocked = false
local detachedSmf = core.Components.CreateSlidingMessageFrame()
detachedSmf.chatFrame = detachedNative
detachedSmf.state = {isCombatLog = false}
detachedSmf.ApplyPendingDynamicEditBoxLayout = noop
detachedSmf:HookChatFrameVisibility(detachedNative)
detachedNative:Show()
assert(detachedNative:IsShown() and detachedSmf:IsShown(), "Classic detached chat lost its movable native frame")
detachedNative:Hide()
assert(not detachedNative:IsShown() and not detachedSmf:IsShown())
detachedSmf:UnhookAll()

constants.ENV = "retail"
local clicked, copied, shifted = false, 0, false
FCF_StopAlertFlash = function () assert(clicked, "Glassy ran before the native click") end
IsShiftKeyDown = function () return shifted end
GameTooltip = {IsOwned = function () return false end}
CHAT_CHANNELS, CHAT_CONFIGURATION, DISPLAY, MINIMIZE = "Channels", "Settings", "Display", "Minimize"
ToggleChannelFrame = noop
local menuModifier
Menu = {ModifyMenu = function (tag, callback)
  assert(tag == "MENU_FCF_TAB")
  menuModifier = callback
end}
MenuUtil = {
  CreateButton = function (text, callback) return {text = text, callback = callback} end,
  GetElementText = function (description) return description.text end,
}
local minimizedFrame, minimizedSide
FCF_MinimizeFrame = function (chatFrame, side) minimizedFrame, minimizedSide = chatFrame, side end
core.GetModule = function () return {Show = function () copied = copied + 1 end} end
loadComponent("ChatTab")
GlassyTestTab = frame("GlassyTestTab")
GlassyTestTab.Text, GlassyTestTab.glow = frame("Text"), frame("Glow")
GlassyTestTab:SetScript("OnClick", function () clicked = true end)
local onClick, nativeHookScript = GlassyTestTab:GetScript("OnClick"), GlassyTestTab.HookScript
local tabAlpha, tabWidth, textColor = GlassyTestTab.SetAlpha, GlassyTestTab.SetWidth, GlassyTestTab.Text.SetTextColor
local saved = 0
local dock = {UpdateTabOrder = noop, SaveSelectedTab = function () saved = saved + 1 end}
core.Components.CreateChatTab({chatFrame = frame("GlassyTest")}, dock)
rawset(_G, "GlassyTest", GlassyTestTab.chatFrame)
assert(GlassyTestTab:GetScript("OnClick") == onClick, "Glassy replaced the secure tab click")
assert(GlassyTestTab.HookScript == nativeHookScript, "AceHook replaced native HookScript")
assert(GlassyTestTab.SetAlpha == tabAlpha and GlassyTestTab.SetWidth == tabWidth, "Retail tab styling replaced native methods")
assert(GlassyTestTab.Text.SetTextColor == textColor, "Retail tab styling replaced native text color")
GlassyTestTab.chatFrame.buttonSide = "right"
local menu = {{text = DISPLAY}, {text = CHAT_CONFIGURATION}}
function menu:EnumerateElementDescriptions()
  local index = 0
  return function ()
    index = index + 1
    if self[index] then return index, self[index] end
  end
end
function menu:Insert(description, index) table.insert(self, index or #self + 1, description) end
menuModifier(GlassyTestTab, menu)
assert(menu[1].text == MINIMIZE and menu[2].text == DISPLAY, "Detached minimize action was not placed before Display")
menu[1].callback()
assert(minimizedFrame == GlassyTestTab.chatFrame and minimizedSide == "RIGHT", "Detached minimize action used the wrong frame")
GlassyTestTab:Fire("OnClick", "LeftButton")
assert(saved == 1 and copied == 0)
shifted = true
GlassyTestTab:Fire("OnClick", "LeftButton")
assert(saved == 2 and copied == 1, "Shift-click copy stopped working")

loadComponent("ChatDock")
local nativeInsertCalls = 0
local function nativeInsert()
  nativeInsertCalls = nativeInsertCalls + 1
  return 2
end
local insertDock = {DOCKED_CHAT_FRAMES = {frame("General"), frame("All")}}
local detachedFrame = frame("Detached")
assert(core.Components.GetSafeDockInsertIndex(nativeInsert, insertDock, detachedFrame, 0, 0) == 3)
detachedFrame.isDocked = true
assert(core.Components.GetSafeDockInsertIndex(nativeInsert, insertDock, detachedFrame, 0, 0) == 2)
assert(nativeInsertCalls == 1, "Detached-tab geometry reached Blizzard's insertion calculation")

-- Exercise the filter bar that Blizzard shows immediately before applying protected filters.
ChatFrame2 = frame("ChatFrame2")
ChatFrame2.isDocked = true
GENERAL_CHAT_DOCK = {selected = ChatFrame2}
CombatLogQuickButtonFrame_Custom = frame("FilterBar")
local barShow, barHookScript = CombatLogQuickButtonFrame_Custom.Show, CombatLogQuickButtonFrame_Custom.HookScript
local styles = 0
core.Components.GradientBackgroundMixin = {Init = function (object)
  object.TestStyleButtons = object.StyleButtons
  object.StyleControls, object.UpdateLayout, object.RefreshButtons = noop, noop, noop
  object.StyleButtons = function () styles = styles + 1; assert(styles < 10, "Post-hook recursed") end
end}
loadComponent("CombatLogBar")
local bar = core.Components.CreateCombatLogBar({}, frame("GlassyLog"))
assert(bar.Show == barShow, "Glassy replaced the filter bar's native Show method")
assert(bar.HookScript == barHookScript, "Glassy overwrote the filter bar's native HookScript")
local normalButton = frame("CombatLogQuickButtonFrameButton1")
local activeButton = frame("CombatLogQuickButtonFrameButton2")
local function configureFilterButton(button, id)
  local text = frame(button.name.."Text")
  text.GetStringWidth, text.SetJustifyH = function () return 30 end, noop
  button.shown = true
  button.GetID = function () return id end
  button.GetFontString = function () return text end
  button.SetHighlightFontObject = function (_, font) button.highlightFont = font end
end
configureFilterButton(normalButton, 1)
configureFilterButton(activeButton, 2)
_G.CombatLogQuickButtonFrameButton1 = normalButton
_G.CombatLogQuickButtonFrameButton2 = activeButton
_G.Blizzard_CombatLog_Filters = {currentFilter = 2}
_G.Blizzard_CombatLog_CurrentSettings = {isTemp = false}
bar:TestStyleButtons()
assert(normalButton.highlightFont == "GlassyCombatLogHighlightFont")
assert(activeButton.highlightFont == "GlassyCombatLogActiveFont")
activeButton:Fire("OnEnter")
assert(activeButton.highlightFont == "GlassyCombatLogHighlightFont", "Hover highlight did not override the weaker active highlight")
activeButton:Fire("OnLeave")
assert(activeButton.highlightFont == "GlassyCombatLogActiveFont", "Active highlight was not restored after hover")
_G.Blizzard_CombatLog_CurrentSettings.isTemp = true
bar:TestStyleButtons()
assert(activeButton.highlightFont == "GlassyCombatLogHighlightFont", "Temporary filters remained highlighted")
local detachedBarParent = frame("DetachedCombatLog")
local detachedFadeParent = frame("DetachedCombatLogDock")
bar:SetGlassyParent(detachedBarParent, true, detachedFadeParent)
assert(bar.parent == detachedFadeParent and bar.glassyParent == detachedBarParent and bar.useParentWidth,
  "Combat Log bar did not follow its detached layout and fade parent")
bar:Show()
assert(bar:IsShown() and styles == 1)
core.db.profile.combatLogHidden = true
bar:Show()
assert(not bar:IsShown())
core.db.profile.combatLogHidden = false
bar:Show()
assert(bar:IsShown() and styles == 2)

-- The correcting layout callback must run once, preserve native identity, and remain removable.
local owner, region = AceHook:Embed({}), frame("Layout")
local nativePoint, corrections = region.SetPoint, 0
utils.hookPresentation(owner, region, "SetPoint", function (self, ...)
  corrections = corrections + 1
  assert(corrections < 10, "Layout correction recursed")
  owner.hooks[region].SetPoint(self, ...)
end)
region:SetPoint("LEFT", 0, 0)
assert(region.SetPoint == nativePoint and corrections == 1)
owner:UnhookAll()
region:SetPoint("LEFT", 0, 0)
assert(corrections == 1)
print("PASS: Retail native chat visibility, tab styling and filter bar methods preserved; post-hooks bounded; Classic visibility and Shift-click copy retained.")
