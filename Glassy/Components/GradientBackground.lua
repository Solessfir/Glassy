local Core = unpack(select(2, ...))

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local GetPhysicalScreenSize = GetPhysicalScreenSize
local Mixin = Mixin
-- luacheck: pop

---@class GlassyGradientBackground: Frame
---@field leftBg Texture
---@field rightBg Texture
---@field centerBg Texture
local GradientBackgroundMixin = {}

local function getPhysicalPixelHeight(region)
  if type(GetPhysicalScreenSize) == "function" then
    local _, physicalHeight = GetPhysicalScreenSize()
    local effectiveScale = region:GetEffectiveScale()
    if physicalHeight and physicalHeight > 0 and effectiveScale and effectiveScale > 0 then
      return 768 / physicalHeight / effectiveScale
    end
  end
  return 1
end

local function clampColorChannel(value, fallback)
  return math.max(0, math.min(1, tonumber(value) or fallback))
end

function GradientBackgroundMixin:Init()
end

function GradientBackgroundMixin:GetPhysicalPixelHeight()
  return getPhysicalPixelHeight(self)
end

function GradientBackgroundMixin:SetGradientBackground(color, opacity, horizontalInset, bottomInset)
  local red = clampColorChannel(color and color.r, 0)
  local green = clampColorChannel(color and color.g, 0)
  local blue = clampColorChannel(color and color.b, 0)
  local alpha = clampColorChannel(opacity, clampColorChannel(color and color.a, 1))
  horizontalInset = horizontalInset or 0
  bottomInset = bottomInset or 0
  local availableWidth = math.max(1, self:GetWidth() + horizontalInset * 2)
  local leftWidth = availableWidth * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeLeftPercent) or 0)) / 100
  local rightWidth = availableWidth * math.max(0, math.min(100, tonumber(Core.db.profile.backgroundFadeRightPercent) or 0)) / 100
  local totalWidth = leftWidth + rightWidth
  if totalWidth > availableWidth then
    local scale = availableWidth / totalWidth
    leftWidth = leftWidth * scale
    rightWidth = rightWidth * scale
  end

  if self.leftBg == nil then
    self.leftBg = self:CreateTexture("", "BACKGROUND")
    self.leftBg:SetColorTexture(1, 1, 1, 1)
  end

  self.leftBg:ClearAllPoints()
  self.leftBg:SetPoint("TOPLEFT", self, "TOPLEFT", -horizontalInset, 0)
  self.leftBg:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -horizontalInset, bottomInset)
  if leftWidth > 0 then
    self.leftBg:SetWidth(leftWidth)
    self.leftBg:SetGradient(
      "HORIZONTAL",
      CreateColor(red, green, blue, 0),
      CreateColor(red, green, blue, alpha)
    )
    self.leftBg:Show()
  else
    self.leftBg:Hide()
  end

  if self.rightBg == nil then
    self.rightBg = self:CreateTexture("", "BACKGROUND")
    self.rightBg:SetColorTexture(1, 1, 1, 1)
  end

  self.rightBg:ClearAllPoints()
  self.rightBg:SetPoint("TOPRIGHT", self, "TOPRIGHT", horizontalInset, 0)
  self.rightBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, bottomInset)
  if rightWidth > 0 then
    self.rightBg:SetWidth(rightWidth)
    self.rightBg:SetGradient(
      "HORIZONTAL",
      CreateColor(red, green, blue, alpha),
      CreateColor(red, green, blue, 0)
    )
    self.rightBg:Show()
  else
    self.rightBg:Hide()
  end

  if self.centerBg == nil then
    self.centerBg = self:CreateTexture("", "BACKGROUND")
  end

  self.centerBg:ClearAllPoints()
  if leftWidth > 0 then
    self.centerBg:SetPoint("TOPLEFT", self.leftBg, "TOPRIGHT")
  else
    self.centerBg:SetPoint("TOPLEFT", self, "TOPLEFT", -horizontalInset, 0)
  end
  if rightWidth > 0 then
    self.centerBg:SetPoint("BOTTOMRIGHT", self.rightBg, "BOTTOMLEFT")
  else
    self.centerBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, bottomInset)
  end
  self.centerBg:SetColorTexture(red, green, blue, alpha)
  if leftWidth + rightWidth >= availableWidth - 0.001 then
    self.centerBg:Hide()
  else
    self.centerBg:Show()
  end
end

function GradientBackgroundMixin:SetSeparatorColor(color, opacityMultiplier)
  local multiplier = clampColorChannel(opacityMultiplier, 1)
  local alpha = clampColorChannel(color and color.a, 0) * multiplier
  self:SetShown(alpha > 0)
  if alpha > 0 then
    self:SetGradientBackground(color, alpha)
  end
end

Core.Components.GradientBackgroundMixin = GradientBackgroundMixin

function Core.Components.CreateSeparatorFrame(parent)
  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, GradientBackgroundMixin)
  GradientBackgroundMixin.Init(object)
  object:SetHeight(getPhysicalPixelHeight(object))
  return object
end
