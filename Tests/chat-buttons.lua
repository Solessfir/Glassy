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

local function newTexture()
  local texture = {color = {1, 1, 1, 1}, alpha = 1, hooks = {}}
  function texture:SetVertexColor(...) self.color = {...} end
  function texture:GetVertexColor() return unpack(self.color) end
  function texture:SetColorTexture() end
  function texture:SetSize() end
  function texture:SetPoint() end
  function texture:SetAtlas(atlas)
    self.atlas = atlas
    if self.hooks.SetAtlas then self.hooks.SetAtlas(self, atlas) end
  end
  function texture:GetAtlas() return self.atlas end
  function texture:GetAlpha() return self.alpha end
  function texture:SetAlpha(alpha)
    self.alpha = alpha
    if self.hooks.SetAlpha then self.hooks.SetAlpha(self, alpha) end
  end
  function texture:HookScript(method, callback) self.hooks[method] = callback end
  function texture:SetTexture(path) self.path = path end
  function texture:SetTexCoord(left, right) self.coords = {left, right} end
  function texture:SetShown(shown) self.shown = shown end
  function texture:Show() self:SetShown(true) end
  function texture:Hide() self:SetShown(false) end
  return texture
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
wipe = function (values) for key in pairs(values) do values[key] = nil end end
C_Texture = {GetAtlasInfo = function () return {} end}
function core:GetThemeColor(key)
  if key == "tabHighlightTextColor" then return {r = 1, g = 0.9, b = 0.8, a = 0.95} end
  return {r = 0.8, g = 0.6, b = 0.4}
end
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
for _, button in ipairs(buttons.buttons) do
  button.CreateTexture = newTexture
  button.IsMouseOver = function () return false end
  button.normal = newTexture()
  function button:GetNormalTexture() return self.normal end
end
QuickJoinToastButton.FriendsButton = newTexture()
QuickJoinToastButton.FriendCount = newTexture()
voice.Icon = newTexture()
voice.Icon:SetAtlas("voicechat-icon-mic-mute")
profile.chatButtonsStyle = "glassy"
subscriptions.config("chatButtonsStyle")
local socialStyle = buttons.knownButtons[QuickJoinToastButton]
assert(socialStyle.icon.shown and QuickJoinToastButton.FriendsButton.color[4] == 0)
local voiceStyle = buttons.knownButtons[voice]
assert(voice.normal.color[4] == 0 and voice.Icon.color[4] == 0 and voiceStyle.icon.coords[1] == 5 / 8)
voice.Icon:SetAlpha(0.75)
voice.Icon:SetAlpha(1)
assert(voice.Icon:GetAlpha() == 0, "Native MouseDown and MouseUp alpha cannot reveal the replaced glyph")
voice.Icon:SetAtlas("chatframe-button-icon-mic-on")
assert(voiceStyle.icon.coords[1] == 4 / 8 and voice.Icon.atlas == "chatframe-button-icon-mic-on",
  "Native voice state changes replace the flat glyph without changing Blizzard's chosen atlas")
voice.Icon:SetAtlas("unrecognized-atlas")
assert(not voiceStyle.icon.shown and voice.Icon.color[4] == 1 and voice.Icon:GetAlpha() == 1)
QuickJoinToastButton:Fire("OnEnter")
assert(socialStyle.icon.color[1] == 1 and socialStyle.icon.color[4] == 0.95)
QuickJoinToastButton:Fire("OnLeave")
assert(socialStyle.icon.color[1] == 0.8)
profile.chatButtonsColor = {r = 0.2, g = 0.4, b = 0.6, a = 0.35}
subscriptions.config("chatButtonsColor")
assert(socialStyle.icon.color[1] == 0.2 and socialStyle.icon.color[4] == 0.35)
profile.chatButtonsHoverColor = {r = 0.9, g = 0.7, b = 0.5, a = 0.6}
subscriptions.config("chatButtonsHoverColor")
QuickJoinToastButton:Fire("OnEnter")
assert(socialStyle.icon.color[1] == 0.9 and socialStyle.icon.color[4] == 0.6
  and QuickJoinToastButton.FriendCount.color[4] == 0.6, "A custom hover color and opacity also apply to counts")
profile.chatButtonsStyle = "blizzard"
subscriptions.config("chatButtonsStyle")
assert(not socialStyle.icon.shown and QuickJoinToastButton.FriendsButton.color[4] == 1)
assert(voice.normal.color[4] == 1 and voice.Icon.color[1] == 1 and voice.Icon.color[4] == 1)

combat = true
profile.chatButtons, profile.chatButtonsSide = false, "bottomright"
subscriptions.config("chatButtons")
assert(buttons:IsShown(), "Changes to protected buttons defer during combat")
combat = false
buttons.scripts.OnEvent(buttons, "PLAYER_REGEN_ENABLED")
assert(not buttons:IsShown() and buttons.point[3] == "BOTTOMRIGHT")
print("PASS: native chat button visibility, positioning, late voice controls and combat deferral")
