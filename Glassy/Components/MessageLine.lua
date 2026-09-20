local Core, Constants = unpack(select(2, ...))

local HyperlinkClick = Constants.ACTIONS.HyperlinkClick
local HyperlinkEnter = Constants.ACTIONS.HyperlinkEnter
local HyperlinkLeave = Constants.ACTIONS.HyperlinkLeave

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local Mixin = Mixin
-- luacheck: pop

local MessageLineMixin = {}

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

local function updateTextLayout(self)
  local leftPadding = getLeftTextPadding()
  local textWidth = Core.db.profile.frameWidth - leftPadding - Constants.TEXT_RIGHT_PADDING

  self.text:ClearAllPoints()
  self.text:SetPoint("LEFT", leftPadding, 0)
  self.text:SetWidth(math.max(1, textWidth))
end

local function updateBackground(self)
  local color = Core.db.profile.chatBackgroundColor
  local frameWidth = self:GetWidth()
  local leftFadeWidth = tonumber(Core.db.profile.backgroundFadeLeftWidth) or 0
  local rightFadeWidth = tonumber(Core.db.profile.backgroundFadeRightWidth) or 0
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
  updateTextLayout(self)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  -- Hyperlink handling
  self:SetHyperlinksEnabled(true)

  self:SetScript("OnHyperlinkClick", function (_, link, text, button)
    Core:Dispatch(HyperlinkClick({link, text, button}))
  end)

  self:SetScript("OnHyperlinkEnter", function (_, link, text)
    if Core.db.profile.mouseOverTooltips then
      Core:Dispatch(HyperlinkEnter({link, text}))
    end
  end)

  self:SetScript("OnHyperlinkLeave", function (_, link)
    Core:Dispatch(HyperlinkLeave(link))
  end)

end

---
-- Update height based on text height
function MessageLineMixin:UpdateFrame()
  self:SetWidth(Core.db.profile.frameWidth)
  self:UpdateFadeSettings()
  updateTextLayout(self)
  self.text:SetIndentedWordWrap(Core.db.profile.indentWordWrap)

  local Ypadding = self.text:GetLineHeight() * Core.db.profile.messageLinePadding
  local messageLineHeight = (self.text:GetStringHeight() + Ypadding * 2)
  self:SetHeight(messageLineHeight)

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
