local Core, Constants = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook
local LibEasing = Core.Libs.LibEasing

local EditBoxLayoutChanged = Constants.ACTIONS.EditBoxLayoutChanged
local EditBoxVisibilityChanged = Constants.ACTIONS.EditBoxVisibilityChanged

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
local Mixin = Mixin
-- luacheck: pop

local EditBoxMixin = {}
Core.Components.EditBoxMixin = EditBoxMixin


local function getVerticalPadding()
  return math.max(
    0,
    tonumber(Core.db.profile.editBoxVerticalPadding) or Core.defaults.profile.editBoxVerticalPadding
  )
end

local function getBackgroundEasing()
  local easing = LibEasing[Core.db.profile.editBoxBackgroundEasing]
  return type(easing) == "function" and easing or LibEasing.OutCubic
end

local function hasVisibleBackground()
  local backgroundColor = Core.db.profile.editBoxBackgroundColor
  local separatorColor = Core.db.profile.editBoxMessageSeparatorColor
  return
    (backgroundColor and (tonumber(backgroundColor.a) or 0) > 0) or
    (separatorColor and (tonumber(separatorColor.a) or 0) > 0)
end

Core.Components.EditBoxHelpers = {
  getVerticalPadding = getVerticalPadding,
  hasVisibleBackground = hasVisibleBackground,
}
function EditBoxMixin:SetBackgroundAlpha(alpha)
  self.glassyBackgroundAlpha = math.max(0, math.min(1, alpha))
  if self.header then self.header:SetAlpha(self.glassyBackgroundAlpha) end
  if self.headerSuffix then self.headerSuffix:SetAlpha(self.glassyBackgroundAlpha) end
  self:UpdateGlassyBackground()
end

function EditBoxMixin:GetBackgroundAlpha()
  return self.glassyBackgroundAlpha or 1
end

function EditBoxMixin:UpdateGlassyBackground()
  local color = Core.db.profile.editBoxBackgroundColor
  local configuredOpacity = math.max(0, math.min(1, tonumber(color and color.a) or 0))
  self:SetGradientBackground(color, configuredOpacity * self:GetBackgroundAlpha())

  if self.messageSeparator then
    self.messageSeparator:SetSeparatorColor(
      Core.db.profile.editBoxMessageSeparatorColor,
      self:GetBackgroundAlpha()
    )
  end

  if configuredOpacity == 0 then
    self.leftBg:Hide()
    self.centerBg:Hide()
    self.rightBg:Hide()
    return
  end

  -- Texture alpha is kept at full strength because the transition is applied directly to the gradient's vertex colors.
  self.leftBg:SetAlpha(1)
  self.centerBg:Show()
  self.centerBg:SetAlpha(1)
  self.rightBg:SetAlpha(1)

  local inset = self.glassyBackgroundTopInset or 0
  if inset > 0 then
    self.leftBg:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -inset)
    self.rightBg:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, -inset)
    if not self.leftBg:IsShown() then
      self.centerBg:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -inset)
    end
    if inset >= self:GetHeight() then
      self.leftBg:Hide()
      self.centerBg:Hide()
      self.rightBg:Hide()
    end
    if self.messageSeparator then self.messageSeparator:Hide() end
  end
end

function EditBoxMixin:ClipBackgroundToMessages(messageFrame)
  local inset = 0
  if self:IsVisible() and Core.db.profile.editBoxAnchor.position == "BELOW"
    and Core.db.profile.chatBackgroundColor.a > 0 then
    local top, messageTop = self:GetTop(), messageFrame:GetTop()
    if top and messageTop then
      local bottom = messageTop - math.min(messageFrame.config.height, messageFrame:GetHeight())
      bottom = bottom * messageFrame:GetEffectiveScale() / self:GetEffectiveScale()
      inset = math.max(0, math.min(self:GetHeight(), top - bottom))
    end
  end
  if self.glassyBackgroundTopInset ~= inset then
    self.glassyBackgroundTopInset = inset
    self:UpdateGlassyBackground()
  end
end

function EditBoxMixin:UpdateMessageSeparator()
  self.messageSeparator:ClearAllPoints()
  if Core.db.profile.editBoxAnchor.position == "ABOVE" then
    self.messageSeparator:SetPoint("BOTTOMLEFT")
    self.messageSeparator:SetPoint("BOTTOMRIGHT")
  else
    self.messageSeparator:SetPoint("TOPLEFT")
    self.messageSeparator:SetPoint("TOPRIGHT")
  end

  self.messageSeparator:SetSeparatorColor(
    Core.db.profile.editBoxMessageSeparatorColor,
    self:GetBackgroundAlpha()
  )
end

function EditBoxMixin:StopBackgroundAlphaTransition()
  if self.editBoxBackgroundAlphaHandle then
    LibEasing:StopEasing(self.editBoxBackgroundAlphaHandle)
    self.editBoxBackgroundAlphaHandle = nil
  end
  self.editBoxBackgroundAlphaTarget = nil
end

function EditBoxMixin:AnimateBackgroundAlpha(targetAlpha, onFinished)
  self:StopBackgroundAlphaTransition()
  self.editBoxBackgroundAlphaTarget = targetAlpha

  local startAlpha = self:GetBackgroundAlpha()
  if not hasVisibleBackground() or startAlpha == targetAlpha then
    self:SetBackgroundAlpha(targetAlpha == 0 and 1 or targetAlpha)
    self.editBoxBackgroundAlphaTarget = nil
    if onFinished then
      onFinished()
    end
    return
  end

  self.editBoxBackgroundAlphaHandle = LibEasing:Ease(
    function (alpha)
      self:SetBackgroundAlpha(alpha)
    end,
    startAlpha,
    targetAlpha,
    math.max(0, tonumber(Core.db.profile[targetAlpha == 1 and "chatFadeInDuration" or "chatFadeOutDuration"])
      or Constants.EDIT_BOX_TRANSITION_DURATION) * math.abs(targetAlpha - startAlpha),
    getBackgroundEasing(),
    function ()
      self.editBoxBackgroundAlphaHandle = nil
      self.editBoxBackgroundAlphaTarget = nil
      if onFinished then
        onFinished()
      end
    end
  )
end

function EditBoxMixin:ShowEntry(continueTransition)
  if self.glassyEntryVisible and self.editBoxBackgroundAlphaTarget ~= 0 then
    return
  end

  self.glassyEntryVisible = true
  Core:Dispatch(EditBoxVisibilityChanged(true))
  if self.glassyInitialized then
    if not continueTransition then
      self:StopBackgroundAlphaTransition()
      self:SetBackgroundAlpha(0)
    end
    self:AnimateBackgroundAlpha(1)
  else
    self.glassyInitialized = true
    self:StopBackgroundAlphaTransition()
    self:SetBackgroundAlpha(1)
  end
  self:UpdateDynamicMessageArea()
end

function EditBoxMixin:GetReusableMessageHeight()
  if (
    Core.db.profile.editBoxAnchor.position ~= "BELOW" or
    self.glassyEntryVisible
  ) then
    return 0
  end

  local yOffset = tonumber(Core.db.profile.editBoxAnchor.yOfs) or 0
  return math.max(0, self:GetHeight() - yOffset)
end

function EditBoxMixin:UpdateDynamicMessageArea()
  if self.dynamicMessageAreaUpdatePending then
    return
  end

  -- Blizzard hides the edit box synchronously from SendText/ClearChat. Defer
  -- the visual layout work so it does not inherit that already-busy script's
  -- execution budget, and coalesce duplicate Show/Hide updates in one frame.
  self.dynamicMessageAreaUpdatePending = true
  C_Timer.After(0, function ()
    self.dynamicMessageAreaUpdatePending = nil

    local reusableHeight = self:GetReusableMessageHeight()
    self.dynamicMessageArea:SetWidth(self:GetLayoutWidth())
    self.dynamicMessageArea:SetHeight(math.max(1, reusableHeight))
    self.dynamicMessageArea:SetShown(reusableHeight > 0)
    Core:Dispatch(EditBoxLayoutChanged())
  end)
end

function EditBoxMixin:GetLayoutWidth()
  if self.glassyUseParentWidth and self.glassyParent then
    return math.max(1, tonumber(self.glassyParent:GetWidth()) or 1)
  end
  return math.max(1, tonumber(Core.db.profile.frameWidth) or Core.defaults.profile.frameWidth)
end

function EditBoxMixin:UpdateAnchor()
  self:ClearAllPoints()
  if Core.db.profile.editBoxAnchor.position == "ABOVE" then
    self:SetPoint("BOTTOMLEFT", self.glassyParent, "TOPLEFT", 0, Core.db.profile.editBoxAnchor.yOfs)
  else
    self:SetPoint("TOPLEFT", self.glassyParent, "BOTTOMLEFT", 0, Core.db.profile.editBoxAnchor.yOfs)
  end
end

function EditBoxMixin:SetGlassyParent(parent, useParentWidth)
  self.glassyParent = parent
  self.glassyUseParentWidth = useParentWidth == true
  self:SetParent(parent)
  self:UpdateAnchor()
  self:SetWidth(self:GetLayoutWidth())

  if self.dynamicMessageArea then
    self.dynamicMessageArea:SetParent(parent)
    self.dynamicMessageArea:ClearAllPoints()
    self.dynamicMessageArea:SetPoint("TOPLEFT", parent, "BOTTOMLEFT")
    self:UpdateDynamicMessageArea()
  end
  self:UpdateGlassyBackground()
  self:UpdateMessageSeparator()
end

Core.Components.CreateEditBox = function (parent, editBox, useParentWidth)
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
  local object = Mixin(editBox or _G.ChatFrame1EditBox, GradientBackgroundMixin, EditBoxMixin)
  if object.glassyMixinInitialized then
    object:SetGlassyParent(parent, useParentWidth)
    return object
  end

  object.glassyMixinInitialized = true
  -- Keep AceHook methods off Blizzard's edit box so other addons can use its native HookScript.
  object.glassyHooks = AceHook:Embed({})
  -- Glassy hides the native chat frame; its input must inherit visibility from Glassy instead.
  object:SetParent(parent)
  GradientBackgroundMixin.Init(object)
  object:Init(parent, useParentWidth)
  return object
end
