local Core = unpack(select(2, ...))

local GradientBackgroundMixin = {}

local function clampColorChannel(value, fallback)
  return math.max(0, math.min(1, tonumber(value) or fallback))
end

function GradientBackgroundMixin:Init()
end

function GradientBackgroundMixin:SetGradientBackground(color, opacity, horizontalInset)
  local red = clampColorChannel(color and color.r, 0)
  local green = clampColorChannel(color and color.g, 0)
  local blue = clampColorChannel(color and color.b, 0)
  local alpha = clampColorChannel(opacity, clampColorChannel(color and color.a, 1))
  horizontalInset = horizontalInset or 0
  local availableWidth = math.max(1, self:GetWidth() + horizontalInset * 2)
  local leftWidth = math.max(0, tonumber(Core.db.profile.backgroundFadeLeftWidth) or 0)
  local rightWidth = math.max(0, tonumber(Core.db.profile.backgroundFadeRightWidth) or 0)
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
  self.leftBg:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT", -horizontalInset, 0)
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
  self.rightBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, 0)
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
    self.centerBg:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", horizontalInset, 0)
  end
  self.centerBg:SetColorTexture(red, green, blue, alpha)
end

Core.Components.GradientBackgroundMixin = GradientBackgroundMixin
