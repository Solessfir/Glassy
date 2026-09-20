local Core, Constants, Utils = unpack(select(2, ...))

local LibEasing = Core.Libs.LibEasing
local CreateMessageLinePool = Core.Components.CreateMessageLinePool
local CreateScrollOverlayFrame = Core.Components.CreateScrollOverlayFrame
local SlidingMessageFrameMixin = Core.Components.SlidingMessageFrameMixin
local Helpers = Core.Components.SlidingMessageFrameHelpers

local getMessageTopInset = Helpers.getMessageTopInset
local getScrollbackLimit = Helpers.getScrollbackLimit
local getRenderedMessageLimit = Helpers.getRenderedMessageLimit
local getReceivedAt = Helpers.getReceivedAt
local getHistoryEntry = Helpers.getHistoryEntry
local isCombatLogHidden = Helpers.isCombatLogHidden
local keepCombatLogTracking = Helpers.keepCombatLogTracking
local getMessageFrameHeight = Helpers.getMessageFrameHeight

local EDIT_BOX_LAYOUT_CHANGED = Constants.EVENTS.EDIT_BOX_LAYOUT_CHANGED
local EDIT_BOX_VISIBILITY_CHANGED = Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED
local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
-- luacheck: pop

function SlidingMessageFrameMixin:SyncNativeChatVisibility()
  local shown = self.chatFrame:IsShown() and not (self.state.isCombatLog and isCombatLogHidden())
  if shown then
    self:ApplyPendingDynamicEditBoxLayout()
  end
  self:SetGlassyShown(shown)
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
        self:SetGlassyShown(false)
        return
      end
      self.hooks[chatFrame].Show(frame)
    elseif not frame.isDocked then
      self.hooks[chatFrame].Show(frame)
    end
    self:ApplyPendingDynamicEditBoxLayout()
    self:SetGlassyShown(true)
  end, true)

  -- FCF_CheckShowChatFrame uses SetShown when switching or creating tabs.
  self:RawHook(chatFrame, "SetShown", function (_, shown)
    if self.state.isCombatLog and isCombatLogHidden() then
      self.hooks[chatFrame].SetShown(chatFrame, false)
      keepCombatLogTracking()
      self:SetGlassyShown(false)
      return
    end
    self.hooks[chatFrame].SetShown(
      chatFrame,
      (self.state.isCombatLog or not chatFrame.isDocked) and shown or false
    )
    if shown then
      self:ApplyPendingDynamicEditBoxLayout()
    end
    self:SetGlassyShown(shown)
  end, true)

  self:RawHook(chatFrame, "Hide", function (frame)
    self.hooks[chatFrame].Hide(frame)
    if self.state.isCombatLog and isCombatLogHidden() then
      keepCombatLogTracking()
    end
    self:SetGlassyShown(false)
  end, true)
end


function SlidingMessageFrameMixin:ResetForChatFrame(chatFrame)
  local isCombatLog = chatFrame == _G.ChatFrame2
  self.config = {
    height = getMessageFrameHeight(isCombatLog),
    width = tonumber(Core.db.profile.frameWidth) or Core.defaults.profile.frameWidth,
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
  self.layoutWidth = nil
  self.layoutHeight = nil
  self.layoutEditBox = nil
  self.detachedContainer = nil
end

function SlidingMessageFrameMixin:ConfigureScrollback(chatFrame)
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
end

function SlidingMessageFrameMixin:ConfigureNativeLayout(chatFrame)
  _G[chatFrame:GetName().."ButtonFrame"]:Hide()

  chatFrame:SetClampRectInsets(0,0,0,0)
  chatFrame:SetClampedToScreen(false)

  if self.state.isCombatLog then
    if chatFrame.isDocked then
      chatFrame:ClearAllPoints()
    end

    local function applyCombatLogLayout()
      if not chatFrame.isDocked then
        return
      end
      local layoutParent = self:GetNativeLayoutParent()
      if Constants.ENV == "retail" then chatFrame:ClearAllPoints() end
      self.hooks[chatFrame].SetPoint(
        chatFrame,
        "TOPLEFT",
        layoutParent,
        "TOPLEFT",
        0,
        -getMessageTopInset(true)
      )
      self.hooks[chatFrame].SetPoint(
        chatFrame,
        "BOTTOMLEFT",
        layoutParent,
        "BOTTOMLEFT",
        0,
        0
      )
      self.hooks[chatFrame].SetWidth(chatFrame, self:GetNativeLayoutWidth())
    end

    Utils.hookPresentation(self, chatFrame, "SetWidth", function (_, width)
      if self:KeepDetachedNativeLayout("SetWidth", width) then
        return
      end
      self.hooks[chatFrame].SetWidth(chatFrame, self:GetNativeLayoutWidth())
    end, true)
    Utils.hookPresentation(self, chatFrame, "SetSize", function (_, width, height)
      if self:KeepDetachedNativeLayout("SetSize", width, height) then
        return
      end
      self.hooks[chatFrame].SetSize(chatFrame, self:GetNativeLayoutWidth(), height)
    end, true)
    Utils.hookPresentation(self, chatFrame, "SetPoint", function (_, ...)
      if self:KeepDetachedNativeLayout("SetPoint", ...) then
        return
      end
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
  end
end

function SlidingMessageFrameMixin:InitializeScrollFrame()
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

      self:UpdateViewportHeight()
      local startOffset = self:GetVerticalScroll()
      local endOffset = self:GetVerticalScrollRange() + self.config.overflowHeight

      LibEasing:Ease(
        function (offset) self:SetVerticalScroll(offset) end,
        startOffset,
        endOffset,
        0.3,
        LibEasing.OutCubic,
        function ()
          self:SetVerticalScroll(endOffset)
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
      self:UpdateViewportHeight()
      self:SetVerticalScroll(self:GetVerticalScrollRange() + self.config.overflowHeight)
      self.overlay:Hide()
      self.overlay:HideNewMessageAlert()
      self.state.unreadMessages = false
    else
      -- While scrolled back, reserve the bottom row for the return-to-latest control so it never covers a chat message.
      self:UpdateViewportHeight()
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
end

function SlidingMessageFrameMixin:HookNativeMessages(chatFrame, chatFrameWasShown)
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

  chatFrame:EnableMouse(false)
  chatFrame:EnableMouseWheel(false)
  Utils.hookPresentation(self, chatFrame, "SetAlpha", function (frame)
    self.hooks[chatFrame].SetAlpha(frame, 0)
  end, true)
  chatFrame:SetAlpha(0)
  if self.state.isCombatLog or Constants.ENV == "retail" or not chatFrame.isDocked then
    if Constants.ENV ~= "retail" then
      chatFrame:SetShown(chatFrameWasShown)
    end
  else
    chatFrame:Hide()
    self:SetGlassyShown(chatFrameWasShown)
  end
end

function SlidingMessageFrameMixin:LoadInitialMessages(chatFrame)
  if chatFrame == DEFAULT_CHAT_FRAME or not chatFrame.isDocked or (self.state.isCombatLog and not isCombatLogHidden()) then
    local messageCount = chatFrame:GetNumMessages()
    local firstMessage = math.max(1, messageCount - getRenderedMessageLimit() + 1)
    for i = firstMessage, messageCount do
      local text, r, g, b = chatFrame:GetMessageInfo(i)
      self:AddMessageAt(getReceivedAt(getHistoryEntry(chatFrame, i)), chatFrame, text, r, g, b)
    end
  end
end

function SlidingMessageFrameMixin:SubscribeToEvents()
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
          message:Show()
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
          local editBox = self.layoutEditBox == false and nil or self.layoutEditBox or _G.ChatFrame1EditBox
          self:SetTyping(editBox and editBox.glassyEntryVisible)
        end

        if key == "chatAlwaysVisible" then
          self:UpdateAlwaysVisible()
        end

        if key == "messageBlacklist" then
          self:ReloadMessagesFromChatFrame()
        end

        if key == "editBoxEasing" and self.state.editBoxEasingHandle then
          self:UpdateDynamicEditBoxLayout()
        end

        if (
          key == "font" or
          key == "messageFontSize" or
          key == "frameWidth" or
          key == "frameHeight" or
          key == "tabMessageSpacing" or
          key == "textLeftPadding" or
          key == "messageLeading" or
          key == "messageLinePadding" or
          key == "indentWordWrap" or
          key == "iconTextureYOffset" or
          key == "emojiDisplay" or
          key == "timestampDisplay" or
          (key == "combatLogBarLayout" and self.state.isCombatLog)
        ) then
          self:RefreshLayout(
            key == "iconTextureYOffset" or
            key == "emojiDisplay" or
            key == "timestampDisplay"
          )
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

function SlidingMessageFrameMixin:Init(chatFrame)
  local chatFrameWasShown = chatFrame:IsShown()
  self:ResetForChatFrame(chatFrame)
  self:ConfigureScrollback(chatFrame)
  self:ConfigureNativeLayout(chatFrame)
  self:InitializeScrollFrame()
  self:HookNativeMessages(chatFrame, chatFrameWasShown)
  self:LoadInitialMessages(chatFrame)
  self:SubscribeToEvents()
end
