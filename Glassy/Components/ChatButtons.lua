local Core, Constants = unpack(select(2, ...))

local ICON_TEXTURE = "Interface\\AddOns\\Glassy\\Glassy\\Assets\\chatButtonIcons"
local VOICE_GLYPHS = {
  ["chatframe-button-icon-voicechat"] = 2,
  ["chatframe-button-icon-headset"] = 6,
  ["chatframe-button-icon-speaker-on"] = 2,
  ["chatframe-button-icon-speaker-off"] = 3,
  ["chatframe-button-icon-mic-on"] = 4,
  ["chatframe-button-icon-mic-off"] = 5,
  ["chatframe-button-icon-mic-silenced"] = 5,
  ["chatframe-button-icon-mic-silenced-off"] = 5,
  ["voicechat-icon-speaker"] = 2,
  ["voicechat-icon-speaker-mute"] = 3,
  ["voicechat-icon-speaker-silenced"] = 3,
  ["voicechat-icon-speaker-mutesilenced"] = 3,
  ["voicechat-icon-mic"] = 4,
  ["voicechat-icon-mic-mute"] = 5,
  ["voicechat-icon-mic-silenced"] = 5,
  ["voicechat-icon-mic-mutesilenced"] = 5,
}

local BUTTON_NAMES = {
  "QuickJoinToastButton",
  "ChatFrameChannelButton",
  "ChatFrameToggleVoiceDeafenButton",
  "ChatFrameToggleVoiceMuteButton",
  "ChatFrameMenuButton",
}

local POSITIONS = {
  left = {"TOPRIGHT", "TOPLEFT", -2, 0},
  right = {"TOPLEFT", "TOPRIGHT", 2, 0},
  topleft = {"BOTTOMLEFT", "TOPLEFT", 0, 2},
  topright = {"BOTTOMRIGHT", "TOPRIGHT", 0, 2},
  bottomleft = {"TOPLEFT", "BOTTOMLEFT", 0, -2},
  bottomright = {"TOPRIGHT", "BOTTOMRIGHT", 0, -2},
}

local ChatButtonsMixin = {}
Core.Components.ChatButtonsMixin = ChatButtonsMixin

function Core:GetChatButtonColor(hovered)
  local color = self.db.profile[hovered and "chatButtonsHoverColor" or "chatButtonsColor"]
  if color and color.r >= 0 then return color end
  return self:GetThemeColor(hovered and "tabHighlightTextColor" or "tabTextColor")
end

local function setArtwork(style, texture, red, green, blue, alpha)
  if not (texture and texture.GetVertexColor and texture.SetVertexColor) then return end
  if not style.colors[texture] then
    local original = {texture:GetVertexColor()}
    if #original == 0 then return end
    style.colors[texture] = original
  end
  texture:SetVertexColor(red, green, blue, alpha)
end

local function tintIcon(button, style, hovered)
  if not style.enabled then return end
  local color = Core:GetChatButtonColor(hovered)
  local r, g, b, a = color.r, color.g, color.b, color.a or 1
  style.glyph:SetVertexColor(r, g, b, a)
  setArtwork(style, button.FriendCount, r, g, b, a)
  setArtwork(style, button.QueueCount, r, g, b, a)
end

local function setNativeAlpha(style, native, alpha)
  style.settingNativeAlpha = true
  native:SetAlpha(alpha)
  style.settingNativeAlpha = nil
end

local function hideNativeIcon(style, native, hide)
  if not (native and native.SetAlpha and native.GetAlpha) then return end
  if hide then
    if style.nativeAlpha == nil then style.nativeAlpha = native:GetAlpha() end
    setNativeAlpha(style, native, 0)
  elseif style.nativeAlpha ~= nil then
    local alpha = style.nativeAlpha
    style.nativeAlpha = nil
    setNativeAlpha(style, native, alpha)
  end
end

local function updateGlyph(button, style)
  local native = button.Icon
  local social = button == _G.QuickJoinToastButton
  local menu = button == _G.ChatFrameMenuButton
  local slot = social and 0 or menu and 1 or (native and native.GetAtlas and VOICE_GLYPHS[native:GetAtlas()])
  if slot and native and native.GetAlpha and native.SetAlpha and style.nativeAlpha == nil then
    style.nativeAlpha = native:GetAlpha()
  end
  if native then setArtwork(style, native, 1, 1, 1, slot and 0 or 1) end
  hideNativeIcon(style, native, not not slot)
  if slot then style.icon:SetTexCoord(slot / 8, (slot + 1) / 8, 0, 1) end
  style.icon:SetShown(slot ~= nil and slot ~= false)
  style.glyph = slot and style.icon or native
  tintIcon(button, style, button:IsMouseOver())
end

local function updateButtonStyle(button, style, enabled)
  if not enabled then
    if not style.enabled then return end
    for texture, original in pairs(style.colors) do texture:SetVertexColor(unpack(original)) end
    hideNativeIcon(style, button.Icon, false)
    wipe(style.colors)
    if style.icon then style.icon:Hide() end
    style.enabled = false
    return
  end

  local social = button == _G.QuickJoinToastButton
  if not social and button ~= _G.ChatFrameMenuButton and not button.Icon then return end

  if not style.icon then
    style.icon = button:CreateTexture(nil, "ARTWORK")
    style.icon:SetSize(16, 16)
    style.icon:SetPoint("CENTER", 0, social and 6 or 0)
    style.icon:SetTexture(ICON_TEXTURE)
    button:HookScript("OnEnter", function () tintIcon(button, style, true) end)
    button:HookScript("OnLeave", function () tintIcon(button, style, false) end)
  end
  if button.Icon and button.Icon ~= style.hookedIcon and button.Icon.SetAtlas then
    style.hookedIcon = button.Icon
    _G.hooksecurefunc(button.Icon, "SetAtlas", function ()
      if style.enabled then updateGlyph(button, style) end
    end)
    if button.Icon.SetAlpha and button.Icon.GetAlpha then
      _G.hooksecurefunc(button.Icon, "SetAlpha", function (native, alpha)
        -- Blizzard's pressed and released states set alpha on the original icon.
        if style.enabled and style.nativeAlpha ~= nil and not style.settingNativeAlpha then
          style.nativeAlpha = alpha
          setNativeAlpha(style, native, 0)
        end
      end)
    end
  end
  style.enabled = true
  updateGlyph(button, style)
  setArtwork(style, button.FriendsButton, 1, 1, 1, 0)
  setArtwork(style, button.QueueButton, 1, 1, 1, 0)
  setArtwork(style, button.GetNormalTexture and button:GetNormalTexture(), 1, 1, 1, 0)
  setArtwork(style, button.GetPushedTexture and button:GetPushedTexture(), 1, 1, 1, 0)
  setArtwork(style, button.GetHighlightTexture and button:GetHighlightTexture(), 1, 1, 1, 0)
  setArtwork(style, button.GetDisabledTexture and button:GetDisabledTexture(), 1, 1, 1, 0)
end

function ChatButtonsMixin:CanChangeLayout()
  if _G.InCombatLockdown and _G.InCombatLockdown() then
    for _, button in ipairs(self.buttons) do
      if button.IsProtected and button:IsProtected() then return false end
    end
  end
  return true
end

function ChatButtonsMixin:Layout()
  if self.layingOut or not self:CanChangeLayout() then return end
  self.layingOut = true
  local side = Core.db.profile.chatButtonsSide
  if not POSITIONS[side] then side = "right" end
  local position = POSITIONS[side]
  local vertical = side == "left" or side == "right"
  local reverse = side == "topright" or side == "bottomright"
  self:ClearAllPoints()
  self:SetPoint(position[1], self.container, position[2],
    position[3] + (tonumber(Core.db.profile.chatButtonsOffsetX) or 0),
    position[4] + (tonumber(Core.db.profile.chatButtonsOffsetY) or 0))

  local previous
  for index = 1, #self.buttons do
    local button = self.buttons[reverse and (#self.buttons - index + 1) or index]
    if button:GetParent() ~= self then button:SetParent(self) end
    if button:IsShown() then
      button:ClearAllPoints()
      if not previous then
        button:SetPoint(position[1], self, position[1], 0, 0)
      elseif vertical then
        button:SetPoint("TOP", previous, "BOTTOM", 0, -2)
      elseif reverse then
        button:SetPoint("RIGHT", previous, "LEFT", -2, 0)
      else
        button:SetPoint("LEFT", previous, "RIGHT", 2, 0)
      end
      previous = button
    end
  end
  self.layingOut = nil
end

function ChatButtonsMixin:Update()
  if not self:CanChangeLayout() then return end
  self:SetShown(not not Core.db.profile.chatButtons)
  local styled = Core.db.profile.chatButtons and Core.db.profile.chatButtonsStyle == "glassy"
  for _, button in ipairs(self.buttons) do
    updateButtonStyle(button, self.knownButtons[button], styled)
  end
  self:Layout()
end

function ChatButtonsMixin:CollectButtons()
  local buttons = {}
  for _, name in ipairs(BUTTON_NAMES) do
    local button = _G[name]
    if button then buttons[#buttons + 1] = button end
    if button and not self.knownButtons[button] then
      self.knownButtons[button] = {colors = {}}
      self.container:AddHoverRegion(button)
      -- Keep Blizzard's click handlers, tooltips, voice state and menu generation intact.
      button:HookScript("OnShow", function () self:Layout() end)
      button:HookScript("OnHide", function () self:Layout() end)
      _G.hooksecurefunc(button, "SetPoint", function () self:Layout() end)
      _G.hooksecurefunc(button, "SetParent", function () self:Layout() end)
    end
  end
  self.buttons = buttons
  self:Update()
end

Core.Components.CreateChatButtons = function (container, dock)
  local frame = _G.CreateFrame("Frame", nil, dock)
  local object = _G.Mixin(frame, ChatButtonsMixin)
  object.container = container
  object.buttons, object.knownButtons = {}, {}
  object:SetSize(1, 1)
  object:RegisterEvent("ADDON_LOADED")
  object:RegisterEvent("PLAYER_REGEN_ENABLED")
  object:SetScript("OnEvent", function () object:CollectButtons() end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "chatButtons" or key == "chatButtonsSide" or key == "chatButtonsStyle" or key == "tabTextColor"
      or key == "chatButtonsColor" or key == "chatButtonsHoverColor" or key == "tabHighlightTextColor"
      or key == "chatButtonsOffsetX" or key == "chatButtonsOffsetY" then
      object:Update()
    end
  end)
  object:CollectButtons()
  return object
end
