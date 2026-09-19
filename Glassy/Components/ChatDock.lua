local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local MOUSE_ENTER = Constants.EVENTS.MOUSE_ENTER
local MOUSE_LEAVE = Constants.EVENTS.MOUSE_LEAVE
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG
local CreateSeparatorFrame = Core.Components.CreateSeparatorFrame

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local Mixin = Mixin
local FCFDock_GetSelectedWindow = FCFDock_GetSelectedWindow
local FCFDock_HideInsertHighlight = FCFDock_HideInsertHighlight
local FCFDockOverflowListButton_SetValue = FCFDockOverflowListButton_SetValue
local FCF_SelectDockFrame = FCF_SelectDockFrame
local CHAT_WINDOWS_COUNT = CHAT_WINDOWS_COUNT
local CreateFrame = CreateFrame
local GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK
local GeneralDockManager = GeneralDockManager
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local UIParent = UIParent
-- luacheck: pop

local ChatDockMixin = {}
local TAB_DRAG_SCROLL_EDGE = 32
local TAB_DRAG_SCROLL_SPEED = 300

local function getSafeDockInsertIndex(original, dock, chatFrame, mouseX, mouseY)
  if not chatFrame.isDocked then
    return #dock.DOCKED_CHAT_FRAMES + 1
  end

  return original(dock, chatFrame, mouseX, mouseY)
end

local function updateMessageSeparator(self)
  self.messageSeparator:SetSeparatorColor(Core.db.profile.tabMessageSeparatorColor)
end

local function getTabColor(chatFrame)
  local brightness = 1
  if chatFrame and chatFrame.isDocked and GENERAL_CHAT_DOCK.selected == chatFrame then
    brightness = 1 + math.max(0, math.min(1, tonumber(Core.db.profile.activeTabHighlightStrength) or 0))
  end
  local color = Constants.COLORS.apache
  return math.min(1, color.r * brightness), math.min(1, color.g * brightness), math.min(1, color.b * brightness)
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
end

function ChatDockMixin:UpdateFadeSettings()
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
  self:SetFadeEasing(Core.db.profile.chatFadeEasing)
end

function ChatDockMixin:FilterOverflowList(list)
  if not Core.db.profile.combatLogHidden or list == nil or list.buttons == nil then
    return
  end

  local orderedFrames = self:GetOrderedDockFrames()
  local totalHeight = 25
  if list.numTabs then
    list.numTabs:SetFormattedText(CHAT_WINDOWS_COUNT, #orderedFrames)
  end

  for index, chatFrame in ipairs(orderedFrames) do
    local button = list.buttons[index]
    if button then
      FCFDockOverflowListButton_SetValue(button, chatFrame)
      totalHeight = totalHeight + button:GetHeight() + 3
    end
  end

  for index = #orderedFrames + 1, #list.buttons do
    list.buttons[index]:Hide()
  end
  list:SetHeight(totalHeight)
end

function ChatDockMixin:StyleOverflowList()
  local list = self.overflowButton.list
  if list.SetBackdropColor then
    list:SetBackdropColor(0, 0, 0, 0.9)
  end
  if list.SetBackdropBorderColor then
    local color = Constants.COLORS.apache
    list:SetBackdropBorderColor(color.r, color.g, color.b, 0.5)
  end
  if list.numTabs then
    list.numTabs:SetFontObject("GlassyChatDockFont")
    list.numTabs:SetTextColor(0.65, 0.65, 0.65)
  end

  for _, button in ipairs(list.buttons or {}) do
    button:SetNormalFontObject("GlassyChatDockFont")
    local fontString = button:GetFontString()
    if fontString then
      local tab = button.chatFrame and _G[button.chatFrame:GetName().."Tab"]
      if button.chatFrame and button.chatFrame.isTemporary and tab and tab.Text then
        fontString:SetTextColor(tab.Text:GetTextColor())
      else
        fontString:SetTextColor(getTabColor(button.chatFrame))
      end
    end
    if button.highlight then
      button.highlight:SetTexture("Interface\\Buttons\\WHITE8X8")
      button.highlight:SetVertexColor(
        Constants.COLORS.apache.r,
        Constants.COLORS.apache.g,
        Constants.COLORS.apache.b,
        0.18
      )
    end
  end
end

function ChatDockMixin:StyleOverflowButton()
  local button = self.overflowButton
  button:SetSize(Constants.DOCK_HEIGHT, Constants.DOCK_HEIGHT)
  button.width = Constants.DOCK_HEIGHT
  button:SetAlpha(1)

  local normalTexture = button:GetNormalTexture()
  if normalTexture then
    normalTexture:SetTexture(nil)
  end
  local highlightTexture = button:GetHighlightTexture()
  if highlightTexture then
    highlightTexture:SetTexture("Interface\\Buttons\\WHITE8X8")
    highlightTexture:ClearAllPoints()
    highlightTexture:SetAllPoints(button)
    highlightTexture:SetVertexColor(
      Constants.COLORS.apache.r,
      Constants.COLORS.apache.g,
      Constants.COLORS.apache.b,
      0.18
    )
  end

  if button.glassyText == nil then
    button.glassyText = button:CreateFontString(nil, "OVERLAY", "GlassyChatDockFont")
    button.glassyText:SetPoint("CENTER", 0, 2)
    button.glassyText:SetText("...")
  end
  button.glassyText:SetTextColor(
    Constants.COLORS.apache.r,
    Constants.COLORS.apache.g,
    Constants.COLORS.apache.b
  )

  button:HookScript("OnEnter", function ()
    button.glassyText:SetTextColor(1, 1, 1)
  end)
  button:HookScript("OnLeave", function ()
    button.glassyText:SetTextColor(
      Constants.COLORS.apache.r,
      Constants.COLORS.apache.g,
      Constants.COLORS.apache.b
    )
  end)
  self:HookScript(button.list, "OnShow", function ()
    self:FilterOverflowList(button.list)
    self:StyleOverflowList()
  end)
end

function ChatDockMixin:UpdateCombatLogVisibility()
  if Core.db.profile.combatLogHidden and FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK) == _G.ChatFrame2 then
    self:SelectVisibleFallback()
  end
  self:UpdateTabOrder()
  if self.overflowButton.list:IsShown() then
    _G.FCFDockOverflowList_Update(self.overflowButton.list, GENERAL_CHAT_DOCK)
  end
end

function ChatDockMixin:LayoutDockedTabs(orderedFrames, keepSelectedVisible, gap)
  local child = self.scrollFrame.child
  local totalWidth = 0
  local offsets = {}
  local hasPreviousSlot = false

  self.scrollFrame:SetScript("OnUpdate", nil)
  self.scrollFrame:SetPoint("LEFT", self, "LEFT", 0, 0)

  for index, chatFrame in ipairs(orderedFrames) do
    local tab = _G[chatFrame:GetName().."Tab"]
    if tab then
      if gap and gap.index == index then
        if hasPreviousSlot then
          totalWidth = totalWidth + 1
        end
        totalWidth = totalWidth + gap.width
        hasPreviousSlot = true
      end

      if hasPreviousSlot then
        totalWidth = totalWidth + 1
      end

      tab:SetParent(child)
      tab:SetFrameStrata("LOW")
      tab:ClearAllPoints()
      tab:SetPoint("LEFT", child, "LEFT", totalWidth, 0)

      offsets[chatFrame] = totalWidth
      totalWidth = totalWidth + tab:GetWidth()
      hasPreviousSlot = true
    end
  end

  if gap and gap.index == #orderedFrames + 1 then
    if hasPreviousSlot then
      totalWidth = totalWidth + 1
    end
    totalWidth = totalWidth + gap.width
  end

  local dockWidth = self:GetWidth()
  local overflowWidth = self.overflowButton.width or self.overflowButton:GetWidth() or 16
  local hasOverflow = totalWidth > dockWidth
  local availableWidth = dockWidth

  if hasOverflow then
    self.overflowButton:Show()
    availableWidth = math.max(1, dockWidth - overflowWidth - 5)
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self.overflowButton, "BOTTOMLEFT", -5, -5)
  else
    self.overflowButton:Hide()
    self.overflowButton.list:Hide()
    self.scrollFrame:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT", 0, -5)
  end

  child:SetWidth(math.max(1, totalWidth, availableWidth))

  local scrollOffset = self.scrollFrame:GetHorizontalScroll()
  local maximumScroll = math.max(0, totalWidth - availableWidth)
  if keepSelectedVisible ~= false then
    local selectedFrame = FCFDock_GetSelectedWindow(GENERAL_CHAT_DOCK)
    local selectedOffset = offsets[selectedFrame]
    local selectedTab = selectedFrame and _G[selectedFrame:GetName().."Tab"]
    if selectedOffset and selectedTab then
      if selectedOffset < scrollOffset then
        scrollOffset = selectedOffset
      elseif selectedOffset + selectedTab:GetWidth() > scrollOffset + availableWidth then
        scrollOffset = selectedOffset + selectedTab:GetWidth() - availableWidth
      end
    end
  end

  self.scrollFrame:SetHorizontalScroll(math.max(0, math.min(scrollOffset, maximumScroll)))
end

function ChatDockMixin:UpdateTabOrder()
  if self.tabDrag then
    return
  end

  local combatLogTab = _G.ChatFrame2Tab
  if combatLogTab then
    combatLogTab:SetShown(not Core.db.profile.combatLogHidden)
  end
  self:LayoutDockedTabs(self:GetOrderedDockFrames(), true)
  self:UpdateTabVisualStates()
end

function ChatDockMixin:GetDropIndex(cursorX, orderedFrames)
  for index, chatFrame in ipairs(orderedFrames) do
    local tab = _G[chatFrame:GetName().."Tab"]
    local center = tab and tab:GetCenter()
    if center and cursorX < center then
      return index
    end
  end
  return #orderedFrames + 1
end

function ChatDockMixin:AutoScrollTabDrag(cursorX, elapsed)
  local scrollLeft = self.scrollFrame:GetLeft()
  local scrollRight = self.scrollFrame:GetRight()
  if scrollLeft == nil or scrollRight == nil then
    return
  end

  local maximumScroll = math.max(0, self.scrollFrame.child:GetWidth() - self.scrollFrame:GetWidth())
  if maximumScroll == 0 then
    return
  end

  local direction = 0
  if cursorX < scrollLeft + TAB_DRAG_SCROLL_EDGE then
    direction = -1
  elseif cursorX > scrollRight - TAB_DRAG_SCROLL_EDGE then
    direction = 1
  end
  if direction ~= 0 then
    local scroll = self.scrollFrame:GetHorizontalScroll() +
      direction * TAB_DRAG_SCROLL_SPEED * math.min(0.05, elapsed or 0)
    self.scrollFrame:SetHorizontalScroll(math.max(0, math.min(maximumScroll, scroll)))
  end
end

function ChatDockMixin:UpdateTabDrag(elapsed)
  local drag = self.tabDrag
  if drag == nil then
    return
  end

  local cursorX = GetCursorPosition() / UIParent:GetScale()
  self:AutoScrollTabDrag(cursorX, elapsed)
  local dropIndex = self:GetDropIndex(cursorX, drag.remainingFrames)
  if dropIndex ~= drag.dropIndex then
    drag.dropIndex = dropIndex
    self:LayoutDockedTabs(drag.remainingFrames, false, {
      index = dropIndex,
      width = drag.tab:GetWidth(),
    })
  end

  local insertHighlight = self.insertHighlight
  insertHighlight:ClearAllPoints()
  local targetFrame = drag.remainingFrames[drag.dropIndex]
  if targetFrame then
    insertHighlight:SetPoint("CENTER", _G[targetFrame:GetName().."Tab"], "LEFT", 0, 0)
  elseif #drag.remainingFrames > 0 then
    local lastFrame = drag.remainingFrames[#drag.remainingFrames]
    insertHighlight:SetPoint("CENTER", _G[lastFrame:GetName().."Tab"], "RIGHT", 0, 0)
  else
    insertHighlight:SetPoint("CENTER", self, "LEFT", 0, 0)
  end
  insertHighlight:Show()
end

function ChatDockMixin:StartTabDrag(tab, button)
  if self.tabDrag then
    return false
  end

  local orderedFrames = self:GetOrderedDockFrames()
  local draggedFrame
  local remainingFrames = {}
  local draggedIndex
  for index, chatFrame in ipairs(orderedFrames) do
    if _G[chatFrame:GetName().."Tab"] == tab then
      draggedFrame = chatFrame
      draggedIndex = index
    else
      table.insert(remainingFrames, chatFrame)
    end
  end

  local left = tab:GetLeft()
  local bottom = tab:GetBottom()
  if draggedFrame == nil or left == nil or bottom == nil then
    return false
  end

  if Constants.ENV ~= "retail" then
    _G.SELECTED_CHAT_FRAME = draggedFrame
    FCF_SelectDockFrame(draggedFrame)
  end
  self.tabDrag = {
    button = button or "LeftButton",
    dropIndex = draggedIndex,
    draggedFrame = draggedFrame,
    remainingFrames = remainingFrames,
    tab = tab,
  }

  self:LayoutDockedTabs(remainingFrames, false, {
    index = draggedIndex,
    width = tab:GetWidth(),
  })

  tab:SetMovable(true)
  tab:SetParent(UIParent)
  tab:SetFrameStrata("DIALOG")
  tab:ClearAllPoints()
  tab:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left, bottom)
  tab:StartMoving()
  tab:LockHighlight()

  tab:SetScript("OnUpdate", function (_, elapsed)
    local drag = self.tabDrag
    if drag == nil then
      tab:SetScript("OnUpdate", nil)
      return
    end

    if not IsMouseButtonDown(drag.button) then
      self:StopTabDrag(tab)
      return
    end
    self:UpdateTabDrag(elapsed)
  end)
  self:UpdateTabDrag()
  return true
end

function ChatDockMixin:StopTabDrag(tab)
  local drag = self.tabDrag
  if drag == nil or drag.tab ~= tab then
    return
  end

  local cursorX = GetCursorPosition() / UIParent:GetScale()
  drag.dropIndex = self:GetDropIndex(cursorX, drag.remainingFrames)
  local orderedFrames = {}
  for index = 1, #drag.remainingFrames + 1 do
    if index == drag.dropIndex then
      table.insert(orderedFrames, drag.draggedFrame)
    end
    if drag.remainingFrames[index] then
      table.insert(orderedFrames, drag.remainingFrames[index])
    end
  end

  tab:StopMovingOrSizing()
  tab:SetScript("OnUpdate", nil)
  tab:SetMovable(false)
  tab:SetFrameStrata("LOW")
  tab:UnlockHighlight()
  FCFDock_HideInsertHighlight(GENERAL_CHAT_DOCK)

  tab:SetParent(self.scrollFrame.child)
  tab:ClearAllPoints()
  tab:SetPoint("LEFT", self.scrollFrame.child, "LEFT", 0, 0)

  self.tabDrag = nil
  self:SaveTabOrder(orderedFrames)
  self:LayoutDockedTabs(orderedFrames, true)
  self:UpdateTabVisualStates()
end

function ChatDockMixin:Init(parent)
  self.state = {
    mouseOver = false
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

  -- Gradient background
  local backgroundColor = Core.db.profile.headerBackgroundColor
  self:SetGradientBackground(backgroundColor, backgroundColor.a)

  if self.messageSeparator == nil then
    self.messageSeparator = CreateSeparatorFrame(self)
    self.messageSeparator:SetPoint("BOTTOMLEFT")
    self.messageSeparator:SetPoint("BOTTOMRIGHT")
  end
  updateMessageSeparator(self)

  self:QuickHide()

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

        if Core.db.profile.chatShowOnMouseOver then
          -- When chatShowOnMouseOver is on, synchronize the chat tab's fade out with
          -- the chat
          self:HideDelay(Core.db.profile.chatHoldTime)
        else
          -- Otherwise hide it immediately on mouse leave
          self:Hide()
        end
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

        if key == "activeTabHighlightStrength" or key == "tabHoverHighlightStrength" then
          self:UpdateTabVisualStates()
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

local DetachedChatDockMixin = {}

function DetachedChatDockMixin:UpdateFadeSettings()
  self:SetFadeInDuration(Core.db.profile.chatFadeInDuration)
  self:SetFadeOutDuration(Core.db.profile.chatFadeOutDuration)
  self:SetFadeEasing(Core.db.profile.chatFadeEasing)
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
    Core:Subscribe(MOUSE_ENTER, function () self:Show() end),
    Core:Subscribe(MOUSE_LEAVE, function ()
      if Core.db.profile.chatShowOnMouseOver then
        self:HideDelay(Core.db.profile.chatHoldTime)
      else
        self:Hide()
      end
    end),
    Core:Subscribe(UPDATE_CONFIG, function (key)
      if key == "headerBackgroundColor" or key == "tabMessageSeparatorColor" or key == "backgroundFade" then
        self:UpdateStyle()
      elseif key == "chatFadeInDuration" or key == "chatFadeOutDuration" or key == "chatFadeEasing" then
        self:UpdateFadeSettings()
      end
    end),
  }

  self:QuickHide()
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
