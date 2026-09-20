-- Run from the repository root with Lua 5.1.
---@diagnostic disable: undefined-global
local function noop() end

local function newFrame(parent)
  local frame = {
    parent = parent,
    left = 0,
    bottom = 0,
    width = 200,
    height = 100,
    scripts = {},
  }

  function frame:GetParent() return self.parent end
  function frame:GetCenter() return self.left + self.width / 2, self.bottom + self.height / 2 end
  function frame:GetLeft() return self.left end
  function frame:GetRight() return self.left + self.width end
  function frame:GetBottom() return self.bottom end
  function frame:GetTop() return self.bottom + self.height end
  function frame:GetWidth() return self.width end
  function frame:GetHeight() return self.height end
  function frame:GetEffectiveScale() return 1 end
  function frame:GetFrameLevel() return 1 end
  function frame:ClearAllPoints() self.point = nil end
  function frame:SetPoint(...) self.point = {...} end
  function frame:SetWidth(width) self.width = width end
  function frame:SetHeight(height) self.height = height end
  function frame:SetAllPoints() end
  function frame:SetFrameLevel() end
  function frame:EnableMouse() end
  function frame:RegisterForDrag() end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:SetMovable() end
  function frame:StartMoving() end
  function frame:StopMovingOrSizing() end
  function frame:Hide() end
  function frame:CreateTexture()
    return {
      SetAllPoints = noop,
      SetPoint = noop,
      SetHeight = noop,
      SetWidth = noop,
      SetColorTexture = noop,
    }
  end

  return frame
end

local parent = newFrame(nil)
parent.width, parent.height = 1000, 800

CreateFrame = function (_, _, frameParent) return newFrame(frameParent) end
Mixin = function (object, mixin)
  for key, value in pairs(mixin) do object[key] = value end
  return object
end
C_Timer = {After = function (_, callback) callback() end}
local cursorX, cursorY = 0, 0
GetCursorPosition = function () return cursorX, cursorY end

local core = {
  Components = {},
  db = {profile = {
    frameWidth = 200,
    frameHeight = 100,
    positionAnchor = {point = "BOTTOMLEFT", xOfs = 0, yOfs = 0},
  }},
  Subscribe = function () end,
}
local constants = {
  ACTIONS = {SaveFramePosition = "save"},
  EVENTS = {LOCK_MOVER = "lock", UNLOCK_MOVER = "unlock", UPDATE_CONFIG = "update"},
}

assert(loadfile("Glassy/Components/MoverFrame.lua"))("Glassy", {core, constants})
local mover = core.Components.CreateMoverFrame("Test", parent)
mover.left, mover.bottom, mover.height = 300, 300, 100
cursorX, cursorY = 350, 350
mover.boundsFrame.scripts.OnDragStart()

cursorX, cursorY = 55, 400
mover.boundsFrame.scripts.OnUpdate()
assert(mover.point[1] == "BOTTOMLEFT" and mover.point[4] == 0 and mover.point[5] == 350,
  "The left edge did not snap while dragging")

cursorX, cursorY = 450, 745
mover.boundsFrame.scripts.OnUpdate()
assert(mover.point[1] == "TOPLEFT" and mover.point[4] == 400 and mover.point[5] == 0,
  "The top edge did not snap while dragging")

cursorX, cursorY = 845, 745
mover.boundsFrame.scripts.OnUpdate()
assert(mover.point[1] == "TOPRIGHT" and mover.point[4] == 0 and mover.point[5] == 0,
  "The corner did not snap while dragging")

mover.boundsFrame.scripts.OnDragStop()
assert(mover.boundsFrame.scripts.OnUpdate == nil, "The live drag update was not removed")

print("PASS: Mover snaps live to screen sides and corners.")
