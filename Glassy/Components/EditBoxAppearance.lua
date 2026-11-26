local Core, Constants, Utils = unpack(select(2, ...))
local EditBoxMixin = Core.Components.EditBoxMixin
local ASSETS = "Interface\\AddOns\\Glassy\\Glassy\\Assets\\"

local function setShape(texture, file)
  texture:SetTexture(ASSETS.."Tabs\\"..file)
  if texture.SetTextureSliceMargins then
    texture:SetTextureSliceMargins(8, 8, 8, 8)
    if texture.SetTextureSliceMode and _G.Enum and _G.Enum.UITextureSliceMode then
      texture:SetTextureSliceMode(_G.Enum.UITextureSliceMode.Stretched)
    end
  end
end

local function channelColor(editBox)
  local r, g, b = editBox.header:GetTextColor()
  if (_G.canaccessvalue and not (_G.canaccessvalue(r) and _G.canaccessvalue(g) and _G.canaccessvalue(b))) or not r then
    return 223 / 255, 186 / 255, 105 / 255
  end
  return r, g, b
end

function EditBoxMixin:UpdateGlassyStyle()
  local style = Core.db.profile.editBoxStyle
  local styled = style == "minimal" or style == "framed"
  local layers = self.glassyInputLayers
  if not styled then
    if layers then for _, texture in ipairs(layers) do texture:Hide() end end
    return
  end
  if not layers then
    layers = {}
    for index = 1, 6 do
      layers[index] = self:CreateTexture(nil, index <= 4 and "BACKGROUND" or "BORDER")
    end
    setShape(layers[1], "tabBackground")
    setShape(layers[2], "tabBorder")
    self.glassyInputLayers = layers
  end
  self.leftBg:Hide()
  self.centerBg:Hide()
  self.rightBg:Hide()
  if self.messageSeparator then self.messageSeparator:Hide() end

  local inset = self.glassyBackgroundTopInset or 0
  local visible = inset < self:GetHeight()
  for index, texture in ipairs(layers) do
    texture:ClearAllPoints()
    texture:SetShown(visible and ((style == "framed" and index <= 2) or (style == "minimal" and index > 2)))
    if index <= 2 then
      texture:SetPoint("TOPLEFT", 0, -inset)
      texture:SetPoint("BOTTOMRIGHT")
    else
      local left = index == 3 or index == 5
      texture:SetPoint(left and "BOTTOMLEFT" or "BOTTOMRIGHT")
      texture:SetWidth(self:GetWidth() / 2)
      if index <= 4 then
        texture:SetPoint(left and "TOPLEFT" or "TOPRIGHT", 0, -inset)
      else
        texture:SetHeight(self:GetPhysicalPixelHeight())
      end
    end
  end
  local color = Core.db.profile.editBoxBackgroundColor
  local opacity = math.max(0, math.min(1, tonumber(color.a) or 0)) * self:GetBackgroundAlpha()
  local r, g, b = channelColor(self)
  layers[1]:SetVertexColor(color.r, color.g, color.b, opacity)
  layers[2]:SetVertexColor(r, g, b, 0.9 * self:GetBackgroundAlpha())
  for index = 3, 6 do
    local red, green, blue, alpha = color.r, color.g, color.b, opacity
    if index > 4 then red, green, blue, alpha = r, g, b, 0.8 * self:GetBackgroundAlpha() end
    layers[index]:SetColorTexture(1, 1, 1, 1)
    local clear = _G.CreateColor(red, green, blue, 0)
    local opaque = _G.CreateColor(red, green, blue, alpha)
    layers[index]:SetGradient("HORIZONTAL", index % 2 == 1 and clear or opaque, index % 2 == 1 and opaque or clear)
  end
end

function EditBoxMixin:CanUseEmotePicker()
  return Core.db.profile.emotePickerEnabled and Core.db.profile.emojisEnabled
    and not (_G.C_ChatInfo and _G.C_ChatInfo.InChatMessagingLockdown and _G.C_ChatInfo.InChatMessagingLockdown())
end

function EditBoxMixin:UpdateEmotePicker()
  local enabled = Core.db.profile.emotePickerEnabled and Core.db.profile.emojisEnabled
  if enabled and not self.glassyEmoteButton then self:CreateEmotePicker() end
  if self.glassyEmoteButton then
    self.glassyEmoteButton:SetShown(enabled)
    if not enabled then self.glassyEmotePanel:Hide() end
  end
  if self.glassyApplyTextInsets then self.glassyApplyTextInsets() end
end

function EditBoxMixin:CreateEmotePicker()
  local picks = Core:GetModule("TextProcessing").EMOTE_PICKS
  local button = _G.CreateFrame("Frame", nil, self)
  button:SetSize(16, 16)
  button:SetPoint("RIGHT", -6, 0)
  button:EnableMouse(false)
  local face = button:CreateTexture(nil, "ARTWORK")
  face:SetAllPoints()
  face:SetTexture(ASSETS.."Emotes\\twemoji_smile")
  self.glassyEmoteButton = button

  local panelName = self:GetName().."GlassyEmotePicker"
  local panel = _G.CreateFrame("Frame", panelName, _G.UIParent)
  self.glassyEmotePanel = panel
  table.insert(_G.UISpecialFrames, panelName)
  panel:SetFrameStrata("DIALOG")
  panel:SetClampedToScreen(true)
  panel:EnableMouse(true)
  panel:SetSize(6 * 26 + 12, math.ceil(#picks / 6) * 26 + 12)
  panel:SetPoint("BOTTOMRIGHT", button, "TOPRIGHT", 6, 8)
  panel:Hide()
  local background = panel:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  setShape(background, "tabBackground")
  background:SetVertexColor(0.04, 0.04, 0.04, 0.95)
  local border = panel:CreateTexture(nil, "BORDER")
  border:SetAllPoints()
  setShape(border, "tabBorder")
  border:SetVertexColor(channelColor(self))
  for index, pick in ipairs(picks) do
    local cell = _G.CreateFrame("Button", nil, panel)
    cell:SetSize(26, 26)
    cell:SetPoint("TOPLEFT", 6 + ((index - 1) % 6) * 26, -6 - math.floor((index - 1) / 6) * 26)
    local icon = cell:CreateTexture(nil, "ARTWORK")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ASSETS.."Emotes\\twemoji_"..pick[1])
    cell:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    cell:SetScript("OnClick", function ()
      panel:Hide()
      _G.GameTooltip:Hide()
      if not self:CanUseEmotePicker() then return end
      local activate = (_G.ChatFrameUtil and _G.ChatFrameUtil.ActivateChat) or _G.ChatEdit_ActivateChat
      if activate then activate(self) else self:Show(); self:SetFocus() end
      self:Insert(pick[2].." ")
    end)
    cell:SetScript("OnEnter", function ()
      _G.GameTooltip:SetOwner(cell, "ANCHOR_TOP")
      _G.GameTooltip:SetText(pick[2])
      _G.GameTooltip:Show()
    end)
    cell:SetScript("OnLeave", function () _G.GameTooltip:Hide() end)
  end
  -- The face passes clicks through to the native edit box so opening it keeps text focus.
  Utils.super(self).HookScript(self, "OnMouseUp", function (_, mouseButton)
    if mouseButton == "LeftButton" and button:IsShown() and button:IsMouseOver() and self:CanUseEmotePicker() then
      local above = Core.db.profile.editBoxAnchor.position == "ABOVE"
      panel:ClearAllPoints()
      panel:SetPoint(above and "TOPRIGHT" or "BOTTOMRIGHT", button, above and "BOTTOMRIGHT" or "TOPRIGHT", 6, above and -8 or 8)
      panel:SetShown(not panel:IsShown())
    end
  end)
  for _, script in ipairs({"OnEnterPressed", "OnEscapePressed"}) do
    Utils.super(self).HookScript(self, script, function () panel:Hide() end)
  end
end

function EditBoxMixin:InitGlassyAppearance()
  self.glassyHooks:SecureHook(self.header, "SetTextColor", function () self:UpdateGlassyStyle() end)
  self:UpdateEmotePicker()
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "emotePickerEnabled" or key == "emojiDisplay" then self:UpdateEmotePicker() end
    if key == "editBoxStyle" then
      self:UpdateGlassyBackground()
      self:UpdateMessageSeparator()
    end
  end)
end
