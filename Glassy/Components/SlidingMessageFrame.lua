local Core, Constants, Utils = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")
local UIManager = Core:GetModule("UIManager")

local AceHook = Core.Libs.AceHook

local LibEasing = Core.Libs.LibEasing
local CreateMessageLinePool = Core.Components.CreateMessageLinePool
local CreateScrollOverlayFrame = Core.Components.CreateScrollOverlayFrame

local EDIT_BOX_LAYOUT_CHANGED = Constants.EVENTS.EDIT_BOX_LAYOUT_CHANGED
local EDIT_BOX_VISIBILITY_CHANGED = Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED
local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local CreateObjectPool = CreateObjectPool
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local GetServerTime = GetServerTime
local GetTime = GetTime
local Mixin = Mixin
-- luacheck: pop

----
-- SlidingMessageFrameMixin
--
-- Custom frame for displaying pretty sliding messages
local SlidingMessageFrameMixin = {}

local RENDERED_MESSAGE_LIMIT = 128

local function getMessageTopInset(isCombatLog)
  local inset = Constants.DOCK_HEIGHT + 5
  if isCombatLog and Core.db.profile.combatLogBarPosition == "BELOW" then
    inset = inset + Constants.COMBAT_LOG_BAR_HEIGHT
  end
  return inset
end

local function getScrollbackLimit()
  local limit = tonumber(Core.db.profile.scrollbackLines) or Core.defaults.profile.scrollbackLines
  return math.max(1, math.floor(limit))
end

local function getRenderedMessageLimit()
  return math.min(getScrollbackLimit(), RENDERED_MESSAGE_LIMIT)
end

local function getSlideEasing()
  local easing = LibEasing[Core.db.profile.chatSlideInEasing]
  return type(easing) == "function" and easing or LibEasing.OutCubic
end

local function getEditBoxEasing()
  local easing = LibEasing[Core.db.profile.editBoxEasing]
  return type(easing) == "function" and easing or LibEasing.OutCubic
end

local function getReceivedAt(entry)
  if entry and tonumber(entry.serverTime) then
    return tonumber(entry.serverTime)
  end

  if entry and tonumber(entry.timestamp) then
    return GetServerTime() - math.max(0, GetTime() - tonumber(entry.timestamp))
  end

  return GetServerTime()
end

local function getHistoryEntry(chatFrame, messageIndex)
  local historyBuffer = chatFrame and chatFrame.historyBuffer
  if historyBuffer == nil then
    return nil
  end

  local entryIndex = chatFrame:GetNumMessages() - messageIndex + 1
  return historyBuffer:GetEntryAtIndex(entryIndex)
end

local function isCombatLogHidden()
  return Core.db.profile.combatLogHidden
end

-- Blizzard disables filtered combat events when ChatFrame2 hides. Keep only its native event stream active so history remains available without Glassy rendering it.
local function keepCombatLogTracking()
  if Constants.ENV ~= "retail" and _G.C_CombatLog and type(_G.C_CombatLog.SetFilteredEventsEnabled) == "function" then
    _G.C_CombatLog.SetFilteredEventsEnabled(true)
  end
end

local function getMessageFrameHeight(isCombatLog)
  local frameHeight = tonumber(Core.db.profile.frameHeight) or Core.defaults.profile.frameHeight
  local editBox = _G.ChatFrame1EditBox
  local reusableHeight = 0
  if Core.db.profile.dynamicEditBox and Core.db.profile.editBoxAnchor.position == "BELOW" and editBox then
    if type(editBox.GetReusableMessageHeight) == "function" then
      reusableHeight = editBox:GetReusableMessageHeight()
    else
      local editBoxShown = editBox:IsShown()
      if not editBoxShown then
        local yOffset = tonumber(Core.db.profile.editBoxAnchor.yOfs) or 0
        reusableHeight = math.max(0, editBox:GetHeight() - yOffset)
      end
    end
  end
  return math.max(1, frameHeight - getMessageTopInset(isCombatLog) + reusableHeight)
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
  if self.state.scrollAtBottom then
    self:SetHeight(nextHeight + self.config.overflowHeight)
  else
    self:SetHeight(nextHeight)
  end

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
  local nextHeight = getMessageFrameHeight(self.state.isCombatLog)
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
    Constants.EDIT_BOX_TRANSITION_DURATION,
    getEditBoxEasing(),
    function ()
      self.state.editBoxEasingHandle = nil
      self.state.editBoxTargetHeight = nil
      self:AlignDynamicEditBoxScroll()
    end
  )
end

function SlidingMessageFrameMixin:CancelMessageHideTimer(clearDeadlines)
  if self.messageHideTimer then
    self.messageHideTimer:Cancel()
    self.messageHideTimer = nil
  end

  if clearDeadlines and self.state then
    for _, message in ipairs(self.state.messages) do
      message.glassyHideAt = nil
    end
  end
end

function SlidingMessageFrameMixin:ScheduleMessageHideCheck()
  self:CancelMessageHideTimer(false)

  local nextHideAt
  for _, message in ipairs(self.state.messages) do
    if message.glassyHideAt and (nextHideAt == nil or message.glassyHideAt < nextHideAt) then
      nextHideAt = message.glassyHideAt
    end
  end

  if nextHideAt == nil then
    return
  end

  self.messageHideTimer = C_Timer.NewTimer(math.max(0, nextHideAt - GetTime()), function ()
    self.messageHideTimer = nil
    local now = GetTime()
    for _, message in ipairs(self.state.messages) do
      if message.glassyHideAt and message.glassyHideAt <= now then
        message.glassyHideAt = nil
        message:Hide()
      end
    end
    self:ScheduleMessageHideCheck()
  end)
end

function SlidingMessageFrameMixin:ScheduleMessageHides(messages)
  local now = GetTime()
  local regularHideAt = now + math.max(0, tonumber(Core.db.profile.chatHoldTime) or 0)
  for _, message in ipairs(messages) do
    if message:IsVisible() then
      if message.glassyPreview then
        local animationDuration = math.max(
          tonumber(Core.db.profile.chatFadeInDuration) or 0,
          tonumber(Core.db.profile.chatSlideInDuration) or 0
        )
        message.glassyHideAt = now + animationDuration + 0.75
      else
        message.glassyHideAt = regularHideAt
      end
    end
  end
  self:ScheduleMessageHideCheck()
end

function SlidingMessageFrameMixin:ScheduleVisibleMessageHides()
  self:CancelMessageHideTimer(true)
  self:ScheduleMessageHides(self.state.messages)
end

function SlidingMessageFrameMixin:SetTyping(visible)
  local typing = not not (visible and Core.db.profile.chatShowWhileTyping)
  if self.state.typing == typing then
    return
  end

  self.state.typing = typing
  if typing then
    self:CancelMessageHideTimer(true)
    for _, message in ipairs(self.state.messages) do
      message:Show()
    end
  elseif not self.state.mouseOver then
    self:ScheduleVisibleMessageHides()
  end
end

function SlidingMessageFrameMixin:SyncNativeChatVisibility()
  local shown = self.chatFrame:IsShown() and not (self.state.isCombatLog and isCombatLogHidden())
  if shown then
    self:ApplyPendingDynamicEditBoxLayout()
  end
  self:SetShown(shown)
end

function SlidingMessageFrameMixin:HookChatFrameVisibility(chatFrame)
  if Constants.ENV == "retail" then
    -- Retail's native OnShow applies protected combat filters; never wrap or invoke it from addon code.
    self:SecureHookScript(chatFrame, "OnShow", function () self:SyncNativeChatVisibility() end)
    self:SecureHookScript(chatFrame, "OnHide", function () self:SyncNativeChatVisibility() end)
    self:SyncNativeChatVisibility()
    return
  end

  -- Hide the default chat frame and show the sliding message frame instead.
  self:RawHook(chatFrame, "Show", function (frame)
    if self.state.isCombatLog then
      if isCombatLogHidden() then
        self.hooks[chatFrame].Hide(frame)
        keepCombatLogTracking()
        self:Hide()
        return
      end
      self.hooks[chatFrame].Show(frame)
    end
    self:ApplyPendingDynamicEditBoxLayout()
    self:Show()
  end, true)

  -- FCF_CheckShowChatFrame uses SetShown when switching or creating tabs.
  self:RawHook(chatFrame, "SetShown", function (_, shown)
    if self.state.isCombatLog and isCombatLogHidden() then
      self.hooks[chatFrame].SetShown(chatFrame, false)
      keepCombatLogTracking()
      self:Hide()
      return
    end
    self.hooks[chatFrame].SetShown(chatFrame, self.state.isCombatLog and shown or false)
    if shown then
      self:ApplyPendingDynamicEditBoxLayout()
    end
    self:SetShown(shown)
  end, true)

  self:RawHook(chatFrame, "Hide", function (frame)
    self.hooks[chatFrame].Hide(frame)
    if self.state.isCombatLog and isCombatLogHidden() then
      keepCombatLogTracking()
    end
    self:Hide()
  end, true)
end

function SlidingMessageFrameMixin:Init(chatFrame)
  local isCombatLog = chatFrame == _G.ChatFrame2
  local chatFrameWasShown = chatFrame:IsShown()
  self.config = {
    height = getMessageFrameHeight(isCombatLog),
    width = Core.db.profile.frameWidth,
    overflowHeight = 60,
  }
  self.state = {
    mouseOver = false,
    typing = false,
    showingTooltip = false,
    prevEasingHandle = nil,
    editBoxEasingHandle = nil,
    editBoxTargetHeight = nil,
    pendingEditBoxHeight = nil,
    incomingScrollbackMessages = {},
    incomingMessages = {},
    messages = {},
    head = nil,
    tail = nil,
    isCombatLog = isCombatLog,
    scrollAtBottom = true,
    unreadMessages = false,
  }
  self.chatFrame = chatFrame
  self.historyBuffer = chatFrame.historyBuffer

  Utils.hookPresentation(self, chatFrame, "SetMaxLines", function (frame)
    self.hooks[chatFrame].SetMaxLines(frame, getScrollbackLimit())
  end, true)
  chatFrame:SetMaxLines(getScrollbackLimit())

  -- This subscription follows pooled frames because it reads self.chatFrame when the event is dispatched.
  if self.scrollbackSubscription == nil then
    self.scrollbackSubscription = Core:Subscribe(UPDATE_CONFIG, function (key)
      if key ~= "scrollbackLines" or self.chatFrame == nil then
        return
      end

      self.chatFrame:SetMaxLines(getScrollbackLimit())

      local removedHeight = self:ReleaseOverflowMessages()
      if removedHeight > 0 then
        local minimumHeight = self.config.height + self.config.overflowHeight
        local scrollOffset = math.max(0, self:GetVerticalScroll() - removedHeight)
        self.slider:SetHeight(math.max(minimumHeight, self.slider:GetHeight() - removedHeight))
        self:UpdateScrollChildRect()

        if self.state.scrollAtBottom then
          self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
        else
          self:SetVerticalScroll(scrollOffset)
        end
      end
    end)
  end

  -- Override Blizzard UI
  _G[chatFrame:GetName().."ButtonFrame"]:Hide()

  chatFrame:SetClampRectInsets(0,0,0,0)
  chatFrame:SetClampedToScreen(false)
  chatFrame:SetResizable(false)
  if Constants.ENV ~= "retail" then
    chatFrame:SetParent(self:GetParent())
  end
  chatFrame:ClearAllPoints()

  if self.state.isCombatLog then
    local function applyCombatLogLayout()
      if Constants.ENV == "retail" then chatFrame:ClearAllPoints() end
      self.hooks[chatFrame].SetPoint(
        chatFrame,
        "TOPLEFT",
        self:GetParent(),
        "TOPLEFT",
        0,
        -getMessageTopInset(true)
      )
      self.hooks[chatFrame].SetPoint(
        chatFrame,
        "BOTTOMLEFT",
        self:GetParent(),
        "BOTTOMLEFT",
        0,
        0
      )
      self.hooks[chatFrame].SetWidth(chatFrame, Core.db.profile.frameWidth)
    end

    Utils.hookPresentation(self, chatFrame, "SetWidth", function ()
      self.hooks[chatFrame].SetWidth(chatFrame, Core.db.profile.frameWidth)
    end, true)
    Utils.hookPresentation(self, chatFrame, "SetSize", function (_, _, height)
      self.hooks[chatFrame].SetSize(chatFrame, Core.db.profile.frameWidth, height)
    end, true)
    Utils.hookPresentation(self, chatFrame, "SetPoint", function ()
      applyCombatLogLayout()
    end, true)

    applyCombatLogLayout()

    if self.combatLogLayoutSubscription == nil then
      self.combatLogLayoutSubscription = Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "frameWidth" or key == "combatLogBarLayout" then
          applyCombatLogLayout()
        end
      end)
    end

  else
    Utils.hookPresentation(self, chatFrame, "SetPoint", function (frame, ...)
      if not frame.isDocked then
        self.hooks[chatFrame].SetPoint(frame, ...)
      else
        self.hooks[chatFrame].SetPoint(frame, "TOPLEFT", self:GetParent(), "TOPLEFT", 0, -45)
      end
    end, true)
  end

  -- Chat scroll frame
  self:SetHeight(self.config.height + self.config.overflowHeight)
  self:SetWidth(self.config.width)
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", 0, -getMessageTopInset(self.state.isCombatLog))

  -- Set initial scroll position
  self:SetVerticalScroll(self.config.overflowHeight)

  -- Overlay
  if self.overlay == nil then
    self.overlay = CreateScrollOverlayFrame(self)
    self.overlay:QuickHide()

    -- Snap to bottom on click
    self.overlay:SetScript("OnClickSnapFrame", function ()
      self.state.scrollAtBottom = true
      self.state.unreadMessages = false
      self.overlay:Hide()
      self.overlay:HideNewMessageAlert()

      local startOffset = math.max(
        self:GetVerticalScrollRange() - self.config.height * 2,
        self:GetVerticalScroll()
      )
      local endOffset = self:GetVerticalScrollRange()

      LibEasing:Ease(
        function (offset) self:SetVerticalScroll(offset) end,
        startOffset,
        endOffset,
        0.3,
        LibEasing.OutCubic,
        function ()
          self:SetHeight(self.config.height + self.config.overflowHeight)
        end
      )
    end)
  end

  -- Scrolling
  self:SetScript("OnMouseWheel", function (frame, delta)
    self:CancelDynamicEditBoxLayout(true)
    local maxScroll = (
      self.state.scrollAtBottom and
      self:GetVerticalScrollRange() + self.config.overflowHeight
      or self:GetVerticalScrollRange()
    )
    local minScroll = self.config.height + self.config.overflowHeight
    local scrollValue

    if delta < 0 then
      -- Scroll down
      scrollValue = math.min(self:GetVerticalScroll() + 20, maxScroll)
    else
      -- Scroll up
      scrollValue = math.max(self:GetVerticalScroll() - 20, math.min(minScroll, maxScroll))
    end

    self:UpdateScrollChildRect()
    self:SetVerticalScroll(scrollValue)

    self.state.scrollAtBottom = scrollValue == maxScroll

    -- Adjust height of scroll frame when scrolling
    if self.state.scrollAtBottom then
      -- If scrolled to the bottom, the height of the scroll frame should
      -- include overflow to account for slide up animations
      self:SetHeight(self.config.height + self.config.overflowHeight)
      self.overlay:Hide()
      self.overlay:HideNewMessageAlert()
      self.state.unreadMessages = false
    else
      -- If not, the height should fit the frame exactly so messages don't spill
      -- under the edit box area
      self:SetHeight(self.config.height)
      self.overlay:Show()
    end

    -- Show hidden messages
    self:CancelMessageHideTimer(true)
    for _, message in ipairs(self.state.messages) do
      message:Show()
    end
  end)

  -- Mouse clickthrough
  self:EnableMouse(false)

  -- ScrollChild
  if self.slider == nil then
    self.slider = CreateFrame("Frame", nil, self)
  end
  self.slider:SetHeight(self.config.height + self.config.overflowHeight)
  self.slider:SetWidth(self.config.width)
  self:SetScrollChild(self.slider)

  if self.slider.bg == nil then
    self.slider.bg = self.slider:CreateTexture(nil, "BACKGROUND")
  end
  self.slider.bg:SetAllPoints()
  self.slider.bg:SetColorTexture(0, 0, 1, 0)

  -- Pool for the message frames
  if self.messageFramePool == nil then
    self.messageFramePool = CreateMessageLinePool(self.slider)
  end

  local hookMessage = Constants.ENV == "retail" and self.SecureHook or self.Hook
  hookMessage(self, chatFrame, "AddMessage", function (...)
    local newestEntry = self.historyBuffer and self.historyBuffer:GetEntryAtIndex(1)
    self:AddMessageAt(getReceivedAt(newestEntry), ...)
  end, true)

  hookMessage(self, chatFrame, "Clear", function ()
    self:ClearMessages()
  end, true)

  if self.state.isCombatLog and type(chatFrame.BackFillMessage) == "function" then
    hookMessage(self, chatFrame, "BackFillMessage", function (...)
      local oldestEntry = self.historyBuffer and self.historyBuffer:GetEntryAtIndex(chatFrame:GetNumMessages())
      self:BackFillMessageAt(getReceivedAt(oldestEntry), ...)
    end, true)
  end

  if self.historyBuffer and not self.state.isCombatLog then
    hookMessage(self, self.historyBuffer, "PushBack", function (_, message)
      self:BackFillMessageAt(
        getReceivedAt(message),
        self.chatFrame,
        message.message,
        message.r,
        message.g,
        message.b
      )
    end, true)
  end

  self:HookChatFrameVisibility(chatFrame)

  if self.state.isCombatLog or Constants.ENV == "retail" then
    chatFrame:EnableMouse(false)
    chatFrame:EnableMouseWheel(false)
    Utils.hookPresentation(self, chatFrame, "SetAlpha", function (frame)
      self.hooks[chatFrame].SetAlpha(frame, 0)
    end, true)
    chatFrame:SetAlpha(0)
    if Constants.ENV ~= "retail" then
      chatFrame:SetShown(chatFrameWasShown)
    end
  else
    chatFrame:Hide()
  end

  -- Load any messages already in the chat frame to Glassy
  if chatFrame == DEFAULT_CHAT_FRAME or (self.state.isCombatLog and not isCombatLogHidden()) then
    local messageCount = chatFrame:GetNumMessages()
    local firstMessage = math.max(1, messageCount - getRenderedMessageLimit() + 1)
    for i = firstMessage, messageCount do
      local text, r, g, b = chatFrame:GetMessageInfo(i)
      self:AddMessageAt(getReceivedAt(getHistoryEntry(chatFrame, i)), chatFrame, text, r, g, b)
    end
  end

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(EDIT_BOX_LAYOUT_CHANGED, function ()
        self:UpdateDynamicEditBoxLayout()
      end),
      Core:Subscribe(MOUSE_ENTER, function ()
        -- Don't hide chats when mouse is over
        self.state.mouseOver = true
        self:CancelMessageHideTimer(true)

        if not self.state.scrollAtBottom then
          self.overlay:Show()
        end

        for _, message in ipairs(self.state.messages) do
          if Core.db.profile.chatShowOnMouseOver then
            message:Show()
          end
        end
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Hide chats when mouse leaves
        self.state.mouseOver = false

        self.overlay:HideDelay(Core.db.profile.chatHoldTime)
        if not self.state.typing then
          self:ScheduleVisibleMessageHides()
        end
      end),
      Core:Subscribe(EDIT_BOX_VISIBILITY_CHANGED, function (visible)
        self:SetTyping(visible)
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "combatLogVisibility" and self.state.isCombatLog then
          self:ApplyCombatLogVisibility()
        end

        if key == "chatFadeInDuration" or key == "chatFadeOutDuration" or key == "chatFadeEasing" then
          for _, message in ipairs(self.state.messages) do
            message:UpdateFadeSettings()
          end
        end

        if key == "chatShowWhileTyping" then
          local editBox = _G.ChatFrame1EditBox
          self:SetTyping(editBox and editBox.glassyEntryVisible)
        end

        if key == "editBoxEasing" and self.state.editBoxEasingHandle then
          self:UpdateDynamicEditBoxLayout()
        end

        if (
          key == "font" or
          key == "messageFontSize" or
          key == "frameWidth" or
          key == "frameHeight" or
          key == "textLeftPadding" or
          key == "messageLeading" or
          key == "messageLinePadding" or
          key == "indentWordWrap" or
          key == "iconTextureYOffset" or
          key == "emojiDisplay" or
          key == "timestampDisplay" or
          (key == "combatLogBarLayout" and self.state.isCombatLog)
        ) then
          self:CancelDynamicEditBoxLayout(false)
          -- Adjust frame dimensions first
          self.config.height = getMessageFrameHeight(self.state.isCombatLog)
          self.config.width = Core.db.profile.frameWidth

          self:ClearAllPoints()
          self:SetPoint("TOPLEFT", 0, -getMessageTopInset(self.state.isCombatLog))
          self:SetHeight(self.config.height + self.config.overflowHeight)
          self:SetWidth(self.config.width)

          -- Then adjust message line dimensions
          for _, message in ipairs(self.state.messages) do
            if (
              key == "iconTextureYOffset" or
              key == "emojiDisplay" or
              key == "timestampDisplay"
            ) and message.sourceText then
              local processedText = TP:ProcessText(message.sourceText, message.sourceFrame, message.receivedAt)
              message.text:SetText(processedText)
            end

            message:UpdateFrame()
          end

          -- Then update scroll values
          local contentHeight = 0
          for _, message in ipairs(self.state.messages) do
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

        if key == "chatBackgroundColor" or key == "backgroundFade" then
          for _, message in ipairs(self.state.messages) do
            message:UpdateTextures()
          end
        end
      end)
    }
  end
end

function SlidingMessageFrameMixin:CreateMessageFrame(messageArgs)
  local frame, text, red, green, blue = unpack(messageArgs)
  red = red or 1
  green = green or 1
  blue = blue or 1

  local message = self.messageFramePool:Acquire()
  -- Match Blizzard's pooled FontString reset so protected text aspects do not leak into later lines.
  message.text:ClearText()
  message.text:SetFontObject("GlassyMessageFont")
  local processedText, sourceText = TP:ProcessText(text, frame, messageArgs.receivedAt)
  message.sourceText = sourceText
  message.sourceFrame = frame
  message.receivedAt = messageArgs.receivedAt
  message.glassyPreview = messageArgs.glassyPreview
  message.text:SetTextColor(red, green, blue, 1)
  message.text:SetText(processedText)

  -- Adjust height to contain text
  message:UpdateFrame()

  return message
end

function SlidingMessageFrameMixin:AddMessage(...)
  self:AddMessageAt(GetServerTime(), ...)
end

function SlidingMessageFrameMixin:RemovePreviewMessages()
  local messages = self.state.messages
  local retained = {}
  local removedHeight = 0

  for _, message in ipairs(messages) do
    if message.glassyPreview then
      removedHeight = removedHeight + message:GetHeight()
      self.messageFramePool:Release(message)
    else
      retained[#retained + 1] = message
    end
  end
  if removedHeight == 0 then
    return
  end
  if self.state.prevEasingHandle then
    LibEasing:StopEasing(self.state.prevEasingHandle)
    self.state.prevEasingHandle = nil
  end

  for index, message in ipairs(retained) do
    message:ClearAllPoints()
    if index == #retained then
      message:SetPoint("BOTTOMLEFT")
    else
      message:SetPoint("BOTTOMLEFT", retained[index + 1], "TOPLEFT")
    end
  end

  self.state.messages = retained
  self.state.tail = retained[1]
  self.state.head = retained[#retained]
  local minimumHeight = self.config.height + self.config.overflowHeight
  self.slider:SetHeight(math.max(minimumHeight, self.slider:GetHeight() - removedHeight))
  self:UpdateScrollChildRect()
  if self.state.scrollAtBottom then
    self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
  end
end

function SlidingMessageFrameMixin:PreviewAnimations()
  self:CancelDynamicEditBoxLayout(true)
  if self.previewCleanupTimer then
    self.previewCleanupTimer:Cancel()
    self.previewCleanupTimer = nil
  end
  self:RemovePreviewMessages()

  self.state.scrollAtBottom = true
  self.state.unreadMessages = false
  self:SetHeight(self.config.height + self.config.overflowHeight)
  self:UpdateScrollChildRect()
  self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
  self.overlay:Hide()
  self.overlay:HideNewMessageAlert()

  local args = {
    self.chatFrame,
    "|cffffd100Glassy animation preview|r",
    1,
    1,
    1,
  }
  args.receivedAt = GetServerTime()
  args.glassyPreview = true
  table.insert(self.state.incomingMessages, args)
  UIManager:QueueFrameForUpdate(self)

  local totalDuration = math.max(
    tonumber(Core.db.profile.chatFadeInDuration) or 0,
    tonumber(Core.db.profile.chatSlideInDuration) or 0
  ) + 0.75 + math.max(0, tonumber(Core.db.profile.chatFadeOutDuration) or 0)
  self.previewCleanupTimer = C_Timer.NewTimer(totalDuration + 0.1, function ()
    self.previewCleanupTimer = nil
    if self.chatFrame then
      self:RemovePreviewMessages()
    end
  end)
end

function SlidingMessageFrameMixin:AddMessageAt(receivedAt, ...)
  if self.state.isCombatLog and isCombatLogHidden() then
    return
  end

  -- Enqueue messages to be displayed
  local args = {...}
  args.receivedAt = receivedAt
  table.insert(self.state.incomingMessages, args)
  UIManager:QueueFrameForUpdate(self)
end

function SlidingMessageFrameMixin:BackFillMessage(...)
  self:BackFillMessageAt(GetServerTime(), ...)
end

function SlidingMessageFrameMixin:BackFillMessageAt(receivedAt, ...)
  if self.state.isCombatLog and isCombatLogHidden() then
    return
  end

  local args = {...}
  args.receivedAt = receivedAt
  table.insert(self.state.incomingScrollbackMessages, args)
  UIManager:QueueFrameForUpdate(self)
end

function SlidingMessageFrameMixin:ReloadMessagesFromChatFrame()
  self:ClearMessages()

  local messageCount = self.chatFrame:GetNumMessages()
  local firstMessage = math.max(1, messageCount - getRenderedMessageLimit() + 1)
  for index = firstMessage, messageCount do
    local text, r, g, b = self.chatFrame:GetMessageInfo(index)
    if text then
      self:AddMessageAt(
        getReceivedAt(getHistoryEntry(self.chatFrame, index)),
        self.chatFrame,
        text,
        r,
        g,
        b
      )
    end
  end
end

function SlidingMessageFrameMixin:ApplyCombatLogVisibility()
  if not self.state.isCombatLog then
    return
  end

  if Constants.ENV == "retail" then
    if isCombatLogHidden() then
      self:ClearMessages()
    else
      self:ReloadMessagesFromChatFrame()
    end
    self:SyncNativeChatVisibility()
    return
  end

  if isCombatLogHidden() then
    self.hooks[self.chatFrame].Hide(self.chatFrame)
    keepCombatLogTracking()
    self:ClearMessages()
    self:Hide()
    return
  end

  self:ReloadMessagesFromChatFrame()
  local dock = _G.GENERAL_CHAT_DOCK
  local isSelected = dock and self.chatFrame.isDocked and dock.selected == self.chatFrame
  if isSelected or (not self.chatFrame.isDocked and _G.SELECTED_CHAT_FRAME == self.chatFrame) then
    self.hooks[self.chatFrame].Show(self.chatFrame)
    self:ApplyPendingDynamicEditBoxLayout()
    self:Show()
  else
    self.hooks[self.chatFrame].Hide(self.chatFrame)
    self:Hide()
  end
end

function SlidingMessageFrameMixin:ClearMessages()
  if self.state.prevEasingHandle ~= nil then
    LibEasing:StopEasing(self.state.prevEasingHandle)
    self.state.prevEasingHandle = nil
  end
  self:CancelMessageHideTimer(true)
  if self.previewCleanupTimer then
    self.previewCleanupTimer:Cancel()
    self.previewCleanupTimer = nil
  end

  self.messageFramePool:ReleaseAll()
  self.state.incomingScrollbackMessages = {}
  self.state.incomingMessages = {}
  self.state.messages = {}
  self.state.head = nil
  self.state.tail = nil
  self.state.scrollAtBottom = true
  self.state.unreadMessages = false

  self:SetHeight(self.config.height + self.config.overflowHeight)
  self.slider:SetHeight(self.config.height + self.config.overflowHeight)
  self:UpdateScrollChildRect()
  self:SetVerticalScroll(self.config.overflowHeight)
  self.overlay:Hide()
  self.overlay:HideNewMessageAlert()
end

function SlidingMessageFrameMixin:ReleaseOldestMessages(removeCount)
  removeCount = math.min(math.max(0, removeCount), #self.state.messages)
  if removeCount == 0 then
    return 0
  end

  local removedHeight = 0
  local messages = self.state.messages
  local messageCount = #messages
  for index = 1, removeCount do
    local message = messages[index]
    removedHeight = removedHeight + message:GetHeight()
    self.messageFramePool:Release(message)
  end

  local remainingCount = messageCount - removeCount
  for index = 1, remainingCount do
    messages[index] = messages[index + removeCount]
  end
  for index = remainingCount + 1, messageCount do
    messages[index] = nil
  end

  self.state.tail = messages[1]
  self.state.head = messages[#messages]

  return removedHeight
end

function SlidingMessageFrameMixin:ReleaseOverflowMessages()
  return self:ReleaseOldestMessages(#self.state.messages - getRenderedMessageLimit())
end

function SlidingMessageFrameMixin:OnFrame()
  if #self.state.incomingMessages > 0 then
    local incoming = self.state.incomingMessages
    self.state.incomingMessages = {}
    self:Update(incoming, false)
  end

  if #self.state.incomingScrollbackMessages > 0 then
    local incoming = self.state.incomingScrollbackMessages
    self.state.incomingScrollbackMessages = {}
    self:Update(incoming, true)
  end
end

function SlidingMessageFrameMixin:Update(incoming, reverse)
  self:CancelDynamicEditBoxLayout(true)
  local firstIncoming = 1
  local lastIncoming = #incoming
  local renderedLimit = getRenderedMessageLimit()
  if reverse then
    lastIncoming = math.min(lastIncoming, math.max(0, renderedLimit - #self.state.messages))
  else
    firstIncoming = math.max(1, lastIncoming - renderedLimit + 1)
  end

  if firstIncoming > lastIncoming then
    return
  end

  local incomingCount = lastIncoming - firstIncoming + 1
  local scrollOffset = self:GetVerticalScroll()
  local removeCount = reverse and 0 or math.max(0, #self.state.messages + incomingCount - renderedLimit)
  local removedExistingHeight = self:ReleaseOldestMessages(removeCount)

  -- Create new message frame for each message
  local newMessages = {}
  local newMessagesHeight = 0

  for incomingIndex = firstIncoming, lastIncoming do
    local message = incoming[incomingIndex]
    local messageFrame = self:CreateMessageFrame(message)
    messageFrame:SetPoint("BOTTOMLEFT")

    -- Attach previous messageFrame to this one
    if reverse then
      if self.state.tail then
        messageFrame:ClearAllPoints()
        messageFrame:SetPoint("BOTTOMLEFT", self.state.tail, "TOPLEFT")
      end
    else
      if self.state.head then
        self.state.head:ClearAllPoints()
        self.state.head:SetPoint("BOTTOMLEFT", messageFrame, "TOPLEFT")
      end
    end

    if self.state.tail == nil then
      self.state.tail = messageFrame
    end

    if self.state.head == nil then
      self.state.head = messageFrame
    end

    if reverse then
      self.state.tail = messageFrame
    else
      self.state.head = messageFrame
    end

    table.insert(newMessages, messageFrame)
    newMessagesHeight = newMessagesHeight + messageFrame:GetHeight()
  end

  if reverse then
    local existingCount = #self.state.messages
    local newCount = #newMessages
    for index = existingCount, 1, -1 do
      self.state.messages[index + newCount] = self.state.messages[index]
    end
    for index = 1, newCount do
      self.state.messages[index] = newMessages[newCount - index + 1]
    end
  else
    for _, message in ipairs(newMessages) do
      table.insert(self.state.messages, message)
    end
  end

  -- Keep the rendered pool and scroll range bounded by the configured history.
  local minimumHeight = self.config.height + self.config.overflowHeight
  local newHeight = math.max(minimumHeight, self.slider:GetHeight() + newMessagesHeight - removedExistingHeight)
  self.slider:SetHeight(newHeight)

  if removedExistingHeight > 0 then
    self:UpdateScrollChildRect()
    self:SetVerticalScroll(math.max(0, scrollOffset - removedExistingHeight))
  end

  -- Display and run everything
  if self.state.scrollAtBottom then
    -- Only play slide up if not scrolling
    if self.state.prevEasingHandle ~= nil then
      LibEasing:StopEasing(self.state.prevEasingHandle)
    end

    local startOffset = self:GetVerticalScroll()
    local endOffset = newHeight - self:GetHeight() + self.config.overflowHeight

    if Core.db.profile.chatSlideInDuration > 0 then
      self.state.prevEasingHandle = LibEasing:Ease(
        function (n) self:SetVerticalScroll(n) end,
        startOffset,
        endOffset,
        Core.db.profile.chatSlideInDuration,
        getSlideEasing(),
        function () self.state.prevEasingHandle = nil end
      )
    else
      self:SetVerticalScroll(endOffset)
    end
  else
    -- Otherwise show "Unread messages" notification
    self.state.unreadMessages = true
    self.overlay:Show()
    self.overlay:ShowNewMessageAlert()
    if not self.state.mouseOver then
      self.overlay:HideDelay(Core.db.profile.chatHoldTime)
    end
  end

  for _, message in ipairs(newMessages) do
    message:Show()
  end
  if not self.state.mouseOver and not self.state.typing then
    self:ScheduleMessageHides(newMessages)
  else
    local previews = {}
    for _, message in ipairs(newMessages) do
      if message.glassyPreview then
        previews[#previews + 1] = message
      end
    end
    if #previews > 0 then
      self:ScheduleMessageHides(previews)
    end
  end
end

local function CreateSlidingMessageFrame(name, parent, chatFrame)
  local frame = CreateFrame("ScrollFrame", name, parent)
  local object = Mixin(frame, SlidingMessageFrameMixin)
  AceHook:Embed(object)

  if chatFrame then
    object:Init(chatFrame)
  end
  object:Hide()
  return object
end

local function CreateSlidingMessageFramePool(parent)
  return CreateObjectPool(
    function () return CreateSlidingMessageFrame(nil, parent) end,
    function (_, smf)
      smf:Hide()

      if smf.state and smf.state.prevEasingHandle then
        LibEasing:StopEasing(smf.state.prevEasingHandle)
      end
      if smf.state and smf.state.editBoxEasingHandle then
        LibEasing:StopEasing(smf.state.editBoxEasingHandle)
        smf.state.editBoxEasingHandle = nil
        smf.state.editBoxTargetHeight = nil
      end
      if smf.state then
        smf.state.pendingEditBoxHeight = nil
      end
      smf:CancelMessageHideTimer(true)
      if smf.previewCleanupTimer then
        smf.previewCleanupTimer:Cancel()
        smf.previewCleanupTimer = nil
      end

      if smf.overlay then
        smf.overlay:QuickHide()
        if smf.overlay.newMessageAlertFrame then
          smf.overlay.newMessageAlertFrame:QuickHide()
        end
      end

      if smf.historyBuffer then
        smf:Unhook(smf.historyBuffer, "PushBack")
      end

      if smf.chatFrame then
        smf:Unhook(smf.chatFrame, "SetPoint")
        smf:Unhook(smf.chatFrame, "SetMaxLines")
        smf:Unhook(smf.chatFrame, "SetSize")
        smf:Unhook(smf.chatFrame, "SetWidth")
        smf:Unhook(smf.chatFrame, "AddMessage")
        smf:Unhook(smf.chatFrame, "BackFillMessage")
        smf:Unhook(smf.chatFrame, "Clear")
        smf:Unhook(smf.chatFrame, "Show")
        smf:Unhook(smf.chatFrame, "SetShown")
        smf:Unhook(smf.chatFrame, "Hide")
        smf:Unhook(smf.chatFrame, "SetAlpha")
        smf:Unhook(smf.chatFrame, "OnShow")
        smf:Unhook(smf.chatFrame, "OnHide")
      end

      smf.chatFrame = nil
      smf.historyBuffer = nil

      if smf.state ~= nil then
        smf.state.head = nil
        smf.state.tail = nil
        smf.state.messages = {}
        smf.state.incomingMessages = {}
        smf.state.incomingScrollbackMessages = {}
      end

      if smf.messageFramePool ~= nil then
        smf.messageFramePool:ReleaseAll()
      end
    end
  )
end

Core.Components.CreateSlidingMessageFrame = CreateSlidingMessageFrame
Core.Components.CreateSlidingMessageFramePool = CreateSlidingMessageFramePool
