local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local EDIT_BOX_VISIBILITY_CHANGED = Constants.EVENTS.EDIT_BOX_VISIBILITY_CHANGED
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local Mixin = Mixin
local FCFDock_GetSelectedWindow = FCFDock_GetSelectedWindow
local FCF_SelectDockFrame = FCF_SelectDockFrame
local GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK
local GeneralDockManager = GeneralDockManager
-- luacheck: pop

local ChatDockMixin = {}
Core.Components.ChatDockMixin = ChatDockMixin

local function getSafeDockInsertIndex(original, dock, chatFrame, mouseX, mouseY)
  if not chatFrame.isDocked then
    return #dock.DOCKED_CHAT_FRAMES + 1
  end

  return original(dock, chatFrame, mouseX, mouseY)
end

local function updateMessageSeparator(self)
  self.messageSeparator:SetSeparatorColor(Core.db.profile.tabMessageSeparatorColor)
end

function ChatDockMixin:SaveSelectedTab(chatFrame)
  if (
    chatFrame and
    chatFrame.isDocked and
    not chatFrame.isTemporary and
    (chatFrame ~= _G.ChatFrame2 or not Core.db.profile.combatLogHidden)
  ) then
    Core.db.profile.selectedTab = chatFrame:GetName()
  end
end

function ChatDockMixin:RestoreSelectedTab(initiallyShownChatFrame)
  if Constants.ENV == "retail" then
    -- Native tab selection can apply protected combat filters; restore only Glassy's display on Retail.
    local selectedFrame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or initiallyShownChatFrame or _G.ChatFrame1
    local tab = _G[selectedFrame:GetName().."Tab"]
    if tab and tab.slidingMessageFrame then
      local smf = tab.slidingMessageFrame
      smf:SetShown(selectedFrame ~= _G.ChatFrame2 or not Core.db.profile.combatLogHidden)
    end
    self.selectionPersistenceReady = true
    self:SaveSelectedTab(selectedFrame)
    return
  end

  local savedFrameName = Core.db.profile.selectedTab
  local selectedFrame = savedFrameName ~= "" and _G[savedFrameName] or initiallyShownChatFrame
  if (
    selectedFrame == nil or
    not selectedFrame.isDocked or
    (selectedFrame == _G.ChatFrame2 and Core.db.profile.combatLogHidden)
  ) then
    selectedFrame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) or _G.ChatFrame1
  end

  if selectedFrame == _G.ChatFrame2 and Core.db.profile.combatLogHidden then
    selectedFrame = self:GetOrderedDockFrames()[1] or _G.ChatFrame1
  end

  _G.SELECTED_CHAT_FRAME = selectedFrame
  FCF_SelectDockFrame(selectedFrame)
  self.selectionPersistenceReady = true
  self:SaveSelectedTab(selectedFrame)
end

function ChatDockMixin:GetOrderedDockFrames()
  local dockedByName = {}
  local dockedFrames = {}
  for _, chatFrame in ipairs(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) do
    if chatFrame ~= _G.ChatFrame2 or not Core.db.profile.combatLogHidden then
      dockedByName[chatFrame:GetName()] = chatFrame
      table.insert(dockedFrames, chatFrame)
    end
  end

  local orderedFrames = {}
  local added = {}
  local savedOrder = Core.db.profile.tabOrder or {}
  for _, frameName in ipairs(savedOrder) do
    local chatFrame = dockedByName[frameName]
    if chatFrame and not added[frameName] then
      table.insert(orderedFrames, chatFrame)
      added[frameName] = true
    end
  end

  if #savedOrder == 0 and Core.db.profile.combatLogTabFirst then
    local combatLog = dockedByName.ChatFrame2
    if combatLog then
      table.insert(orderedFrames, combatLog)
      added.ChatFrame2 = true
    end
  end

  for _, chatFrame in ipairs(dockedFrames) do
    local frameName = chatFrame:GetName()
    if not added[frameName] then
      table.insert(orderedFrames, chatFrame)
      added[frameName] = true
    end
  end

  return orderedFrames
end

function ChatDockMixin:SaveTabOrder(orderedFrames)
  local savedOrder = {}
  for _, chatFrame in ipairs(orderedFrames) do
    table.insert(savedOrder, chatFrame:GetName())
  end

  if Core.db.profile.combatLogHidden then
    local hiddenIndex = 2
    for index, frameName in ipairs(Core.db.profile.tabOrder or {}) do
      if frameName == "ChatFrame2" then
        hiddenIndex = index
        break
      end
    end
    table.insert(savedOrder, math.min(hiddenIndex, #savedOrder + 1), "ChatFrame2")
  end

  Core.db.profile.tabOrder = savedOrder
end

function ChatDockMixin:SelectVisibleFallback()
  local selectedFrame = self:GetOrderedDockFrames()[1] or _G.ChatFrame1
  _G.SELECTED_CHAT_FRAME = selectedFrame
  FCF_SelectDockFrame(selectedFrame)
end

function ChatDockMixin:UpdateTabVisualStates()
  for _, chatFrame in ipairs(GENERAL_CHAT_DOCK.DOCKED_CHAT_FRAMES) do
    local tab = _G[chatFrame:GetName().."Tab"]
    if tab and tab.UpdateVisualState then
      tab:UpdateVisualState()
    end
  end

  if self.overflowButton.list:IsShown() then
    self:StyleOverflowList()
  end
  self:UpdateOverflowButtonHighlight()
end

function ChatDockMixin:UpdateFadeSettings()
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
  self:SetFadeEasing(Core.db.profile.chatFadeEasing)
end

function ChatDockMixin:UpdateAutomaticVisibility()
  if Core.db.profile.chatAlwaysVisible or self.state.typing then
    self:QuickShow()
  else
    self:HideDelay(Core.db.profile.chatHoldTime)
  end
end

function ChatDockMixin:SetTyping(visible)
  self.state.editBoxVisible = not not visible
  local typing = self.state.editBoxVisible and Core.db.profile.chatShowWhileTyping or false
  if self.state.typing == typing then
    return
  end

  self.state.typing = typing
  if typing then
    self:Show()
  elseif not self.state.mouseOver then
    self:UpdateAutomaticVisibility()
  end
end

function ChatDockMixin:Init(parent)
  self.state = {
    editBoxVisible = false,
    mouseOver = false,
    typing = false,
  }
  self.selectionPersistenceReady = false

  self:SetWidth(Core.db.profile.frameWidth)
  self:SetHeight(Constants.DOCK_HEIGHT)
  self:ClearAllPoints()
  self:SetPoint("TOPLEFT", parent, "TOPLEFT")
  self:UpdateFadeSettings()

  self.scrollFrame:SetHeight(Constants.DOCK_HEIGHT)
  self.scrollFrame.child:SetHeight(Constants.DOCK_HEIGHT)

  local bottomPoint, bottomRelativeTo, bottomRelativePoint, bottomX, bottomY
  for pointIndex = 1, self.scrollFrame:GetNumPoints() do
    local point, relativeTo, relativePoint, xOffset, yOffset = self.scrollFrame:GetPoint(pointIndex)
    if point == "BOTTOMRIGHT" then
      bottomPoint = point
      bottomRelativeTo = relativeTo
      bottomRelativePoint = relativePoint
      bottomX = xOffset
      bottomY = yOffset
      break
    end
  end

  if not self:IsHooked(self.scrollFrame, "SetPoint") then
    Utils.hookPresentation(self, self.scrollFrame, "SetPoint", function (frame, point, relativeTo, relativePoint, xOffset, yOffset)
      if point == "BOTTOMRIGHT" then
        yOffset = (yOffset or 0) + 5
      end

      self.hooks[self.scrollFrame].SetPoint(frame, point, relativeTo, relativePoint, xOffset, yOffset)
    end, true)
  end

  if not self:IsHooked("FCFDock_UpdateTabs") then
    self:SecureHook("FCFDock_UpdateTabs", function (dock)
      if dock == GENERAL_CHAT_DOCK then
        self:UpdateTabOrder()
      end
    end)
  end

  if Constants.ENV ~= "retail" and type(_G.FCFDock_GetInsertIndex) == "function" and not self:IsHooked("FCFDock_GetInsertIndex") then
    self:RawHook("FCFDock_GetInsertIndex", function (dock, chatFrame, mouseX, mouseY)
      return getSafeDockInsertIndex(self.hooks.FCFDock_GetInsertIndex, dock, chatFrame, mouseX, mouseY)
    end, true)
  end

  if not self:IsHooked("FCFDock_SelectWindow") then
    self:SecureHook("FCFDock_SelectWindow", function (dock, chatFrame)
      if dock == GENERAL_CHAT_DOCK then
        if Core.db.profile.combatLogHidden and chatFrame == _G.ChatFrame2 then
          self:SelectVisibleFallback()
        elseif self.selectionPersistenceReady then
          self:SaveSelectedTab(chatFrame)
        end
        self:UpdateTabVisualStates()
      end
    end)
  end

  if type(_G.FCFDockOverflowList_Update) == "function" and not self:IsHooked("FCFDockOverflowList_Update") then
    self:SecureHook("FCFDockOverflowList_Update", function (list, dock)
      if dock == GENERAL_CHAT_DOCK then
        self:FilterOverflowList(list)
        self:StyleOverflowList()
      end
    end)
  end

  -- Correct the anchor that Blizzard applied before Glassy installed its hook.
  if bottomPoint then
    self.scrollFrame:SetPoint(bottomPoint, bottomRelativeTo, bottomRelativePoint, bottomX, bottomY)
  end

  self:StyleOverflowButton()
  self:UpdateTabOrder()

  if self.messageSeparator == nil then
    self.messageSeparator = CreateSeparatorFrame(self)
    self.messageSeparator:SetPoint("BOTTOMLEFT")
    self.messageSeparator:SetPoint("BOTTOMRIGHT")
  end

  -- Overlap the message background by one physical pixel to avoid a subpixel seam.
  local backgroundColor = Core.db.profile.headerBackgroundColor
  self:SetGradientBackground(backgroundColor, backgroundColor.a)
  updateMessageSeparator(self)

  if Core.db.profile.chatAlwaysVisible then
    self:QuickShow()
  else
    self:QuickHide()
  end

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(MOUSE_ENTER, function ()
        -- Don't hide tabs when mouse is over
        self.state.mouseOver = true
        self:Show()
      end),
      Core:Subscribe(MOUSE_LEAVE, function ()
        -- Hide chat tab when mouse leaves
        self.state.mouseOver = false

        self:UpdateAutomaticVisibility()
      end),
      Core:Subscribe(EDIT_BOX_VISIBILITY_CHANGED, function (visible)
        self:SetTyping(visible)
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "combatLogVisibility" then
          self:UpdateCombatLogVisibility()
        end

        if key == "frameWidth" or key == "headerBackgroundColor" or key == "backgroundFade" then
          self:SetWidth(Core.db.profile.frameWidth)

          backgroundColor = Core.db.profile.headerBackgroundColor
          self:SetGradientBackground(backgroundColor, backgroundColor.a)
        end

        if key == "tabMessageSeparatorColor" or key == "frameWidth" or key == "backgroundFade" then
          updateMessageSeparator(self)
        end

        if key == "chatFadeInDuration" or key == "chatFadeOutDuration" or key == "chatFadeEasing" then
          self:UpdateFadeSettings()
        end

        if key == "chatAlwaysVisible" then
          if Core.db.profile.chatAlwaysVisible or not self.state.mouseOver then
            self:UpdateAutomaticVisibility()
          end
        end

        if key == "chatShowWhileTyping" then
          self:SetTyping(self.state.editBoxVisible)
        end

        if key == "tabTextColor" or key == "tabHighlightTextColor" then
          self:UpdateTabVisualStates()
          self:UpdateOverflowButtonHighlight()
          if self.overflowButton.list:IsShown() then self:StyleOverflowList() end
        end
      end)
    }
  end
end

local isCreated = false

Core.Components.CreateChatDock = function (parent)
  if isCreated then
    error("ChatDock already exists. Only one ChatDock can exist at a time.")
  end

  local FadingFrameMixin = Core.Components.FadingFrameMixin
  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin

  isCreated = true
  local object = Mixin(GeneralDockManager, FadingFrameMixin, GradientBackgroundMixin, ChatDockMixin)
  AceHook:Embed(object)
  FadingFrameMixin.Init(object)
  GradientBackgroundMixin.Init(object)
  ChatDockMixin.Init(object, parent)
  return object
end

Core.Components.GetSafeDockInsertIndex = getSafeDockInsertIndex
