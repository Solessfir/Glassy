local Core, _, Utils = unpack(select(2, ...))

local super = Utils.super
local LibEasing = Core.Libs.LibEasing

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local FadingFrameMixin = {}

local function setClampedAlpha(self, alpha)
  self:SetAlpha(math.max(0, math.min(1, alpha)))
end

local function cancelHideTimer(self)
  if self.hideTimer ~= nil then
    self.hideTimer:Cancel()
    self.hideTimer = nil
  end
end

local function stopFade(self)
  if self.fadeHandle ~= nil then
    LibEasing:StopEasing(self.fadeHandle)
    self.fadeHandle = nil
  end
end

function FadingFrameMixin:Init()
  self.fadeInDuration = self.fadeInDuration or 0
  self.fadeOutDuration = self.fadeOutDuration or 0
  self.fadeInEasing = self.fadeInEasing or LibEasing.OutCubic
  self.fadeOutEasing = self.fadeOutEasing or LibEasing.Linear
end

function FadingFrameMixin:QuickShow()
  self:StopAnimating()
  stopFade(self)
  cancelHideTimer(self)
  self:SetAlpha(1)
  super(self).Show(self)
end

function FadingFrameMixin:QuickHide()
  self:StopAnimating()
  stopFade(self)
  cancelHideTimer(self)
  self:SetAlpha(1)
  super(self).Hide(self)
end

function FadingFrameMixin:Show()
  self:StopAnimating()
  stopFade(self)
  cancelHideTimer(self)

  local wasVisible = self:IsVisible()
  local startAlpha = wasVisible and self:GetAlpha() or 0
  if not wasVisible then
    super(self).Show(self)
  end

  local duration = self.fadeInDuration * math.max(0, 1 - startAlpha)
  if duration > 0 and startAlpha < 1 then
    self:SetAlpha(startAlpha)
    self.fadeHandle = LibEasing:Ease(
      function (alpha) setClampedAlpha(self, alpha) end,
      startAlpha,
      1,
      duration,
      self.fadeInEasing,
      function () self.fadeHandle = nil end
    )
  else
    self:SetAlpha(1)
  end
end

function FadingFrameMixin:Hide()
  cancelHideTimer(self)

  if self:IsVisible() then
    self:StopAnimating()
    stopFade(self)
    local startAlpha = self:GetAlpha()
    local duration = self.fadeOutDuration * math.max(0, startAlpha)
    if duration > 0 and startAlpha > 0 then
      self.fadeHandle = LibEasing:Ease(
        function (alpha) setClampedAlpha(self, alpha) end,
        startAlpha,
        0,
        duration,
        self.fadeOutEasing,
        function ()
          self.fadeHandle = nil
          self:QuickHide()
        end
      )
    else
      self:QuickHide()
    end
  end
end

function FadingFrameMixin:HideDelay(delay)
  delay = delay or 0

  if self:IsVisible() then
    cancelHideTimer(self)
    self.hideTimer = C_Timer.NewTimer(delay, function ()
      self.hideTimer = nil
      self:Hide()
    end)
  end
end

function FadingFrameMixin:SetFadeInDuration(duration)
  self.fadeInDuration = math.max(0, tonumber(duration) or 0)
end

function FadingFrameMixin:SetFadeOutDuration(duration)
  self.fadeOutDuration = math.max(0, tonumber(duration) or 0)
end

function FadingFrameMixin:SetFadeEasing(easingName)
  local easing = LibEasing[easingName]
  if type(easing) ~= "function" then
    easing = LibEasing.Linear
  end
  self.fadeInEasing = easing
  self.fadeOutEasing = easing
end

local function CreateFadingFrame(frameType, name, parent)
  local frame = CreateFrame(frameType, name, parent)
  local object = Mixin(frame, FadingFrameMixin)
  object:Init()
  return object
end

Core.Components.CreateFadingFrame = CreateFadingFrame
Core.Components.FadingFrameMixin = FadingFrameMixin
