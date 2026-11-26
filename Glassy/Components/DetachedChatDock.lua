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
local C_Timer = C_Timer
-- luacheck: pop

local DetachedChatDockMixin = {}
Core.Components.DetachedChatDockMixin = DetachedChatDockMixin

function DetachedChatDockMixin:UpdatePosition()
  local bottom = Core.db.profile.tabBarPosition == "bottom"
  self:ClearAllPoints()
  self:SetPoint(bottom and "BOTTOMLEFT" or "TOPLEFT", self.glassyParent, bottom and "BOTTOMLEFT" or "TOPLEFT")
  self:SetPoint(bottom and "BOTTOMRIGHT" or "TOPRIGHT", self.glassyParent, bottom and "BOTTOMRIGHT" or "TOPRIGHT")
  self.messageSeparator:ClearAllPoints()
  self.messageSeparator:SetPoint(bottom and "TOPLEFT" or "BOTTOMLEFT")
  self.messageSeparator:SetPoint(bottom and "TOPRIGHT" or "BOTTOMRIGHT")
end

function DetachedChatDockMixin:UpdateSingleTabAlignment()
  if not self.tab then return end
  local alignment = Core.db.profile.tabBarAlignment
  local point = alignment == "right" and "RIGHT" or (alignment == "center" and "CENTER" or "LEFT")
  self.tab:ClearAllPoints()
  self.tab:SetPoint(point, self, point, 0, 0)
end

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
  self.messageSeparator:SetSeparatorColor(Core:GetThemeColor("tabMessageSeparatorColor"))
  if self.scrollButtons then
    local color = Core:GetThemeColor("tabTextColor") or Constants.COLORS.apache
    for _, button in ipairs(self.scrollButtons) do
      button:GetFontString():SetTextColor(color.r, color.g, color.b, color.a or 1)
    end
  end
end

function DetachedChatDockMixin:ClearTabs()
  for _, tab in ipairs(self.tabs or {}) do
    if tab.glassySecondaryDock == self then
      tab.glassySecondaryDock = nil
    end
  end
  self.tabs = nil
  self.selectedTab = nil
  self.selected = nil
end

function DetachedChatDockMixin:ScrollTabs(offset)
  local maximum = math.max(0, self.scrollFrame.child:GetWidth() - self.scrollFrame:GetWidth())
  self.scrollFrame:SetHorizontalScroll(math.max(0, math.min(offset, maximum)))
end

function DetachedChatDockMixin:CreateTabScrollFrame()
  local scrollFrame = CreateFrame("ScrollFrame", nil, self)
  scrollFrame:SetHeight(Constants.DOCK_HEIGHT)
  scrollFrame:SetPoint("LEFT", self, "LEFT")
  local child = CreateFrame("Frame", nil, scrollFrame)
  child:SetHeight(Constants.DOCK_HEIGHT)
  scrollFrame:SetScrollChild(child)
  scrollFrame.child = child
  self.scrollFrame = scrollFrame

  self.scrollButtons = {}
  for index, direction in ipairs({-1, 1}) do
    local button = CreateFrame("Button", nil, self)
    button:SetSize(Constants.DOCK_HEIGHT, Constants.DOCK_HEIGHT)
    button:SetPoint("RIGHT", self, "RIGHT", (index - 2) * Constants.DOCK_HEIGHT, 0)
    button:SetNormalFontObject("GlassyChatDockFont")
    button:SetText(direction == -1 and "<" or ">")
    button:SetScript("OnClick", function ()
      self:ScrollTabs(scrollFrame:GetHorizontalScroll() + direction * math.max(1, scrollFrame:GetWidth() / 2))
    end)
    self.scrollButtons[index] = button
  end
  self:UpdateStyle()
end

function DetachedChatDockMixin:UpdateTabOrder()
  if self.tabs == nil then return end
  local child = self.scrollFrame.child
  local totalWidth, selectedOffset = 0, nil
  for _, tab in ipairs(self.tabs) do
    if tab.glassySecondaryDock == self then
      tab:SetParent(child)
      tab:SetFrameStrata(self:GetFrameStrata())
      tab:ClearAllPoints()
      tab:SetPoint("LEFT", child, "LEFT", totalWidth, 0)
      tab:Show()
      if tab.UpdateVisualState then tab:UpdateVisualState() end
      if tab == self.selectedTab then selectedOffset = totalWidth end
      totalWidth = totalWidth + tab:GetWidth() + 1
    end
  end
  totalWidth = math.max(0, totalWidth - 1)
  local overflow = totalWidth > self:GetWidth()
  local availableWidth = math.max(1, self:GetWidth() - (overflow and 2 * Constants.DOCK_HEIGHT or 0))
  self.scrollFrame:SetWidth(availableWidth)
  child:SetWidth(math.max(1, totalWidth, availableWidth))
  local alignment = Core.db.profile.tabBarAlignment
  local leading = math.max(0, availableWidth - totalWidth)
    * (alignment == "right" and 1 or (alignment == "center" and 0.5 or 0))
  if leading > 0 then
    for _, tab in ipairs(self.tabs) do
      if tab.glassySecondaryDock == self then
        tab:ClearAllPoints()
        tab:SetPoint("LEFT", child, "LEFT", leading, 0)
        leading = leading + tab:GetWidth() + 1
      end
    end
  end
  for _, button in ipairs(self.scrollButtons) do button:SetShown(overflow) end

  local offset = self.scrollFrame:GetHorizontalScroll()
  if selectedOffset then
    if selectedOffset < offset then
      offset = selectedOffset
    elseif selectedOffset + self.selectedTab:GetWidth() > offset + availableWidth then
      offset = selectedOffset + self.selectedTab:GetWidth() - availableWidth
    end
  end
  self:ScrollTabs(offset)
end

function DetachedChatDockMixin:ScheduleTabOrder()
  if self.tabs == nil or self.tabOrderPending then return end
  self.tabOrderPending = true
  C_Timer.After(0, function ()
    self.tabOrderPending = nil
    self:UpdateTabOrder()
  end)
end

function DetachedChatDockMixin:SetTabs(tabs, selectedTab)
  self:ClearTabs()
  self.tab = nil
  if self.scrollFrame == nil then self:CreateTabScrollFrame() end
  self.tabs = {}
  for index, tab in ipairs(tabs) do
    self.tabs[index] = tab
    tab.glassySecondaryDock = self
  end
  self.selectedTab = selectedTab or tabs[1]
  self.selected = self.selectedTab and self.selectedTab.chatFrame or nil
  self.scrollFrame:Show()
  self:UpdateTabOrder()
end

function DetachedChatDockMixin:SetTab(tab)
  self:ClearTabs()
  if self.scrollFrame then
    self.scrollFrame:Hide()
    for _, button in ipairs(self.scrollButtons) do button:Hide() end
  end
  self.tab = tab
  if tab == nil then return end
  tab.glassySecondaryDock = nil
  tab:SetParent(self)
  tab:SetFrameStrata(self:GetFrameStrata())
  tab:ClearAllPoints()
  tab:SetPoint("LEFT", self, "LEFT", 0, 0)
  self:UpdateSingleTabAlignment()
  if tab.UpdateVisualState then
    tab:UpdateVisualState()
  end
end

function DetachedChatDockMixin:Init(parent)
  self.glassyParent = parent
  self.editBoxVisible = false
  self.mouseOver = false
  self.typing = false
  self:SetHeight(Constants.DOCK_HEIGHT)
  self:SetPoint("TOPLEFT", parent, "TOPLEFT")
  self:SetPoint("TOPRIGHT", parent, "TOPRIGHT")
  -- Clipped message lines still catch hyperlink clicks, so the tab must sit above them.
  self:SetFrameLevel(parent:GetFrameLevel() + 20)
  self:UpdateFadeSettings()

  self.messageSeparator = CreateSeparatorFrame(self)
  self.messageSeparator:SetPoint("BOTTOMLEFT")
  self.messageSeparator:SetPoint("BOTTOMRIGHT")
  self:UpdatePosition()
  self:UpdateStyle()
  self:SetScript("OnSizeChanged", function ()
    self:UpdateStyle()
    self:ScheduleTabOrder()
  end)

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
      if key == "tabBarPosition" then self:UpdatePosition() end
      if key == "tabBarAlignment" then
        self:UpdateSingleTabAlignment()
        self:UpdateTabOrder()
      end
      if key == "headerBackgroundColor" or key == "tabMessageSeparatorColor" or key == "backgroundFade" or key == "tabTextColor" then
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
