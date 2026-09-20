local Core, Constants = unpack(select(2, ...))
local ChatDockMixin = Core.Components.ChatDockMixin

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local FCFDock_GetSelectedWindow = FCFDock_GetSelectedWindow
local FCFDock_HideInsertHighlight = FCFDock_HideInsertHighlight
local FCFDockOverflowListButton_SetValue = FCFDockOverflowListButton_SetValue
local FCF_SelectDockFrame = FCF_SelectDockFrame
local CHAT_WINDOWS_COUNT = CHAT_WINDOWS_COUNT
local GENERAL_CHAT_DOCK = GENERAL_CHAT_DOCK
local GetCursorPosition = GetCursorPosition
local IsMouseButtonDown = IsMouseButtonDown
local UIParent = UIParent
-- luacheck: pop

local TAB_DRAG_SCROLL_EDGE = 32
local TAB_DRAG_SCROLL_SPEED = 300

local function setTextColor(text, highlighted)
  local color = Core.db.profile[highlighted and "tabHighlightTextColor" or "tabTextColor"] or Constants.COLORS.apache
  text:SetTextColor(color.r, color.g, color.b, 1)
  text:SetAlpha(color.a or 1)
end

local function isSelected(chatFrame)
  return chatFrame and chatFrame.isDocked and GENERAL_CHAT_DOCK.selected == chatFrame
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
        setTextColor(fontString, button.glassyHovered or isSelected(button.chatFrame))
        if not button.glassyHoverHooked then
          button.glassyHoverHooked = true
          button:HookScript("OnEnter", function ()
            button.glassyHovered = true
            setTextColor(button:GetFontString(), true)
          end)
          button:HookScript("OnLeave", function ()
            button.glassyHovered = false
            self:StyleOverflowList()
          end)
        end
      end
    end
    if button.highlight then
      button.highlight:SetTexture(nil)
    end
  end
end

function ChatDockMixin:UpdateOverflowButtonHighlight()
  local highlightTexture = self.overflowButton:GetHighlightTexture()
  if highlightTexture then
    highlightTexture:SetTexture(nil)
  end
  if self.overflowButton.glassyText then
    setTextColor(self.overflowButton.glassyText, self.overflowButton.glassyHovered)
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
    self:UpdateOverflowButtonHighlight()
  end

  if button.glassyText == nil then
    button.glassyText = button:CreateFontString(nil, "OVERLAY", "GlassyChatDockFont")
    button.glassyText:SetPoint("CENTER", 0, 2)
    button.glassyText:SetText("...")
  end
  setTextColor(button.glassyText, button.glassyHovered)

  button:HookScript("OnEnter", function ()
    button.glassyHovered = true
    setTextColor(button.glassyText, true)
  end)
  button:HookScript("OnLeave", function ()
    button.glassyHovered = false
    setTextColor(button.glassyText, false)
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
