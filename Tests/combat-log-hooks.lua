-- Run from the repository root with Lua 5.1 and the bundled AceHook library.
strmatch = string.match
issecurevariable = function () return false end
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
local function noop() end
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
  object.RegisterForDrag, object.SetTextColor = noop, noop
  object.GetTextWidth = function () return 30 end
  object.SetParent, object.SetIgnoreParentAlpha, object.SetFrameStrata = noop, noop, noop
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
local constants = {ENV = "retail", ACTIONS = {}, EVENTS = {}, COLORS = {apache = {r = 1, g = 1, b = 1}}, TEXT_RIGHT_PADDING = 5}
local core = {
  Libs = {AceHook = AceHook, LibEasing = {}}, Components = {}, GetModule = function () return {} end,
  db = {profile = {textLeftPadding = 0}}, defaults = {profile = {textLeftPadding = 0}}, Subscribe = noop,
}
local utils = {}
assert(loadfile("Glassy/utils.lua"))("Glassy", {core, constants, utils})
local function loadComponent(name)
  assert(loadfile("Glassy/Components/"..name..".lua"))("Glassy", {core, constants, utils})
end

loadComponent("SlidingMessageFrame")
for _, environment in ipairs({"retail", "classic"}) do
  constants.ENV = environment
  for _, combatLog in ipairs({true, false}) do
    local native = frame("NativeChat")
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

constants.ENV = "retail"
local clicked, copied, shifted = false, 0, false
FCF_StopAlertFlash = function () assert(clicked, "Glassy ran before the native click") end
IsShiftKeyDown = function () return shifted end
GameTooltip = {IsOwned = function () return false end}
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
assert(GlassyTestTab:GetScript("OnClick") == onClick, "Glassy replaced the secure tab click")
assert(GlassyTestTab.HookScript == nativeHookScript, "AceHook replaced native HookScript")
assert(GlassyTestTab.SetAlpha == tabAlpha and GlassyTestTab.SetWidth == tabWidth, "Retail tab styling replaced native methods")
assert(GlassyTestTab.Text.SetTextColor == textColor, "Retail tab styling replaced native text color")
GlassyTestTab:Fire("OnClick", "LeftButton")
assert(saved == 1 and copied == 0)
shifted = true
GlassyTestTab:Fire("OnClick", "LeftButton")
assert(saved == 2 and copied == 1, "Shift-click copy stopped working")

-- Exercise the filter bar that Blizzard shows immediately before applying protected filters.
ChatFrame2 = frame("ChatFrame2")
ChatFrame2.isDocked = true
GENERAL_CHAT_DOCK = {selected = ChatFrame2}
CombatLogQuickButtonFrame_Custom = frame("FilterBar")
local barShow, barHookScript = CombatLogQuickButtonFrame_Custom.Show, CombatLogQuickButtonFrame_Custom.HookScript
local styles = 0
core.Components.GradientBackgroundMixin = {Init = function (object)
  object.StyleControls, object.UpdateLayout, object.RefreshButtons = noop, noop, noop
  object.StyleButtons = function () styles = styles + 1; assert(styles < 10, "Post-hook recursed") end
end}
loadComponent("CombatLogBar")
local bar = core.Components.CreateCombatLogBar({}, frame("GlassyLog"))
assert(bar.Show == barShow, "Glassy replaced the filter bar's native Show method")
assert(bar.HookScript == barHookScript, "Glassy overwrote the filter bar's native HookScript")
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
