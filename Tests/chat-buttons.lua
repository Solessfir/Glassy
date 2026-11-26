-- Run from the repository root with Lua 5.1.
local function newFrame(parent)
  local frame = {parent = parent, shown = true, scripts = {}, hooks = {}}
  function frame:IsShown() return self.shown end
  function frame:Fire(event)
    for _, callback in ipairs(self.hooks[event] or {}) do callback(self) end
  end
  function frame:SetShown(shown)
    if self.shown == shown then return end
    self.shown = shown
    self:Fire(shown and "OnShow" or "OnHide")
  end
  function frame:GetParent() return self.parent end
  function frame:SetParent(newParent)
    self.parent = newParent
    self:Fire("SetParent")
  end
  function frame:ClearAllPoints() self.point = nil end
  function frame:SetPoint(...) self.point = {...}; self:Fire("SetPoint") end
  function frame:SetSize() end
  function frame:RegisterEvent() end
  function frame:SetScript(event, callback) self.scripts[event] = callback end
  function frame:HookScript(event, callback)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], callback)
  end
  return frame
end

CreateFrame = function (_, _, parent) return newFrame(parent) end
Mixin = function (frame, mixin)
  for key, method in pairs(mixin) do frame[key] = method end
  return frame
end
hooksecurefunc = function (frame, method, callback) frame:HookScript(method, callback) end
local combat = false
InCombatLockdown = function () return combat end
local profile, subscriptions = {}, {}
local core = {Components = {}, db = {profile = profile}, Subscribe = function (_, key, callback)
  subscriptions[key] = callback
end}
assert(loadfile("Glassy/Components/ChatButtons.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "config"}}})

local nativeParent, dock, container = newFrame(), newFrame(), newFrame()
function container:AddHoverRegion() end
QuickJoinToastButton = newFrame(nativeParent)
ChatFrameMenuButton = newFrame(nativeParent)
local buttons = core.Components.CreateChatButtons(container, dock)
assert(buttons:GetParent() == dock and not buttons:IsShown())
assert(#buttons.buttons == 2, "Clients without voice controls still get their available buttons")
profile.chatButtons = true
subscriptions.config("chatButtons")
assert(buttons:IsShown() and buttons.point[3] == "TOPRIGHT")
assert(QuickJoinToastButton:GetParent() == buttons and ChatFrameMenuButton.point[2] == QuickJoinToastButton)

local voice = newFrame(nativeParent)
voice.IsProtected = function () return true end
ChatFrameToggleVoiceMuteButton = voice
buttons.scripts.OnEvent(buttons, "ADDON_LOADED")
assert(voice.point[2] == QuickJoinToastButton and ChatFrameMenuButton.point[2] == voice)
voice:SetShown(false)
assert(ChatFrameMenuButton.point[2] == QuickJoinToastButton, "Voice leaving closes its gap without revealing its control")
ChatFrameMenuButton:SetParent(nativeParent)
assert(ChatFrameMenuButton:GetParent() == buttons, "A native layout pass cannot detach the chat menu")
combat = true
profile.chatButtons, profile.chatButtonsSide = false, "bottomright"
subscriptions.config("chatButtons")
assert(buttons:IsShown(), "Changes to protected buttons defer during combat")
combat = false
buttons.scripts.OnEvent(buttons, "PLAYER_REGEN_ENABLED")
assert(not buttons:IsShown() and buttons.point[3] == "BOTTOMRIGHT")
print("PASS: native chat button visibility, positioning, late voice controls and combat deferral")
