local Core, Constants = unpack(select(2, ...))

local SaveFramePosition = Constants.ACTIONS.SaveFramePosition

local LOCK_MOVER = Constants.EVENTS.LOCK_MOVER
local UNLOCK_MOVER = Constants.EVENTS.UNLOCK_MOVER
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

---@class GlassyMoverFrame: Frame
local MoverFrameMixin = {}

local EDIT_MODE_BLUE_R = 0.22
local EDIT_MODE_BLUE_G = 0.62
local EDIT_MODE_BLUE_B = 0.78
local EDIT_MODE_FILL_ALPHA = 0.35
local EDIT_MODE_HOVER_ALPHA = 0.5
local EDIT_MODE_BORDER_ALPHA = 1
local EDIT_MODE_BORDER_SIZE = 2
local LEGACY_EDIT_BOX_MARGIN = 35
local EDGE_SNAP_DISTANCE = 20

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local C_Timer = C_Timer
local GetCursorPosition = GetCursorPosition
local Mixin = Mixin
-- luacheck: pop

function MoverFrameMixin:AddBoundsRegion(region, shouldInclude)
  if region then
    table.insert(self.boundsRegions, {
      frame = region,
      shouldInclude = shouldInclude
    })
    self:ScheduleBoundsUpdate()
  end
end

function MoverFrameMixin:SetDragPosition(left, bottom)
  local parent = self:GetParent()
  local parentLeft, parentRight = parent and parent:GetLeft(), parent and parent:GetRight()
  local parentBottom, parentTop = parent and parent:GetBottom(), parent and parent:GetTop()
  local width, height = self:GetWidth(), self:GetHeight()
  if not (parentLeft and parentRight and parentBottom and parentTop and width and height) then
    return
  end

  local right = left + width
  local top = bottom + height
  local leftDistance = math.abs(left - parentLeft)
  local rightDistance = math.abs(right - parentRight)
  local bottomDistance = math.abs(bottom - parentBottom)
  local topDistance = math.abs(top - parentTop)

  if leftDistance <= EDGE_SNAP_DISTANCE and leftDistance <= rightDistance then
    left = parentLeft
  elseif rightDistance <= EDGE_SNAP_DISTANCE then
    left = parentRight - width
  end

  if bottomDistance <= EDGE_SNAP_DISTANCE and bottomDistance <= topDistance then
    bottom = parentBottom
  elseif topDistance <= EDGE_SNAP_DISTANCE then
    bottom = parentTop - height
  end

  local centerX, centerY = left + width / 2, bottom + height / 2
  local parentCenterX, parentCenterY = parent:GetCenter()
  local horizontal = centerX <= parentCenterX and "LEFT" or "RIGHT"
  local vertical = centerY <= parentCenterY and "BOTTOM" or "TOP"
  local point = vertical..horizontal
  local xOfs = horizontal == "LEFT" and left - parentLeft or left + width - parentRight
  local yOfs = vertical == "BOTTOM" and bottom - parentBottom or bottom + height - parentTop

  self:ClearAllPoints()
  self:SetPoint(point, parent, point, xOfs, yOfs)
  if self.editModePanel and self.editModePanel.frame:IsShown() then self:PositionEditModeSettings() end
end

function MoverFrameMixin:UpdateDragPosition()
  if self.dragOffsetX == nil or self.dragOffsetY == nil then
    return
  end

  local parent = self:GetParent()
  local scale = parent and parent:GetEffectiveScale()
  if scale == nil or scale == 0 then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  self:SetDragPosition(cursorX / scale - self.dragOffsetX, cursorY / scale - self.dragOffsetY)
end

function MoverFrameMixin:StartDragging()
  local parent = self:GetParent()
  local scale = parent and parent:GetEffectiveScale()
  local left, bottom = self:GetLeft(), self:GetBottom()
  if scale == nil or scale == 0 or left == nil or bottom == nil then
    return
  end

  local cursorX, cursorY = GetCursorPosition()
  self.dragOffsetX = cursorX / scale - left
  self.dragOffsetY = cursorY / scale - bottom
  self.boundsFrame:SetScript("OnUpdate", function ()
    self:UpdateDragPosition()
  end)
end

function MoverFrameMixin:StopDragging()
  self:UpdateDragPosition()
  self.boundsFrame:SetScript("OnUpdate", nil)
  self.dragOffsetX = nil
  self.dragOffsetY = nil
end

function MoverFrameMixin:SavePosition()
  local point, _, _, xOfs, yOfs = self:GetPoint(1)
  if point then Core:Dispatch(SaveFramePosition({point = point, xOfs = xOfs, yOfs = yOfs})) end
end

function MoverFrameMixin:UpdateMoverVisibility()
  local shown = self.manuallyUnlocked or self.blizzardEditing or false
  if self.blizzardEditing and not self.originalMoverStrata then
    self.originalMoverStrata = self.boundsFrame:GetFrameStrata()
    self.originalSettingsStrata = self.editModeSettings:GetFrameStrata()
    -- Blizzard's chat selection uses MEDIUM at level 1000 and intercepts the drag target.
    self.boundsFrame:SetFrameStrata("HIGH")
    self.editModeSettings:SetFrameStrata("HIGH")
  elseif not self.blizzardEditing and self.originalMoverStrata then
    self.boundsFrame:SetFrameStrata(self.originalMoverStrata)
    self.editModeSettings:SetFrameStrata(self.originalSettingsStrata)
    self.originalMoverStrata = nil
    self.originalSettingsStrata = nil
  end
  self:SetShown(shown)
  self:EnableMouse(shown)
  self:SetMovable(shown)
  if self.editModeSettings then self.editModeSettings:SetShown(self.blizzardEditing) end
  if self.editModePanel and not self.blizzardEditing then self.editModePanel.frame:Hide() end
  if shown then self:ScheduleBoundsUpdate() end
end

function MoverFrameMixin:OpenEditModeSettings()
  local config, libs = Core:GetModule("Config"), Core.Libs
  if not (libs.AceGUI and libs.AceConfig and libs.AceConfigDialog and config.Pages) then
    config:OpenSettings()
    return
  end
  if self.editModePanel and self.editModePanel.frame:IsShown() then
    self.editModePanel.frame:Hide()
    return
  end
  if not self.editModePanel then
    local general = config.Pages.general().args
    local messages = config.Pages.messages().args
    local editBox = config.Pages.editBox().args.section1.args
    local options = {name = "Glassy", type = "group", args = {}}
    local controls = {
      general.section3.args.frameWidth, general.section3.args.frameHeight,
      messages.section1.args.messageFont, messages.section1.args.messageFontSize, editBox.editBoxFontSize,
      messages.section1.args.chatBackgroundColor, messages.section2.args.chatAlwaysVisible,
      messages.section2.args.chatHoldTime, messages.animation.args.fadeInDuration,
      messages.animation.args.fadeOutDuration, messages.animation.args.slideInDuration,
    }
    for index, control in ipairs(controls) do
      local option = {}
      for key, value in pairs(control) do option[key] = value end
      option.order, option.width = index, "full"
      if index == 4 then option.name = "Message font size" end
      if index == 5 then option.name = "Edit box font size" end
      local set = option.set
      option.set = function (info, value, ...)
        set(info, value, ...)
        libs.AceConfigRegistry:NotifyChange("Glassy")
      end
      options.args["setting"..index] = option
    end
    options.args.resetPosition = {
      name = "Reset position", type = "execute", order = 20,
      func = function ()
        local anchor = Core.defaults.profile.positionAnchor
        Core:Dispatch(SaveFramePosition({point = anchor.point, xOfs = anchor.xOfs, yOfs = anchor.yOfs}))
        Core:Dispatch(Constants.ACTIONS.UpdateConfig("framePosition"))
        libs.AceConfigRegistry:NotifyChange("Glassy")
      end,
    }
    Core:LocalizeOptions(options)
    libs.AceConfig:RegisterOptionsTable("GlassyEditMode", options)
    -- AceConfigDialog adds scrolling for Frame containers, but not InlineGroup containers.
    local panel = libs.AceGUI:Create("Frame")
    panel:SetTitle("Glassy")
    panel:SetLayout("Fill")
    panel:SetWidth(350)
    panel:SetHeight(math.min(570, _G.UIParent:GetHeight() - 40))
    panel:EnableResize(false)
    panel.frame:SetParent(self.boundsFrame)
    panel.frame:SetFrameStrata("DIALOG")
    panel.frame:SetClampedToScreen(true)
    self.editModePanel = panel
  end
  self.editModePanel.frame:Show()
  self:RefreshEditModeSettings()
end

function MoverFrameMixin:RefreshEditModeSettings()
  local dialog = Core.Libs.AceConfigDialog
  dialog:SetDefaultSize("GlassyEditMode", math.min(350, _G.UIParent:GetWidth() - 20), math.min(570, _G.UIParent:GetHeight() - 40))
  dialog:Open("GlassyEditMode", self.editModePanel)
  self:PositionEditModeSettings()
end

function MoverFrameMixin:PositionEditModeSettings()
  local panel = self.editModePanel
  if not panel then return end
  local parent = _G.UIParent
  local scale = self.boundsFrame:GetEffectiveScale() / parent:GetEffectiveScale()
  local right, left, top = self.boundsFrame:GetRight(), self.boundsFrame:GetLeft(), self.boundsFrame:GetTop()
  if not (right and left and top) then return end
  local width, height = panel.frame:GetWidth(), panel.frame:GetHeight()
  local screenWidth, screenHeight = parent:GetWidth(), parent:GetHeight()
  local x = right * scale + 8
  if x + width > screenWidth - 10 then x = left * scale - width - 8 end
  x = math.max(10, math.min(x, screenWidth - width - 10))
  top = math.max(height + 10, math.min(top * scale, screenHeight - 10))
  panel.frame:ClearAllPoints()
  panel.frame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", x, top)
end

function MoverFrameMixin:ConnectBlizzardEditMode()
  local editMode = _G.EditModeManagerFrame
  if not editMode then return end

  local settings = CreateFrame("Button", nil, self.boundsFrame, "UIPanelButtonTemplate")
  settings:SetPoint("TOPRIGHT", -5, -5)
  settings:SetSize(140, 24)
  settings:SetText(Core:Localize("Glassy settings"))
  settings:SetScript("OnClick", function () self:OpenEditModeSettings() end)
  self.editModeSettings = settings

  local label = settings:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  label:SetPoint("TOPLEFT", self.boundsFrame, "TOPLEFT", 8, -8)
  label:SetText("Glassy")

  local function update()
    local editing = editMode:IsShown() and Core.db.profile.blizzardEditMode ~= false
    if self.blizzardEditing and not editing and self.dragOffsetX then
      self:StopDragging()
      self:SavePosition()
    end
    self.blizzardEditing = editing
    self:UpdateMoverVisibility()
  end
  editMode:HookScript("OnShow", update)
  editMode:HookScript("OnHide", update)
  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "blizzardEditMode" then update() end
    if self.editModePanel and self.editModePanel.frame:IsShown() and not self.settingsRefreshScheduled then
      self.settingsRefreshScheduled = true
      C_Timer.After(0, function ()
        self.settingsRefreshScheduled = false
        if self.editModePanel.frame:IsShown() then
          self:RefreshEditModeSettings()
        end
      end)
    end
  end)
  update()
end

function MoverFrameMixin:ScheduleBoundsUpdate()
  if self.boundsUpdateScheduled then
    return
  end

  self.boundsUpdateScheduled = true
  C_Timer.After(0, function ()
    self.boundsUpdateScheduled = false
    self:UpdateBounds()
  end)
end

function MoverFrameMixin:UpdateLayoutBounds()
  if self.layoutContainer == nil or self.layoutEditBox == nil then
    return
  end

  local editBoxHeight = self.layoutEditBox:GetHeight() or 0
  local editBoxOffset = tonumber(Core.db.profile.editBoxAnchor.yOfs) or 0
  local editBoxPosition = Core.db.profile.editBoxAnchor.position
  local attachedExtent
  if editBoxPosition == "ABOVE" then
    attachedExtent = math.max(0, editBoxHeight + editBoxOffset)
  else
    attachedExtent = math.max(0, editBoxHeight - editBoxOffset)
  end

  self:SetHeight(Core.db.profile.frameHeight + attachedExtent)
  self.layoutContainer:ClearAllPoints()
  if editBoxPosition == "ABOVE" then
    self.layoutContainer:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -attachedExtent)
  else
    self.layoutContainer:SetPoint("TOPLEFT", self, "TOPLEFT")
  end
  self:ScheduleBoundsUpdate()
end

function MoverFrameMixin:ScheduleLayoutBoundsUpdate()
  if self.layoutUpdateScheduled then
    return
  end

  self.layoutUpdateScheduled = true
  C_Timer.After(0, function ()
    self.layoutUpdateScheduled = false
    self:UpdateLayoutBounds()
  end)
end

function MoverFrameMixin:SetLayoutRegions(container, editBox)
  self.layoutContainer = container
  self.layoutEditBox = editBox
  self:UpdateLayoutBounds()
end

function MoverFrameMixin:UpdateBounds()
  local moverLeft = self:GetLeft()
  local moverTop = self:GetTop()
  if moverLeft == nil or moverTop == nil then
    return
  end

  local boundsLeft
  local boundsRight
  local boundsTop
  local boundsBottom
  for _, entry in ipairs(self.boundsRegions) do
    if entry.shouldInclude == nil or entry.shouldInclude() then
      local left, bottom, width, height = entry.frame:GetRect()
      if left and bottom and width and height then
        local right = left + width
        local top = bottom + height
        boundsLeft = boundsLeft and math.min(boundsLeft, left) or left
        boundsRight = boundsRight and math.max(boundsRight, right) or right
        boundsTop = boundsTop and math.max(boundsTop, top) or top
        boundsBottom = boundsBottom and math.min(boundsBottom, bottom) or bottom
      end
    end
  end

  if boundsLeft == nil then
    self.boundsFrame:ClearAllPoints()
    self.boundsFrame:SetAllPoints(self)
    return
  end

  self.boundsFrame:ClearAllPoints()
  self.boundsFrame:SetPoint("TOPLEFT", self, "TOPLEFT", boundsLeft - moverLeft, boundsTop - moverTop)
  self.boundsFrame:SetPoint("BOTTOMRIGHT", self, "TOPLEFT", boundsRight - moverLeft, boundsBottom - moverTop)
  if self.editModePanel and self.editModePanel.frame:IsShown() then self:PositionEditModeSettings() end
end

function MoverFrameMixin:Init()
  self.boundsRegions = {}
  self:ClearAllPoints()
  self:SetPoint(
    Core.db.profile.positionAnchor.point,
    Core.db.profile.positionAnchor.xOfs,
    Core.db.profile.positionAnchor.yOfs
  )
  self:SetWidth(Core.db.profile.frameWidth)
  -- Use the former fixed reserve until the edit box is available and its actual extent can be measured.
  self:SetHeight(Core.db.profile.frameHeight + LEGACY_EDIT_BOX_MARGIN)

  self.boundsFrame = CreateFrame("Frame", nil, self)
  self.boundsFrame:SetAllPoints(self)
  -- Stays above the chat dock, which sits 20 levels over the container.
  self.boundsFrame:SetFrameLevel(self:GetFrameLevel() + 30)
  self.boundsFrame:EnableMouse(true)

  if self.bg == nil then
    self.bg = self.boundsFrame:CreateTexture(nil, "BACKGROUND")
    self.bg:SetAllPoints()
  end
  self.bg:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_FILL_ALPHA)

  if self.topBorder == nil then
    self.topBorder = self.boundsFrame:CreateTexture(nil, "BORDER")
    self.topBorder:SetPoint("TOPLEFT")
    self.topBorder:SetPoint("TOPRIGHT")
    self.topBorder:SetHeight(EDIT_MODE_BORDER_SIZE)

    self.bottomBorder = self.boundsFrame:CreateTexture(nil, "BORDER")
    self.bottomBorder:SetPoint("BOTTOMLEFT")
    self.bottomBorder:SetPoint("BOTTOMRIGHT")
    self.bottomBorder:SetHeight(EDIT_MODE_BORDER_SIZE)

    self.leftBorder = self.boundsFrame:CreateTexture(nil, "BORDER")
    self.leftBorder:SetPoint("TOPLEFT")
    self.leftBorder:SetPoint("BOTTOMLEFT")
    self.leftBorder:SetWidth(EDIT_MODE_BORDER_SIZE)

    self.rightBorder = self.boundsFrame:CreateTexture(nil, "BORDER")
    self.rightBorder:SetPoint("TOPRIGHT")
    self.rightBorder:SetPoint("BOTTOMRIGHT")
    self.rightBorder:SetWidth(EDIT_MODE_BORDER_SIZE)
  end

  self.topBorder:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_BORDER_ALPHA)
  self.bottomBorder:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_BORDER_ALPHA)
  self.leftBorder:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_BORDER_ALPHA)
  self.rightBorder:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_BORDER_ALPHA)

  self:Hide()

  self.boundsFrame:RegisterForDrag("LeftButton")
  self.boundsFrame:SetScript("OnDragStart", function ()
    self:StartDragging()
  end)
  self.boundsFrame:SetScript("OnDragStop", function ()
    self:StopDragging()
    if self.blizzardEditing then
      self:SavePosition()
      Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
    end
  end)
  self.boundsFrame:SetScript("OnEnter", function ()
    self.bg:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_HOVER_ALPHA)
  end)
  self.boundsFrame:SetScript("OnLeave", function ()
    self.bg:SetColorTexture(EDIT_MODE_BLUE_R, EDIT_MODE_BLUE_G, EDIT_MODE_BLUE_B, EDIT_MODE_FILL_ALPHA)
  end)

  if self.subscriptions == nil then
    self.subscriptions = {
      Core:Subscribe(LOCK_MOVER, function ()
        self.manuallyUnlocked = false
        self:UpdateMoverVisibility()
        self:SavePosition()
      end),
      Core:Subscribe(UNLOCK_MOVER, function ()
        self.manuallyUnlocked = true
        self:UpdateMoverVisibility()
      end),
      Core:Subscribe(UPDATE_CONFIG, function (key)
        if (key == "frameWidth") then
          self:SetWidth(Core.db.profile.frameWidth)
        end

        if key == "frameHeight" and self.layoutEditBox == nil then
          self:SetHeight(Core.db.profile.frameHeight + LEGACY_EDIT_BOX_MARGIN)
        end

        if key == "framePosition" then
          self:ClearAllPoints()
          self:SetPoint(
            Core.db.profile.positionAnchor.point,
            Core.db.profile.positionAnchor.xOfs,
            Core.db.profile.positionAnchor.yOfs
          )
        end

        if (
          key == "frameWidth" or
          key == "frameHeight" or
          key == "framePosition" or
          key == "font" or
          key == "editBoxFontSize" or
          key == "editBoxVerticalPadding" or
          key == "editBoxAnchor" or
          key == "combatLogVisibility" or
          key == "combatLogBarLayout"
        ) then
          self:ScheduleLayoutBoundsUpdate()
        end
      end),
    }
  end
  self:ConnectBlizzardEditMode()
end

Core.Components.CreateMoverFrame = function (name, parent)
  local frame = CreateFrame("Frame", name, parent)
  local object = Mixin(frame, MoverFrameMixin)
  object:Init()
  return object
end
