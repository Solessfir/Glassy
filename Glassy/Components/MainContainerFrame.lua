local Core, Constants = unpack(select(2, ...))

local MouseEnter = Constants.ACTIONS.MouseEnter
local MouseLeave = Constants.ACTIONS.MouseLeave

local UPDATE_CONFIG = Constants.EVENTS.UPDATE_CONFIG

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local CreateFrame = CreateFrame
local Mixin = Mixin
local MouseIsOver = MouseIsOver
-- luacheck: pop

local MainContainerFrameMixin = {}

local function isMouseOver(region)
  if region.IsMouseOver then
    return region:IsMouseOver()
  end
  return MouseIsOver and MouseIsOver(region) or false
end

function MainContainerFrameMixin:Init()
  self.state = {
    mouseOver = false
  }
  self.hoverRegions = {
    [self] = true
  }

  self:SetWidth(Core.db.profile.frameWidth)
  self:SetHeight(Core.db.profile.frameHeight)

  --[===[@debug@
  self.bg = self:CreateTexture(nil, "BACKGROUND")
  self.bg:SetColorTexture(1, 0, 0, 0)
  self.bg:SetAllPoints()
  --@end-debug@]===]

  Core:Subscribe(UPDATE_CONFIG, function (key)
    if key == "frameWidth" then
      self:SetWidth(Core.db.profile.frameWidth)
    end

    if key == "frameHeight" then
      self:SetHeight(Core.db.profile.frameHeight)
    end
  end)
end

function MainContainerFrameMixin:AddHoverRegion(region)
  if region then
    self.hoverRegions[region] = true
  end
end

function MainContainerFrameMixin:IsMouseOverTrackedRegions()
  for region in pairs(self.hoverRegions) do
    if region:IsVisible() and isMouseOver(region) then
      return true
    end
  end
  return false
end

function MainContainerFrameMixin:OnFrame()
  -- Mouse over tracking
  local mouseOver = self:IsMouseOverTrackedRegions()
  if self.state.mouseOver ~= mouseOver then
    if not self.state.mouseOver then
      Core:Dispatch(MouseEnter())
    else
      Core:Dispatch(MouseLeave())
    end

    self.state.mouseOver = mouseOver
  end
end

Core.Components.CreateMainContainerFrame = function (name, parent)
  local frame = CreateFrame("Frame", name, parent)
  local object = Mixin(frame, MainContainerFrameMixin)
  object:Init()
  return object
end
