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

mover.left, mover.bottom = 792, 660
mover.boundsFrame.scripts.OnDragStop()
assert(mover.point[1] == "TOPRIGHT" and mover.point[4] == 0 and mover.point[5] == 0,
  ("A window close to a corner must snap flush to it; got %s, %s, %s"):format(
    tostring(mover.point[1]), tostring(mover.point[4]), tostring(mover.point[5])))

mover.left, mover.bottom = 600, 300
mover.boundsFrame.scripts.OnDragStop()
assert(mover.point[1] == "BOTTOMRIGHT" and mover.point[4] == -200 and mover.point[5] == 300,
  ("Free placement must use the nearest corner without moving the window; got %s, %s, %s"):format(
    tostring(mover.point[1]), tostring(mover.point[4]), tostring(mover.point[5])))

print("PASS: Mover selects the nearest corner and snaps within 20 UI points.")
