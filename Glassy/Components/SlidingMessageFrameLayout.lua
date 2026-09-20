local Core, Constants = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")
local UIManager = Core:GetModule("UIManager")

local LibEasing = Core.Libs.LibEasing
local SlidingMessageFrameMixin = Core.Components.SlidingMessageFrameMixin
local Helpers = Core.Components.SlidingMessageFrameHelpers

local getMessageTopInset = Helpers.getMessageTopInset
local getEditBoxEasing = Helpers.getEditBoxEasing
local getMessageFrameHeight = Helpers.getMessageFrameHeight
local DEFAULT_UNREAD_ROW_HEIGHT = 24

function SlidingMessageFrameMixin:UpdateGapBackground()
  local editBox = self.layoutEditBox
  if editBox and editBox.ClipBackgroundToMessages then
    editBox:ClipBackgroundToMessages(self)
  end
  local background = self.gapBackground
  local color = Core.db.profile.chatBackgroundColor
  local window = self.chatFrame and UIManager:GetChatWindow(self.chatFrame)
  local dock = self.detachedContainer and window and window.detachedLayout and window.detachedLayout.dock
    or (not self.detachedContainer and UIManager.dock)
  local filled = dock and dock:IsVisible() and dock:GetAlpha() > 0 and color.a > 0 or false
  local coverage = filled and dock:GetAlpha() or 0
  -- One continuous surface prevents holes as individual messages fade out.
  for _, message in ipairs(self.state.messages) do
    message:SetBackgroundCoverage(coverage)
  end
  background:SetAlpha(filled and dock:GetAlpha() or 0)
  if not filled then return end
  local height = math.min(self.config.height, self:GetHeight())
  if not background.glassyAnchored then
    -- The viewport already includes the configured spacing below the tabs.
    background:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
    background:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
    background.glassyAnchored = true
  end
  if background.glassyHeight ~= height then
    background:SetPoint("BOTTOMLEFT", self, "TOPLEFT", 0, -math.max(1, height))
    background.glassyHeight = height
  end
  if background.glassyColor ~= color or background.glassyWidth ~= self:GetWidth()
    or background.glassyLeftFade ~= Core.db.profile.backgroundFadeLeftPercent
    or background.glassyRightFade ~= Core.db.profile.backgroundFadeRightPercent then
    background:SetGradientBackground(color, color.a)
    background.glassyColor = color
    background.glassyWidth = self:GetWidth()
    background.glassyLeftFade = Core.db.profile.backgroundFadeLeftPercent
    background.glassyRightFade = Core.db.profile.backgroundFadeRightPercent
  end
end

function SlidingMessageFrameMixin:GetLayoutWidth()
  return math.max(
    1,
    tonumber(self.layoutWidth) or tonumber(Core.db.profile.frameWidth) or Core.defaults.profile.frameWidth
  )
end

function SlidingMessageFrameMixin:GetNativeLayoutParent()
  if self.chatFrame and self.chatFrame.isDocked and UIManager.container then
    return UIManager.container
  end
  return self:GetParent()
end

function SlidingMessageFrameMixin:GetNativeLayoutWidth()
  if self.chatFrame and self.chatFrame.isDocked then
    return tonumber(Core.db.profile.frameWidth) or Core.defaults.profile.frameWidth
  end
  return self:GetLayoutWidth()
end

function SlidingMessageFrameMixin:KeepDetachedNativeLayout(method, ...)
  local chatFrame = self.chatFrame
  if chatFrame == nil or chatFrame.isDocked then
    return false
  end
  if Constants.ENV ~= "retail" then
    self.hooks[chatFrame][method](chatFrame, ...)
  end
  return true
end

function SlidingMessageFrameMixin:GetLayoutHeight()
  return math.max(
    1,
    tonumber(self.layoutHeight) or tonumber(Core.db.profile.frameHeight) or Core.defaults.profile.frameHeight
  )
end

function SlidingMessageFrameMixin:GetMessageFrameHeight()
  return getMessageFrameHeight(self.state.isCombatLog, self:GetLayoutHeight(), self.layoutEditBox)
end

function SlidingMessageFrameMixin:SetGlassyShown(shown)
  self:SetShown(shown)
  if self.detachedContainer then
    self.detachedContainer:SetShown(shown)
  end
end

function SlidingMessageFrameMixin:UpdateViewportHeight(unreadRowHeight)
  if self.state.scrollAtBottom then
    self:SetHeight(self.config.height + self.config.overflowHeight)
  else
    local reservedHeight = unreadRowHeight
    if reservedHeight == nil and self.overlay and self.overlay.GetUnreadRowHeight then
      reservedHeight = self.overlay:GetUnreadRowHeight()
    end
    reservedHeight = math.max(0, tonumber(reservedHeight) or DEFAULT_UNREAD_ROW_HEIGHT)
    self:SetHeight(math.max(1, self.config.height - reservedHeight))
  end

  if self.slider then
    self:UpdateScrollChildRect()
  end
end

function SlidingMessageFrameMixin:ApplyDynamicEditBoxHeight(nextHeight)
  local previousHeight = self.config.height
  if previousHeight == nextHeight then
    self.overlay:UpdateFrame()
    return
  end

  local heightDifference = nextHeight - previousHeight
  local previousScroll = self:GetVerticalScroll()
  self.config.height = nextHeight
  self:UpdateViewportHeight()

  local minimumSliderHeight = nextHeight + self.config.overflowHeight
  self.slider:SetHeight(math.max(minimumSliderHeight, self.slider:GetHeight() + heightDifference))
  self:UpdateScrollChildRect()
  self:SetVerticalScroll(previousScroll)
  self.overlay:UpdateFrame()
end

function SlidingMessageFrameMixin:AlignDynamicEditBoxScroll()
  if self.state.scrollAtBottom then
    self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
  else
    self:SetVerticalScroll(math.min(self:GetVerticalScroll(), self:GetVerticalScrollRange()))
  end
end

function SlidingMessageFrameMixin:ApplyPendingDynamicEditBoxLayout()
  local nextHeight = self.state.pendingEditBoxHeight
  if nextHeight == nil then
    return
  end

  self.state.pendingEditBoxHeight = nil
  self:ApplyDynamicEditBoxHeight(nextHeight)
  self:AlignDynamicEditBoxScroll()
end

function SlidingMessageFrameMixin:CancelDynamicEditBoxLayout(applyTarget)
  if self.state.editBoxEasingHandle then
    LibEasing:StopEasing(self.state.editBoxEasingHandle)
    self.state.editBoxEasingHandle = nil
  end

  local targetHeight = self.state.editBoxTargetHeight
  self.state.editBoxTargetHeight = nil
  if applyTarget and targetHeight then
    self:ApplyDynamicEditBoxHeight(targetHeight)
    self:AlignDynamicEditBoxScroll()
  end
end

function SlidingMessageFrameMixin:UpdateDynamicEditBoxLayout()
  local nextHeight = self:GetMessageFrameHeight()
  self:CancelDynamicEditBoxLayout(false)

  -- Only the selected chat frame needs to resize immediately. Updating every
  -- hidden tab here makes SendText synchronously recalculate all of their
  -- scroll children and anchors, which can exceed Classic's script time limit.
  if not self:IsShown() then
    self.state.pendingEditBoxHeight = self.config.height ~= nextHeight and nextHeight or nil
    return
  end

  self.state.pendingEditBoxHeight = nil
  if self.config.height == nextHeight then
    self:AlignDynamicEditBoxScroll()
    self.overlay:UpdateFrame()
    return
  end

  if self.state.prevEasingHandle then
    LibEasing:StopEasing(self.state.prevEasingHandle)
    self.state.prevEasingHandle = nil
  end

  self.state.editBoxTargetHeight = nextHeight
  self.state.editBoxEasingHandle = LibEasing:Ease(
    function (height)
      self:ApplyDynamicEditBoxHeight(height)
    end,
    self.config.height,
    nextHeight,
    math.max(0, tonumber(Core.db.profile[nextHeight < self.config.height and "chatFadeInDuration" or "chatFadeOutDuration"])
      or Constants.EDIT_BOX_TRANSITION_DURATION),
    getEditBoxEasing(),
    function ()
      self.state.editBoxEasingHandle = nil
      self.state.editBoxTargetHeight = nil
      self:AlignDynamicEditBoxScroll()
    end
  )
end


function SlidingMessageFrameMixin:RefreshLayout(reprocessText)
  if self.state == nil or self.slider == nil then
    return
  end

  self:CancelDynamicEditBoxLayout(false)
  self.config.height = self:GetMessageFrameHeight()
  self.config.width = self:GetLayoutWidth()

  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", 0, -getMessageTopInset(self.state.isCombatLog))
  self:SetHeight(self.config.height + self.config.overflowHeight)
  self:SetWidth(self.config.width)

  local contentHeight = 0
  for _, message in ipairs(self.state.messages) do
    if reprocessText and message.sourceText then
      local processedText = TP:ProcessText(message.sourceText, message.sourceFrame, message.receivedAt)
      message.text:SetText(processedText)
    end
    message:UpdateFrame()
    contentHeight = contentHeight + message:GetHeight()
  end

  self.slider:SetHeight(self.config.height + self.config.overflowHeight + contentHeight)
  self.slider:SetWidth(self.config.width)

  self.state.scrollAtBottom = true
  self.state.unreadMessages = false
  self:UpdateScrollChildRect()
  self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
  self.overlay:UpdateFrame()
  self.overlay:Hide()
  self.overlay:HideNewMessageAlert()
end

function SlidingMessageFrameMixin:SetLayout(parent, width, height, editBox, detachedContainer)
  local previousDetachedContainer = self.detachedContainer
  self.layoutWidth = width
  self.layoutHeight = height
  self.layoutEditBox = editBox
  self.detachedContainer = detachedContainer

  self:SetParent(parent)
  if self.gapBackground then
    self.gapBackground:SetParent(parent)
    self.gapBackground:SetFrameStrata(self:GetFrameStrata())
    self.gapBackground:SetFrameLevel(math.max(0, self:GetFrameLevel() - 1))
  end
  self:RefreshLayout(false)

  if Constants.ENV ~= "retail" and not self.state.isCombatLog then
    if detachedContainer and self:IsShown() then
      self.hooks[self.chatFrame].Show(self.chatFrame)
    else
      self.hooks[self.chatFrame].Hide(self.chatFrame)
    end
  end

  if previousDetachedContainer and previousDetachedContainer ~= detachedContainer then
    previousDetachedContainer:Hide()
  end
  if detachedContainer then
    detachedContainer:SetShown(self:IsShown())
  end
end
