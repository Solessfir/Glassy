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
    end
  end)
end

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

function ChatTabMixin:UpdateTextLayout()
  local leftPadding = getLeftTextPadding()
  self.Text:ClearAllPoints()
  self.Text:SetPoint("LEFT", leftPadding, 0)
  self:SetWidth(self:GetTextWidth() + leftPadding + Constants.TEXT_RIGHT_PADDING)
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

  local brightness = 1
  if self:IsSelected() then
    brightness = 1 + math.max(0, math.min(1, tonumber(Core.db.profile.activeTabHighlightStrength) or 0))
  end
  if self.glassyHovered then
    local hoverStrength = math.max(0, math.min(1, tonumber(Core.db.profile.hoverHighlightStrength) or 0))
    brightness = math.max(brightness, 1 + hoverStrength)
  end

  self.glassyHooks.hooks[self.Text].SetTextColor(
    self.Text,
    math.min(1, Colors.apache.r * brightness),
    math.min(1, Colors.apache.g * brightness),
    math.min(1, Colors.apache.b * brightness)
  )
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
    Utils.hookPresentation(self.glassyHooks, self, "SetWidth", function (_, width)
      self.glassyHooks.hooks[self].SetWidth(
        self,
        self:GetTextWidth() + getLeftTextPadding() + Constants.TEXT_RIGHT_PADDING
      )
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
          key == "messageFontSize" or
          key == "textLeftPadding"
        ) then
          self:UpdateTextLayout()
          dock:UpdateTabOrder()
        end

        if key == "activeTabHighlightStrength" or key == "hoverHighlightStrength" then
          self:UpdateVisualState()
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
