local Core, Constants, Utils = unpack(select(2, ...))
local TP = Core:GetModule("TextProcessing")
local UIManager = Core:GetModule("UIManager")

local AceHook = Core.Libs.AceHook

local LibEasing = Core.Libs.LibEasing

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
local GetServerTime = GetServerTime
local GetTime = GetTime
local Mixin = Mixin
-- luacheck: pop

----
-- SlidingMessageFrameMixin
--
-- Custom frame for displaying pretty sliding messages
local SlidingMessageFrameMixin = {}
Core.Components.SlidingMessageFrameMixin = SlidingMessageFrameMixin

local RENDERED_MESSAGE_LIMIT = 128
local MESSAGE_UPDATE_BATCH_SIZE = 16
local DEFAULT_UNREAD_ROW_HEIGHT = 24

local function getBaseMessageTopInset(isCombatLog)
  local inset = Constants.DOCK_HEIGHT
  if isCombatLog and Core.db.profile.combatLogBarPosition == "BELOW" then
    inset = inset + Constants.COMBAT_LOG_BAR_HEIGHT
  end
  return inset
end

local function getMessageTopInset(isCombatLog)
  local offset = tonumber(Core.db.profile.tabMessageSpacing) or Core.defaults.profile.tabMessageSpacing
  return getBaseMessageTopInset(isCombatLog) + offset
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

local function getMessageFrameHeight(isCombatLog, frameHeight, editBox)
  frameHeight = tonumber(frameHeight) or tonumber(Core.db.profile.frameHeight) or Core.defaults.profile.frameHeight
  if editBox == nil then
    editBox = _G.ChatFrame1EditBox
  elseif editBox == false then
    editBox = nil
  end
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
  return math.max(1, frameHeight - getBaseMessageTopInset(isCombatLog) + reusableHeight)
end


Core.Components.SlidingMessageFrameHelpers = {
  getBaseMessageTopInset = getBaseMessageTopInset,
  getMessageTopInset = getMessageTopInset,
  getScrollbackLimit = getScrollbackLimit,
  getRenderedMessageLimit = getRenderedMessageLimit,
  getSlideEasing = getSlideEasing,
  getEditBoxEasing = getEditBoxEasing,
  getReceivedAt = getReceivedAt,
  getHistoryEntry = getHistoryEntry,
  isCombatLogHidden = isCombatLogHidden,
  keepCombatLogTracking = keepCombatLogTracking,
  getMessageFrameHeight = getMessageFrameHeight,
}
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
      elseif Core.db.profile.chatAlwaysVisible then
        message.glassyHideAt = nil
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

function SlidingMessageFrameMixin:UpdateAlwaysVisible()
  if Core.db.profile.chatAlwaysVisible then
    self:CancelMessageHideTimer(true)
    for _, message in ipairs(self.state.messages) do
      message:Show()
    end
  elseif not self.state.mouseOver and not self.state.typing then
    self:ScheduleVisibleMessageHides()
  end
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
  if TP:IsMessageBlacklisted(select(2, ...)) then
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
  if TP:IsMessageBlacklisted(select(2, ...)) then
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
    self:SetGlassyShown(false)
    return
  end

  self:ReloadMessagesFromChatFrame()
  local dock = _G.GENERAL_CHAT_DOCK
  local isSelected = dock and self.chatFrame.isDocked and dock.selected == self.chatFrame
  if isSelected or (not self.chatFrame.isDocked and _G.SELECTED_CHAT_FRAME == self.chatFrame) then
    self.hooks[self.chatFrame].Show(self.chatFrame)
    self:ApplyPendingDynamicEditBoxLayout()
    self:SetGlassyShown(true)
  else
    self.hooks[self.chatFrame].Hide(self.chatFrame)
    self:SetGlassyShown(false)
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
    local incoming = {}
    for _ = 1, math.min(MESSAGE_UPDATE_BATCH_SIZE, #self.state.incomingMessages) do
      incoming[#incoming + 1] = table.remove(self.state.incomingMessages, 1)
    end
    self:Update(incoming, false)
  elseif #self.state.incomingScrollbackMessages > 0 then
    local incoming = {}
    for _ = 1, math.min(MESSAGE_UPDATE_BATCH_SIZE, #self.state.incomingScrollbackMessages) do
      incoming[#incoming + 1] = table.remove(self.state.incomingScrollbackMessages, 1)
    end
    self:Update(incoming, true)
  end

  -- Spread history restoration across game frames so text layout cannot exhaust the script budget.
  if #self.state.incomingMessages > 0 or #self.state.incomingScrollbackMessages > 0 then
    UIManager:QueueFrameForUpdate(self)
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
  else
    object:Hide()
  end
  return object
end

local function CreateSlidingMessageFramePool(parent)
  return CreateObjectPool(
    function () return CreateSlidingMessageFrame(nil, parent) end,
    function (_, smf)
      smf:Hide()
      if smf.detachedContainer then
        smf.detachedContainer:Hide()
      end

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
      smf.layoutWidth = nil
      smf.layoutHeight = nil
      smf.layoutEditBox = nil
      smf.detachedContainer = nil

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
