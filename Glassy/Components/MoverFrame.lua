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

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local C_Timer = C_Timer
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
  -- Preserve the established mover anchor geometry so existing saved positions do not shift.
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
    self:StartMoving()
  end)
  self.boundsFrame:SetScript("OnDragStop", function ()
    self:StopMovingOrSizing()
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

        if (key == "frameHeight") then
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
          key == "editBoxAnchor" or
          key == "combatLogVisibility" or
          key == "combatLogBarLayout"
        ) then
          self:ScheduleBoundsUpdate()
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
