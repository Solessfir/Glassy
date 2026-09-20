local Core, Constants, Utils = unpack(select(2, ...))

local AceHook = Core.Libs.AceHook

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local Mixin = Mixin
-- luacheck: pop

local BUTTON_RIGHT_PADDING = 15
local TEXT_ALIGNMENT_OFFSET = 1

local CombatLogBarMixin = {}

local function getPosition()
  local position = Core.db.profile.combatLogBarPosition
  if position == "ABOVE" or position == "HIDDEN" then
    return position
  end
  return "BELOW"
end

local function getLeftTextPadding()
  return math.max(0, tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding)
end

local function isSelectedFilterButton(button)
  local filters = _G.Blizzard_CombatLog_Filters
  local settings = _G.Blizzard_CombatLog_CurrentSettings
  return filters and settings and filters.currentFilter == button:GetID() and not settings.isTemp
end

function CombatLogBarMixin:UpdateButtonHighlightFont(button)
  local font = "GlassyCombatLogHighlightFont"
  if isSelectedFilterButton(button) then
    local activeStrength = tonumber(Core.db.profile.activeTabHighlightStrength) or 0
    local hoverStrength = tonumber(Core.db.profile.hoverHighlightStrength) or 0
    if not button.glassyHovered or activeStrength >= hoverStrength then
      font = "GlassyCombatLogActiveFont"
    end
  end
  button:SetHighlightFontObject(font)
end

function CombatLogBarMixin:IsCombatLogVisible()
  local dock = _G.GENERAL_CHAT_DOCK
  if dock and _G.ChatFrame2.isDocked then
    return dock.selected == _G.ChatFrame2
  end
  return self.slidingMessageFrame:IsShown() or _G.SELECTED_CHAT_FRAME == _G.ChatFrame2
end

function CombatLogBarMixin:UpdateVisibility()
  if Core.db.profile.combatLogHidden or getPosition() == "HIDDEN" or not self:IsCombatLogVisible() then
    self:Hide()
  else
    self:Show()
  end
end

function CombatLogBarMixin:UpdateLayout()
  local position = getPosition()
  local xOffset = Core.db.profile.combatLogBarXOffset
  local yOffset = Core.db.profile.combatLogBarYOffset
  local width = Core.db.profile.frameWidth
  if self.useParentWidth then
    width = self.glassyParent:GetWidth()
  end

  self:SetWidth(width)
  self:SetHeight(Constants.COMBAT_LOG_BAR_HEIGHT)
  self:ClearAllPoints()

  if position == "ABOVE" then
    self:SetPoint("BOTTOMLEFT", self.glassyParent, "TOPLEFT", xOffset, yOffset)
  else
    self:SetPoint("TOPLEFT", self.glassyParent, "TOPLEFT", xOffset, -Constants.DOCK_HEIGHT + yOffset)
  end

  self:UpdateBackground()
  self:UpdateVisibility()
end

function CombatLogBarMixin:SetGlassyParent(parent, useParentWidth, fadeParent)
  self.glassyParent = parent
  self.useParentWidth = useParentWidth
  self:SetParent(fadeParent or parent)
  self:UpdateLayout()
end

function CombatLogBarMixin:UpdateBackground()
  local color = Core.db.profile.headerBackgroundColor
  self:SetGradientBackground(color, color.a)
end

function CombatLogBarMixin:StyleButtons()
  local previousButton
  local buttonIndex = 1

  while true do
    local button = _G["CombatLogQuickButtonFrameButton"..buttonIndex]
    if button == nil then
      break
    end

    button:SetNormalFontObject("GlassyCombatLogNormalFont")
    self:UpdateButtonHighlightFont(button)

    if not button.glassyHoverHooked then
      button.glassyHoverHooked = true
      button:HookScript("OnEnter", function ()
        button.glassyHovered = true
        self:UpdateButtonHighlightFont(button)
      end)
      button:HookScript("OnLeave", function ()
        button.glassyHovered = false
        self:UpdateButtonHighlightFont(button)
      end)
    end

    local text = button:GetFontString()
    if text then
      text:ClearAllPoints()
      text:SetPoint("LEFT", button, "LEFT")
      text:SetJustifyH("LEFT")
      button:SetWidth(text:GetStringWidth() + BUTTON_RIGHT_PADDING)
    end

    if button:IsShown() then
      button:ClearAllPoints()
      if previousButton then
        button:SetPoint("LEFT", previousButton, "RIGHT")
      else
        button:SetPoint("LEFT", self, "LEFT", getLeftTextPadding() + TEXT_ALIGNMENT_OFFSET, 0)
      end
      previousButton = button
    end

    buttonIndex = buttonIndex + 1
  end
end

function CombatLogBarMixin:StyleControls()
  local texture = _G.CombatLogQuickButtonFrame_CustomTexture
  if texture then
    texture:SetTexture(nil)
    texture:Hide()
  end

  local progressBar = _G.CombatLogQuickButtonFrame_CustomProgressBar
  if progressBar then
    progressBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    progressBar:SetStatusBarColor(Constants.COLORS.apache.r, Constants.COLORS.apache.g, Constants.COLORS.apache.b)
    progressBar:ClearAllPoints()
    progressBar:SetPoint("BOTTOMLEFT", self, "BOTTOMLEFT")
    progressBar:SetPoint("BOTTOMRIGHT", self, "BOTTOMRIGHT")
    progressBar:SetHeight(2)
  end

  local filterButton = _G.CombatLogQuickButtonFrame_CustomAdditionalFilterButton
  if filterButton then
    filterButton:SetSize(Constants.COMBAT_LOG_BAR_HEIGHT, Constants.COMBAT_LOG_BAR_HEIGHT)
    filterButton:ClearAllPoints()
    filterButton:SetPoint("TOPRIGHT", self, "TOPRIGHT")
    filterButton:SetHitRectInsets(0, 0, 0, 0)

    for _, buttonTexture in ipairs({
      filterButton:GetNormalTexture(),
      filterButton:GetPushedTexture(),
      filterButton:GetDisabledTexture(),
      filterButton:GetHighlightTexture(),
    }) do
      if buttonTexture then
        buttonTexture:SetTexture(nil)
      end
    end

    if filterButton.glassyText == nil then
      filterButton.glassyText = filterButton:CreateFontString(nil, "OVERLAY", "GlassyCombatLogHighlightFont")
      filterButton.glassyText:SetPoint("CENTER", 0, 2)
      filterButton.glassyText:SetText("...")
      filterButton.glassyText:SetTextColor(
        Constants.COLORS.apache.r,
        Constants.COLORS.apache.g,
        Constants.COLORS.apache.b
      )
    end
  end
end

function CombatLogBarMixin:RefreshButtons()
  if Constants.ENV ~= "retail" and type(_G.Blizzard_CombatLog_Update_QuickButtons) == "function" then
    _G.Blizzard_CombatLog_Update_QuickButtons()
  else
    self:StyleButtons()
  end
end

function CombatLogBarMixin:Init(parent, slidingMessageFrame)
  self.glassyParent = parent
  self.useParentWidth = false
  self.slidingMessageFrame = slidingMessageFrame
  self:SetParent(_G.GENERAL_CHAT_DOCK or _G.GeneralDockManager or parent)
  self:SetIgnoreParentAlpha(false)
  self:SetFrameStrata("MEDIUM")

  if not self.glassyHooks:IsHooked(self, "Show") then
    Utils.hookPresentation(self.glassyHooks, self, "Show", function (frame)
      if Core.db.profile.combatLogHidden or getPosition() == "HIDDEN" or not self:IsCombatLogVisible() then
        frame:Hide()
      else
        self.glassyHooks.hooks[frame].Show(frame)
        self:StyleButtons()
      end
    end, true)
  end

  if not self.glassyHooks:IsHooked(slidingMessageFrame, "OnShow") then
    self.glassyHooks:HookScript(slidingMessageFrame, "OnShow", function ()
      self:UpdateVisibility()
    end)
  end

  if not self.glassyHooks:IsHooked(slidingMessageFrame, "OnHide") then
    self.glassyHooks:HookScript(slidingMessageFrame, "OnHide", function ()
      self:UpdateVisibility()
    end)
  end

  if (
    type(_G.Blizzard_CombatLog_Update_QuickButtons) == "function" and
    not self.glassyHooks:IsHooked("Blizzard_CombatLog_Update_QuickButtons")
  ) then
    self.glassyHooks:SecureHook("Blizzard_CombatLog_Update_QuickButtons", function ()
      self:StyleButtons()
    end)
  end

  if type(_G.FCFDock_SelectWindow) == "function" and not self.glassyHooks:IsHooked("FCFDock_SelectWindow") then
    self.glassyHooks:SecureHook("FCFDock_SelectWindow", function (dock)
      if dock == _G.GENERAL_CHAT_DOCK then
        self:UpdateVisibility()
        if self:IsCombatLogVisible() then
          self:RefreshButtons()
        end
      end
    end)
  end

  self:StyleControls()
  self:UpdateLayout()
  self:RefreshButtons()

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if key == "combatLogVisibility" then
          self:UpdateVisibility()
        end

        if key == "combatLogBarLayout" or key == "frameWidth" then
          self:UpdateLayout()
          self:RefreshButtons()
        end

        if key == "font" or key == "textLeftPadding" then
          self:RefreshButtons()
        end

        if key == "activeTabHighlightStrength" or key == "hoverHighlightStrength" then
          self:RefreshButtons()
        end

        if key == "headerBackgroundColor" or key == "backgroundFade" then
          self:UpdateBackground()
        end
      end)
    }
  end
end

local isCreated = false

Core.Components.CreateCombatLogBar = function (parent, slidingMessageFrame)
  local frame = _G.CombatLogQuickButtonFrame_Custom
  if frame == nil or isCreated then
    return nil
  end

  local GradientBackgroundMixin = Core.Components.GradientBackgroundMixin
  local object = Mixin(frame, GradientBackgroundMixin, CombatLogBarMixin)
  object.glassyHooks = object.glassyHooks or AceHook:Embed({})
  GradientBackgroundMixin.Init(object)
  CombatLogBarMixin.Init(object, parent, slidingMessageFrame)
  isCreated = true
  return object
end
