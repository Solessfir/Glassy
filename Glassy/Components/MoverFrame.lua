local Core, Constants = unpack(select(2, ...))

local SaveFramePosition = Constants.ACTIONS.SaveFramePosition

local LOCK_MOVER = Constants.EVENTS.LOCK_MOVER
local UNLOCK_MOVER = Constants.EVENTS.UNLOCK_MOVER
local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

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
  self.boundsFrame:SetFrameLevel(self:GetFrameLevel() + 10)
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
        self:Hide()
        self:EnableMouse(false)
        self:SetMovable(false)

        local point, _, _, xOfs, yOfs = self:GetPoint(1)
        local position = {
          point = point,
          xOfs = xOfs,
          yOfs = yOfs
        }

        Core:Dispatch(SaveFramePosition(position))
      end),
      Core:Subscribe(UNLOCK_MOVER, function ()
        self:Show()
        self:EnableMouse(true)
        self:SetMovable(true)
        self:ScheduleBoundsUpdate()
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
end

Core.Components.CreateMoverFrame = function (name, parent)
  local frame = CreateFrame("Frame", name, parent)
  local object = Mixin(frame, MoverFrameMixin)
  object:Init()
  return object
end
