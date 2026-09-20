local Core, Constants = unpack(select(2, ...))

local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local EDIT_BOX_VISIBILITY_CHANGED = Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
-- luacheck: pop

local DetachedChatDockMixin = {}
Core.Components.DetachedChatDockMixin = DetachedChatDockMixin

function DetachedChatDockMixin:UpdateFadeSettings()
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
  self:SetFadeEasing(Core.db.profile.chatFadeEasing)
end

function DetachedChatDockMixin:UpdateAutomaticVisibility()
  if Core.db.profile.chatAlwaysVisible or self.typing then
    self:QuickShow()
  else
    self:HideDelay(Core.db.profile.chatHoldTime)
  end
end

function DetachedChatDockMixin:SetTyping(visible)
  self.editBoxVisible = not not visible
  local typing = self.editBoxVisible and Core.db.profile.chatShowWhileTyping or false
  if self.typing == typing then
    return
  end

  self.typing = typing
  if typing then
    self:Show()
  elseif not self.mouseOver then
    self:UpdateAutomaticVisibility()
  end
end

function DetachedChatDockMixin:UpdateStyle()
  local backgroundColor = Core.db.profile.headerBackgroundColor
  self:SetGradientBackground(backgroundColor, backgroundColor.a)
  self.messageSeparator:SetSeparatorColor(Core.db.profile.tabMessageSeparatorColor)
end

function DetachedChatDockMixin:SetTab(tab)
  if tab == nil then
    return
  end
  self.tab = tab
  tab:SetParent(self)
  tab:SetFrameStrata("LOW")
  tab:ClearAllPoints()
  tab:SetPoint("LEFT", self, "LEFT", 0, 0)
  if tab.UpdateVisualState then
    tab:UpdateVisualState()
  end
end

function DetachedChatDockMixin:Init(parent)
  self.editBoxVisible = false
  self.mouseOver = false
  self.typing = false
  self:SetHeight(Constants.DOCK_HEIGHT)
  self:SetPoint("TOPLEFT", parent, "TOPLEFT")
  self:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  self:UpdateFadeSettings()

  self.messageSeparator = CreateSeparatorFrame(self)
  self.messageSeparator:SetPoint("BOTTOMLEFT")
  self.messageSeparator:SetPoint("BOTTOMRIGHT")
  self:UpdateStyle()
  self:SetScript("OnSizeChanged", function () self:UpdateStyle() end)

  self.subscriptions = {
    Core:Subscribe(MOUSE_ENTER, function ()
      self.mouseOver = true
      self:Show()
    end),
    Core:Subscribe(MOUSE_LEAVE, function ()
      self.mouseOver = false
      self:UpdateAutomaticVisibility()
    end),
    Core:Subscribe(EDIT_BOX_VISIBILITY_CHANGED, function (visible)
      self:SetTyping(visible)
    end),
    Core:Subscribe(UPDATE_CONFIG, function (key)
      if key == "headerBackgroundColor" or key == "tabMessageSeparatorColor" or key == "backgroundFade" then
        self:UpdateStyle()
      elseif key == "chatFadeInDuration" or key == "chatFadeOutDuration" or key == "chatFadeEasing" then
        self:UpdateFadeSettings()
      elseif key == "chatAlwaysVisible" and (Core.db.profile.chatAlwaysVisible or not self.mouseOver) then
        self:UpdateAutomaticVisibility()
      elseif key == "chatShowWhileTyping" then
        self:SetTyping(self.editBoxVisible)
      end
    end),
  }

  if Core.db.profile.chatAlwaysVisible then
    self:QuickShow()
  else
    self:QuickHide()
  end
end

Core.Components.CreateDetachedChatDock = function (parent, tab)
  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
  local frame = CreateFrame("Frame", nil, parent)
  local object = Mixin(frame, FadingFrameMixin, GradientBackgroundMixin, DetachedChatDockMixin)
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  object:Init(parent)
  object:SetTab(tab)
  return object
end
