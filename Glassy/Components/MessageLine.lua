local Core, Constants = unpack(select(2, ...))

local HyperlinkClick = Constants.ACTIONS.HyperlinkClick
local HyperlinkEnter = Constants.ACTIONS.HyperlinkEnter
local HyperlinkLeave = Constants.ACTIONS.HyperlinkLeave

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local Mixin = Mixin
local UIParent = UIParent
local canaccessvalue = canaccessvalue
-- luacheck: pop

local MessageLineMixin = {}

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

local function isAccessible(value)
  return not canaccessvalue or canaccessvalue(value)
end

-- Rows chained above secret text inherit secret geometry, so heights are measured on a detached FontString.
local measureText
local function measureTextHeight(text, width)
  if measureText == nil then
    measureText = UIParent:CreateFontString(nil, "BACKGROUND", "GlassyMessageFont")
    measureText:SetPoint("TOPLEFT", UIParent, "TOPLEFT")
    measureText:Hide()
  end
  measureText:SetFontObject("GlassyMessageFont")
  measureText:SetWidth(width)
  measureText:SetIndentedWordWrap(Core.db.profile.indentWordWrap)
  local lineHeight = measureText:GetLineHeight()
  if not isAccessible(text) then
    return nil, lineHeight
  end
  measureText:SetText(text)
  local height = measureText:GetStringHeight()
  measureText:ClearText()
  if not isAccessible(height) then
    return nil, lineHeight
  end
  return height, lineHeight
end

local function updateBackground(self)
  local color = Core.db.profile.chatBackgroundColor
  local frameWidth = Core.db.profile.frameWidth
  local leftFadeWidth = tonumber(Core.db.profile.backgroundFadeLeftPercent) or 0
  local rightFadeWidth = tonumber(Core.db.profile.backgroundFadeRightPercent) or 0
  if (
    self.glassyBackgroundWidth == frameWidth and
    self.glassyBackgroundLeftFadeWidth == leftFadeWidth and
    self.glassyBackgroundRightFadeWidth == rightFadeWidth and
    self.glassyBackgroundRed == color.r and
    self.glassyBackgroundGreen == color.g and
    self.glassyBackgroundBlue == color.b and
    self.glassyBackgroundAlpha == color.a
  ) then
    return
  end

  self:SetGradientBackground(color, color.a)
  self.glassyBackgroundWidth = frameWidth
  self.glassyBackgroundLeftFadeWidth = leftFadeWidth
  self.glassyBackgroundRightFadeWidth = rightFadeWidth
  self.glassyBackgroundRed = color.r
  self.glassyBackgroundGreen = color.g
  self.glassyBackgroundBlue = color.b
  self.glassyBackgroundAlpha = color.a
  self.glassyCoverageOpacity = nil
  self:SetBackgroundCoverage(self.glassyBackgroundCoverage or 0)
end

function MessageLineMixin:SetBackgroundCoverage(coverage)
  self.glassyBackgroundCoverage = coverage
  local color = Core.db.profile.chatBackgroundColor
  -- Preserve existing lines without double-fading backgrounds as hidden lines return.
  local messageAlpha = self:GetAlpha()
  local opacity = 0
  if messageAlpha > coverage then
    opacity = color.a * (messageAlpha - coverage) / (messageAlpha * (1 - color.a * coverage))
  end
  if self.glassyCoverageOpacity == opacity then return end
  self.glassyCoverageOpacity = opacity
  if opacity == 0 then
    self:DisableDrawLayer("BACKGROUND")
    return
  end
  self:EnableDrawLayer("BACKGROUND")
  self.centerBg:SetColorTexture(color.r, color.g, color.b, opacity)
  local transparent = CreateColor(color.r, color.g, color.b, 0)
  local opaque = CreateColor(color.r, color.g, color.b, opacity)
  self.leftBg:SetGradient("HORIZONTAL", transparent, opaque)
  self.rightBg:SetGradient("HORIZONTAL", opaque, transparent)
end

function MessageLineMixin:UpdateFadeSettings()
  local fadeInDuration = Core.db.profile.chatFadeInDuration
  local fadeOutDuration = Core.db.profile.chatFadeOutDuration
  local fadeEasing = Core.db.profile.chatFadeEasing
  if self.glassyFadeInDuration ~= fadeInDuration then
    self:SetFadeInDuration(fadeInDuration)
    self.glassyFadeInDuration = fadeInDuration
  end
  if self.glassyFadeOutDuration ~= fadeOutDuration then
    self:SetFadeOutDuration(fadeOutDuration)
    self.glassyFadeOutDuration = fadeOutDuration
  end
  if self.glassyFadeEasing ~= fadeEasing then
    self:SetFadeEasing(fadeEasing)
    self.glassyFadeEasing = fadeEasing
  end
end

function MessageLineMixin:Init()
  self:SetWidth(Core.db.profile.frameWidth)
  self:UpdateFadeSettings()
  updateBackground(self)

  if self.text == nil then
    self.text = self:CreateFontString(nil, "ARTWORK", "GlassyMessageFont")
  end
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- Hyperlink handling
  self:SetHyperlinksEnabled(true)

  self:SetScript("OnHyperlinkClick", function (_, link, text, button)
    Core:Dispatch(HyperlinkClick({link, text, button}))
  end)

  self:SetScript("OnHyperlinkEnter", function (_, link, text)
    if Core.db.profile.mouseOverTooltips and isAccessible(link) then
      Core:Dispatch(HyperlinkEnter({link, text}))
    end
  end)

  self:SetScript("OnHyperlinkLeave", function (_, link)
    Core:Dispatch(HyperlinkLeave(link))
  end)

end

function MessageLineMixin:SetDisplayText(text)
  -- Match Blizzard's pooled FontString reset so protected text aspects do not leak into later lines.
  self.text:ClearText()
  self.glassyDisplayText = text
  self.glassySecretText = not isAccessible(text)
  self.text:SetText(text)
end

-- Secret text must be cleared while its FontString is re-anchored, then restored.
function MessageLineMixin:WithTextDetached(callback)
  if self.glassySecretText then self.text:ClearText() end
  callback()
  if self.glassySecretText then self.text:SetText(self.glassyDisplayText) end
end

---
-- Chains this row above relativeTo, or to the bottom of its parent when relativeTo is nil.
-- The text is the chain link and the row sizes itself around it, so Lua never reads secret bounds.
function MessageLineMixin:SetChainAnchor(relativeTo, relativePoint)
  self.glassyChainTarget = relativeTo
  self.glassyChainPoint = relativePoint
  self:WithTextDetached(function ()
    self.text:ClearAllPoints()
    self.text:SetPoint(
      "BOTTOMLEFT",
      relativeTo or self:GetParent(),
      relativeTo and relativePoint or "BOTTOMLEFT",
      getLeftTextPadding(),
      self.glassyTextPadding or 0
    )
  end)
end

---
-- Update layout and the numeric height used for scroll accounting
function MessageLineMixin:UpdateFrame()
  local frameWidth = Core.db.profile.frameWidth
  local leftPadding = getLeftTextPadding()
  local textWidth = math.max(1, frameWidth - leftPadding - Constants.TEXT_RIGHT_PADDING)
  self.glassyLayoutWidth = frameWidth
  self:SetWidth(frameWidth)
  self:UpdateFadeSettings()
  self.text:SetWidth(textWidth)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  local textHeight, lineHeight = measureTextHeight(self.glassyDisplayText, textWidth)
  local padding = lineHeight * Core.db.profile.messageLinePadding
  self.glassyTextPadding = padding
  -- Secret rows still size correctly through anchors; only scroll accounting uses this one-line estimate.
  self.glassyHeight = (textHeight or lineHeight) + padding * 2

  self:WithTextDetached(function ()
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", self.text, "TOPLEFT", -leftPadding, padding)
    self:SetPoint("BOTTOMLEFT", self.text, "BOTTOMLEFT", -leftPadding, -padding)
  end)
  self:SetChainAnchor(self.glassyChainTarget, self.glassyChainPoint)

  updateBackground(self)
end

---
-- Update texture color based on setting
function MessageLineMixin:UpdateTextures()
  updateBackground(self)
end

local function CreateMessageLine(parent)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, MessageLineMixin)

  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  MessageLineMixin.Init(object)

  return object
end

local function CreateMessageLinePool(parent)
  return CreateObjectPool(
    function () return CreateMessageLine(parent) end,
    function (_, message)
      -- Reset all animations and timers
      message:QuickHide()
      message.text:ClearText()
      message.glassyDisplayText = nil
      message.glassySecretText = nil
      message.glassyChainTarget = nil
      message.glassyChainPoint = nil
      message.glassyHeight = nil
      message.sourceText = nil
      message.sourceFrame = nil
      message.receivedAt = nil
      message.glassyHideAt = nil
      message.glassyPreview = nil
    end
  )
end

Core.Components.CreateMessageLine = CreateMessageLine
Core.Components.CreateMessageLinePool = CreateMessageLinePool
