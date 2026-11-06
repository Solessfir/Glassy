local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local UnlockMover = Constants.ACTIONS.UnlockMover
local L = function(text) return Core:Localize(text) end

local Colors = Constants.COLORS

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CHAT_CHANNELS = CHAT_CHANNELS
local CHAT_CONFIGURATION = CHAT_CONFIGURATION
local CLOSE_CHAT_WINDOW = CLOSE_CHAT_WINDOW
local ChatConfigFrame = ChatConfigFrame
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
local DISPLAY = DISPLAY
local FCF_GetNumActiveChatFrames = FCF_GetNumActiveChatFrames
local FCF_MinimizeFrame = FCF_MinimizeFrame
local FCF_NewChatWindow = FCF_NewChatWindow
local FCF_PopInWindow = FCF_PopInWindow
local FCF_RenameChatWindow_Popup = FCF_RenameChatWindow_Popup
local FCF_StopAlertFlash = FCF_StopAlertFlash
local FILTERS = FILTERS
local GameTooltip = GameTooltip
local IsCombatLog = IsCombatLog
local IsShiftKeyDown = IsShiftKeyDown
local Menu = Menu
local MenuUtil = MenuUtil
local MINIMIZE = MINIMIZE or "Minimize Window"
local Mixin = Mixin
local NEW_CHAT_WINDOW = NEW_CHAT_WINDOW
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local RENAME_CHAT_WINDOW = RENAME_CHAT_WINDOW
local ShowUIPanel = ShowUIPanel
local ToggleChannelFrame = ToggleChannelFrame
local UIDropDownMenu_AddButton = UIDropDownMenu_AddButton
local UIDropDownMenu_CreateInfo = UIDropDownMenu_CreateInfo
local UIDropDownMenu_Initialize = UIDropDownMenu_Initialize
local UNLOCK_WINDOW = UNLOCK_WINDOW
-- luacheck: pop

local tabTexs = {
  '',
  'Selected',
  'Highlight'
}

local retailTabTexs = {"Left", "Middle", "Right", "ActiveLeft", "ActiveMiddle", "ActiveRight", "HighlightLeft", "HighlightMiddle", "HighlightRight"}

---@class GlassyChatTab: Button
---@field Text FontString
---@field glow Texture
---@field glassyHooks AceHook-3.0
local ChatTabMixin = {}

if Menu and Menu.ModifyMenu and MenuUtil and ToggleChannelFrame then
  Menu.ModifyMenu("MENU_FCF_TAB", function (owner, rootDescription)
    if owner and owner.slidingMessageFrame then
      local function insertBefore(text, button)
        local insertionIndex
        for index, description in rootDescription:EnumerateElementDescriptions() do
          if MenuUtil.GetElementText(description) == text then
            insertionIndex = index
            break
          end
        end
        rootDescription:Insert(button, insertionIndex)
      end

      local chatFrameName = owner:GetName():gsub("Tab$", "")
      local chatFrame = _G[chatFrameName]
      if chatFrame and not chatFrame.isDocked and FCF_MinimizeFrame then
        insertBefore(DISPLAY, MenuUtil.CreateButton(MINIMIZE, function ()
          FCF_MinimizeFrame(chatFrame, string.upper(chatFrame.buttonSide or "right"))
        end))
      end

      insertBefore(CHAT_CONFIGURATION, MenuUtil.CreateButton(CHAT_CHANNELS, function ()
        ToggleChannelFrame()
      end))

      if chatFrame and chatFrame ~= _G.ChatFrame2 then
        insertBefore(CHAT_CONFIGURATION, MenuUtil.CreateButton(L("Search messages"), function ()
          Core:GetModule("ChatCopy"):ShowSearch(chatFrame)
        end))
      end
    end
  end)
end

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

local UNREAD_COUNT_GAP = 4

function ChatTabMixin:GetLayoutWidth()
  local width = self:GetTextWidth() + getLeftTextPadding() + Constants.TEXT_RIGHT_PADDING
  if self.unreadText and self.unreadText:IsShown() then
    width = width + UNREAD_COUNT_GAP + self.unreadText:GetStringWidth()
  end
  return width
end

function ChatTabMixin:UpdateTextLayout()
  local leftPadding = getLeftTextPadding()
  self.Text:ClearAllPoints()
  self.Text:SetPoint("LEFT", leftPadding, 0)
  self:SetWidth(self:GetLayoutWidth())
end

-- Counts messages that arrive while a docked tab is not selected; selecting it clears the count.
function ChatTabMixin:AddUnreadMessage()
  if not Core.db.profile.tabUnreadCount or not self.chatFrame.isDocked or self:IsSelected() then return end
  self:SetUnreadCount((self.glassyUnreadCount or 0) + 1)
end

function ChatTabMixin:SetUnreadCount(count)
  self.glassyUnreadCount = count
  local shown = count > 0 and Core.db.profile.tabUnreadCount
  if not shown and not self.unreadText then return end
  if not self.unreadText then
    self.unreadText = self:CreateFontString(nil, "OVERLAY", "GlassyChatDockFont")
    self.unreadText:SetPoint("LEFT", self.Text, "RIGHT", UNREAD_COUNT_GAP, 0)
  end
  local color = Core.db.profile.tabHighlightTextColor or Colors.apache
  self.unreadText:SetTextColor(color.r, color.g, color.b, color.a or 1)
  self.unreadText:SetText(shown and (count > 99 and "99+" or tostring(count)) or "")
  self.unreadText:SetShown(shown)

  -- Only re-lay out the dock when the tab actually grows or shrinks.
  local width = self:GetLayoutWidth()
  if width ~= self.glassyLayoutWidth then
    self.glassyLayoutWidth = width
    self:UpdateTextLayout()
    if self.glassyDock then self.glassyDock:UpdateTabOrder() end
  end
end

function ChatTabMixin:IsSelected()
  local dock = _G.GENERAL_CHAT_DOCK
  if dock and self.chatFrame.isDocked then
    return dock.selected == self.chatFrame
  end
  return _G.SELECTED_CHAT_FRAME == self.chatFrame
end

function ChatTabMixin:UpdateVisualState()
  if self.chatFrame.isTemporary or self.glassyHooks.hooks[self.Text] == nil then
    return
  end

  local color = Core.db.profile.tabTextColor or Colors.apache
  if self:IsSelected() then
    color = Core.db.profile.tabHighlightTextColor or Colors.apache
    if (self.glassyUnreadCount or 0) > 0 then self:SetUnreadCount(0) end
  end
  if self.glassyHovered then
    color = Core.db.profile.tabHighlightTextColor or Colors.apache
  end

  self.glassyHooks.hooks[self.Text].SetTextColor(
    self.Text,
    color.r,
    color.g,
    color.b,
    1
  )
  self.Text:SetAlpha(color.a or 1)
end

function ChatTabMixin:ClearBackgroundTextures()
  for _, texName in ipairs(tabTexs) do
    for _, side in ipairs({"Left", "Middle", "Right"}) do
      local texture = _G[self:GetName()..texName..side]
      if texture then texture:SetTexture(nil) end
    end
  end
  for _, key in ipairs(retailTabTexs) do
    local texture = self[key]
    if texture then texture:SetTexture(nil) end
  end
end

function ChatTabMixin:Init(slidingMessageFrame, dock)
  self.slidingMessageFrame = slidingMessageFrame
  self.chatFrame = slidingMessageFrame.chatFrame
  self.glassyDock = dock
  local dropDown = _G[self.chatFrame:GetName().."TabDropDown"]

  self:ClearBackgroundTextures()

  self:SetHeight(Constants.DOCK_HEIGHT)
  self:SetNormalFontObject("GlassyChatDockFont")
  self:UpdateTextLayout()

  if not self.glassyHooks:IsHooked(self, "SetAlpha") then
    Utils.hookPresentation(self.glassyHooks, self, "SetAlpha", function (alpha)
      self.glassyHooks.hooks[self].SetAlpha(self, 1)
    end, true)
  end
  self:SetAlpha(1)

  if self.chatFrame == _G.ChatFrame2 and not self.glassyHooks:IsHooked(self, "Show") then
    Utils.hookPresentation(self.glassyHooks, self, "Show", function (tab)
      if Core.db.profile.combatLogHidden then
        tab:Hide()
      else
        self.glassyHooks.hooks[self].Show(tab)
      end
    end, true)
  end

  -- Set width dynamically based on text width
  if not self.glassyHooks:IsHooked(self, "SetWidth") then
    Utils.hookPresentation(self.glassyHooks, self, "SetWidth", function ()
      self.glassyHooks.hooks[self].SetWidth(self, self:GetLayoutWidth())
    end, true)
  end

  if not self.glassyHooks:IsHooked(self.Text, "SetTextColor") then
    Utils.hookPresentation(self.glassyHooks, self.Text, "SetTextColor", function (...)
      -- Temporary chat frames retain their color
      if self.chatFrame.isTemporary then
        self.glassyHooks.hooks[self.Text].SetTextColor(...)
      else
        self:UpdateVisualState()
      end
    end, true)
  end
  self:UpdateVisualState()

  if not self.glassyOnEnterInstalled then
    self.glassyOnEnterInstalled = true
    self:SetScript("OnEnter", function ()
      self.glassyHovered = true
      self:UpdateVisualState()
      if Core.db.profile.chatTabTooltips then
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText(self.Text:GetText() or self.chatFrame:GetName(), 1, 1, 1)
        GameTooltip:AddLine(L("Click to select"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Drag to reorder"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Shift-click to copy"), 0.8, 0.8, 0.8)
        GameTooltip:AddLine(L("Right-click for chat options"), 0.8, 0.8, 0.8)
        GameTooltip:Show()
      end
    end)
  end
  if not self.glassyHooks:IsHooked(self, "OnLeave") then
    self.glassyHooks:SecureHookScript(self, "OnLeave", function ()
      self.glassyHovered = false
      self:UpdateVisualState()
      if GameTooltip:IsOwned(self) then
        GameTooltip:Hide()
      end
    end)
  end

  -- Don't highlight when frame is already visible
  if not self.glassyHooks:IsHooked(self.glow, "Show") then
    Utils.hookPresentation(self.glassyHooks, self.glow, "Show", function ()
      if not self.slidingMessageFrame:IsVisible() then
        self.glassyHooks.hooks[self.glow].Show(self.glow)
      elseif Constants.ENV == "retail" then
        self.glow:Hide()
      end
    end, true)
  end

  -- Let Blizzard select the tab in secure code before running Glassy's click actions.
  if not self.glassyHooks:IsHooked(self, "OnClick") then
    self.glassyHooks:SecureHookScript(self, "OnClick", function (_, button)
      FCF_StopAlertFlash(self.chatFrame)

      if button == "LeftButton" then
        dock:SaveSelectedTab(self.chatFrame)
      end

      if button == "LeftButton" and IsShiftKeyDown() then
        Core:GetModule("ChatCopy"):Show(self.chatFrame)
      end
    end)
  end

  local originalOnDragStart = self:GetScript("OnDragStart")
  self:RegisterForDrag("LeftButton")
  self:SetScript("OnDragStart", function (tab, button)
    if GameTooltip:IsOwned(tab) then
      GameTooltip:Hide()
    end
    if not dock:StartTabDrag(tab, button) and originalOnDragStart then
      originalOnDragStart(tab, button)
    end
  end)
  self:SetScript("OnDragStop", function (tab)
    dock:StopTabDrag(tab)
  end)

  -- Override context menu
  -- UIDropDownMenu_Initialize(dropDown, function ()
  --   local info = UIDropDownMenu_CreateInfo()

  --   if self.chatFrame == DEFAULT_CHAT_FRAME then
  --     -- Unlock chat window
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = UNLOCK_WINDOW
  --     info.notCheckable = 1
  --     info.func = function()
  --       Core:Dispatch(UnlockMover())
  --     end
  --     UIDropDownMenu_AddButton(info)

  --     -- Create new chat window
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = NEW_CHAT_WINDOW
  --     info.func = FCF_NewChatWindow
  --     info.notCheckable = 1
  --     if FCF_GetNumActiveChatFrames() == NUM_CHAT_WINDOWS then
  --       info.disabled = 1
  --     end
  --     UIDropDownMenu_AddButton(info)
  --   end

  --   -- Rename window
  --   info.text = RENAME_CHAT_WINDOW
  --   info.func = FCF_RenameChatWindow_Popup
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)

  --   -- Close chat window
  --   if self.chatFrame ~= DEFAULT_CHAT_FRAME and not IsCombatLog(self.chatFrame) then
  --     info = UIDropDownMenu_CreateInfo()
  --     info.text = CLOSE_CHAT_WINDOW
  --     info.func = FCF_PopInWindow
  --     info.arg1 = self.chatFrame
  --     info.notCheckable = 1
  --     UIDropDownMenu_AddButton(info)
  --   end

  --   -- Filter header
  --   info = UIDropDownMenu_CreateInfo()
  --   info.text = FILTERS
  --   info.isTitle = 1
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)

  --   -- Configure settings
  --   info = UIDropDownMenu_CreateInfo()
  --   info.text = CHAT_CONFIGURATION
  --   info.func = function() ShowUIPanel(ChatConfigFrame) end
  --   info.notCheckable = 1
  --   UIDropDownMenu_AddButton(info)
  -- end, "MENU")

  -- Listeners
  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if (
          key == "frameWidth" or
          key == "frameHeight" or
          key == "font" or
          key == "tabFontSize" or
          key == "textLeftPadding"
        ) then
          self:UpdateTextLayout()
          dock:UpdateTabOrder()
        end

        if key == "tabTextColor" or key == "tabHighlightTextColor" then
          self:UpdateVisualState()
        end

        if key == "tabUnreadCount" or key == "tabHighlightTextColor" then
          self:SetUnreadCount(Core.db.profile.tabUnreadCount and self.glassyUnreadCount or 0)
        end

        if key == "chatTabTooltips" and not Core.db.profile.chatTabTooltips and GameTooltip:IsOwned(self) then
          GameTooltip:Hide()
        end
      end)
    }
  end

  dock:UpdateTabOrder()
end

Core.Components.CreateChatTab = function (slidingMessageFrame, dock)
  local frame = _G[slidingMessageFrame.chatFrame:GetName().."Tab"]
  local object = Mixin(frame, ChatTabMixin)
  object.glassyHooks = object.glassyHooks or AceHook:Embed({})
  object:Init(slidingMessageFrame, dock)
  return object
end
