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
    frameLevel = parent and parent:GetFrameLevel() + 1 or 0,
    shown = true,
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
  function frame:GetFrameLevel() return self.frameLevel end
  function frame:GetFrameStrata() return self.frameStrata or (self.parent and self.parent:GetFrameStrata()) or "MEDIUM" end
  function frame:ClearAllPoints() self.point = nil end
  function frame:SetPoint(...) self.point = {...} end
  function frame:GetPoint() return unpack(self.point, 1, 5) end
  function frame:SetWidth(width) self.width = width end
  function frame:SetHeight(height) self.height = height end
  function frame:SetAllPoints() end
  function frame:SetFrameLevel(level) self.frameLevel = level end
  function frame:SetParent(frameParent) self.parent = frameParent end
  function frame:SetFrameStrata(strata) self.frameStrata = strata end
  function frame:SetClampedToScreen() end
  function frame:EnableMouse(enabled) self.mouseEnabled = enabled end
  function frame:RegisterForDrag() end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:SetMovable() end
  function frame:StartMoving() end
  function frame:StopMovingOrSizing() end
  function frame:Hide() self.shown = false end
  function frame:Show() self.shown = true end
  function frame:SetShown(shown) self.shown = shown end
  function frame:IsShown() return self.shown end
  function frame:HookScript(name, callback) self.scripts[name] = callback end
  function frame:SetSize(width, height) self.width, self.height = width, height end
  function frame:SetText(text) self.text = text end
  function frame:CreateFontString() return {SetPoint = noop, SetText = noop} end
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

CreateFrame = function (kind, _, frameParent)
  local frame = newFrame(frameParent)
  frame:EnableMouse(kind == "Button")
  return frame
end
Mixin = function (object, mixin)
  for key, value in pairs(mixin) do object[key] = value end
  return object
end
C_Timer = {After = function (_, callback) callback() end}
local cursorX, cursorY = 0, 0
GetCursorPosition = function () return cursorX, cursorY end

local subscriptions, saved, opened = {}, nil, false
local core = {
  Components = {},
  db = {profile = {
    frameWidth = 200,
    frameHeight = 100,
    positionAnchor = {point = "BOTTOMLEFT", xOfs = 0, yOfs = 0},
  }},
  Libs = {AceConfigRegistry = {NotifyChange = noop}},
  Localize = function (_, label) return label end,
  GetModule = function () return {OpenSettings = function () opened = true end} end,
  Subscribe = function (_, event, callback)
    subscriptions[event] = subscriptions[event] or {}
    table.insert(subscriptions[event], callback)
  end,
  Dispatch = function (_, event, payload)
    assert(event == "save")
    saved = payload
  end,
}
local constants = {
  ACTIONS = {SaveFramePosition = function (position) return "save", position end},
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

EditModeManagerFrame = newFrame(parent)
EditModeManagerFrame:Hide()
local nativeMover = core.Components.CreateMoverFrame("EditModeTest", parent)
local boundsStrata, boundsLevel = nativeMover.boundsFrame:GetFrameStrata(), nativeMover.boundsFrame:GetFrameLevel()
local settingsStrata, settingsLevel = nativeMover.editModeSettings:GetFrameStrata(), nativeMover.editModeSettings:GetFrameLevel()
local nativeSelection = newFrame(parent)
nativeSelection:SetFrameStrata("MEDIUM")
nativeSelection:SetFrameLevel(1000)
nativeSelection:EnableMouse(true)
local strataOrder = {MEDIUM = 1, HIGH = 2, DIALOG = 3}
local function topMouseTarget(...)
  local target
  for _, frame in ipairs({...}) do
    local visible, ancestor = true, frame
    while ancestor do
      visible = visible and ancestor:IsShown()
      ancestor = ancestor:GetParent()
    end
    if visible and frame.mouseEnabled and (not target
      or strataOrder[frame:GetFrameStrata()] > strataOrder[target:GetFrameStrata()]
      or (frame:GetFrameStrata() == target:GetFrameStrata() and frame:GetFrameLevel() > target:GetFrameLevel())) then
      target = frame
    end
  end
  return target
end
assert(not nativeMover:IsShown())
EditModeManagerFrame:SetShown(true)
EditModeManagerFrame.scripts.OnShow()
assert(nativeMover:IsShown() and nativeMover.editModeSettings:IsShown(), "Edit Mode shows Glassy's mover")
assert(topMouseTarget(nativeSelection, nativeMover.boundsFrame) == nativeMover.boundsFrame,
  "Glassy's actual drag target must receive the mouse above Blizzard's MEDIUM/1000 selection")
assert(topMouseTarget(nativeSelection, nativeMover.boundsFrame, nativeMover.editModeSettings) == nativeMover.editModeSettings,
  "The settings button must remain clickable above both mover overlays")
nativeMover.editModeSettings.scripts.OnClick()
assert(opened, "The Edit Mode shortcut opens the addon's settings")
nativeMover.boundsFrame.scripts.OnDragStart()
cursorX = cursorX + 35
nativeMover.boundsFrame.scripts.OnDragStop()
assert(saved and saved.point == nativeMover.point[1] and saved.xOfs == nativeMover.point[4],
  "Dragging in Edit Mode saves the current profile position on drop")
core.db.profile.blizzardEditMode = false
for _, callback in ipairs(subscriptions.update) do callback("blizzardEditMode") end
assert(not nativeMover:IsShown(), "Disabling Edit Mode integration hides its mover")
assert(nativeMover.boundsFrame:GetFrameStrata() == boundsStrata and nativeMover.boundsFrame:GetFrameLevel() == boundsLevel
  and nativeMover.editModeSettings:GetFrameStrata() == settingsStrata and nativeMover.editModeSettings:GetFrameLevel() == settingsLevel,
  "Disabling integration must restore the original mover and button layering")
core.db.profile.blizzardEditMode = true
for _, callback in ipairs(subscriptions.update) do callback("blizzardEditMode") end
for _, callback in ipairs(subscriptions.unlock) do callback() end
EditModeManagerFrame:Hide()
EditModeManagerFrame.scripts.OnHide()
assert(nativeMover:IsShown() and not nativeMover.editModeSettings:IsShown(), "Leaving Edit Mode preserves manual unlock")
assert(nativeMover.boundsFrame:GetFrameStrata() == boundsStrata and nativeMover.boundsFrame:GetFrameLevel() == boundsLevel
  and nativeMover.editModeSettings:GetFrameStrata() == settingsStrata and nativeMover.editModeSettings:GetFrameLevel() == settingsLevel,
  "Leaving Edit Mode must restore layering even while manually unlocked")

UIParent = parent
local registered
local function option(key)
  return {name = key, type = "range", get = function () return core.db.profile[key] end,
    set = function (_, value) core.db.profile[key] = value end}
end
local config = {Pages = {
  general = function () return {args = {section3 = {args = {frameWidth = option("frameWidth"), frameHeight = option("frameHeight")}}}} end,
  messages = function () return {args = {
    section1 = {args = {messageFont = option("messageFont"), messageFontSize = option("messageFontSize"), chatBackgroundColor = option("chatBackgroundColor")}},
    section2 = {args = {chatAlwaysVisible = option("chatAlwaysVisible"), chatHoldTime = option("chatHoldTime")}},
    animation = {args = {fadeInDuration = option("fadeInDuration"), fadeOutDuration = option("fadeOutDuration"), slideInDuration = option("slideInDuration")}},
  }} end,
  editBox = function () return {args = {section1 = {args = {editBoxFontSize = option("editBoxFontSize")}}}} end,
}}
core.GetModule = function () return config end
core.LocalizeOptions = noop
core.Libs.AceConfig = {RegisterOptionsTable = function (_, _, options) registered = options end}
core.Libs.AceGUI = {Create = function (_, kind)
  assert(kind == "Frame", "Use a bounded Frame container so AceConfigDialog adds its scroll frame")
  local widget = {frame = newFrame(parent), SetTitle = noop, SetLayout = noop, EnableResize = noop}
  widget.frame:EnableMouse(true)
  function widget:SetWidth(width) self.frame:SetWidth(width) end
  function widget:SetHeight(height) self.frame:SetHeight(height) end
  return widget
end}
local panelOpened = 0
local panelWidth, panelHeight
core.Libs.AceConfigDialog = {
  SetDefaultSize = function (_, _, width, height) panelWidth, panelHeight = width, height end,
  Open = function (_, _, panel)
    panelOpened = panelOpened + 1
    panel:SetWidth(panelWidth)
    panel:SetHeight(panelHeight)
    panel.frame:ClearAllPoints()
    panel.frame:SetPoint("CENTER")
  end,
}
nativeMover.boundsFrame.left, nativeMover.boundsFrame.bottom = 800, 700
nativeMover:OpenEditModeSettings()
assert(panelOpened == 1 and registered, "The inline panel opens its registered AceConfig options")
local keys = {"frameWidth", "frameHeight", "messageFont", "messageFontSize", "editBoxFontSize", "chatBackgroundColor",
  "chatAlwaysVisible", "chatHoldTime", "fadeInDuration", "fadeOutDuration", "slideInDuration"}
for index, key in ipairs(keys) do
  registered.args["setting"..index].set({}, 100 + index)
  assert(core.db.profile[key] == 100 + index and registered.args["setting"..index].get() == 100 + index,
    "Edit Mode control must update its original profile key: "..key)
end
local panelFrame = nativeMover.editModePanel.frame
EditModeManagerFrame:Show()
EditModeManagerFrame.scripts.OnShow()
assert(nativeMover:GetFrameStrata() == boundsStrata, "Edit Mode must preserve the mover container's normal chat strata")
assert(panelFrame:GetFrameStrata() == "DIALOG"
  and topMouseTarget(nativeSelection, nativeMover.boundsFrame, nativeMover.editModeSettings, panelFrame) == panelFrame,
  "The settings panel must keep DIALOG strata and receive mouse input above the raised mover")
assert(panelFrame:GetHeight() <= parent:GetHeight() - 40, "Settings height is bounded to the screen")
assert(panelFrame.point[4] == 442 and panelFrame.point[5] == 790,
  "Settings near the top-right corner open to the left and stay within the screen")
nativeMover.boundsFrame.left, nativeMover.boundsFrame.bottom = 0, 0
nativeMover:PositionEditModeSettings()
assert(panelFrame.point[4] == 208 and panelFrame.point[5] == 580,
  "Settings near the bottom-left corner open to the right and stay within the screen")

print("PASS: Mover snapping, Edit Mode mouse layering, gestures, profile control mapping, panel bounds, and manual unlock")
