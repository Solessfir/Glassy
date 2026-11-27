-- Run from the repository root with Lua 5.1.
---@diagnostic disable: undefined-global
local function noop() end
local timers = {}
C_Timer = {After = function (_, callback) timers[#timers + 1] = callback end}
local function flush()
  local count = 0
  while #timers > 0 do
    count = count + 1
    assert(count < 30, "Notification anchoring did not settle")
    table.remove(timers, 1)()
  end
end
hooksecurefunc = function (object, method, callback)
  local original = object[method]
  object[method] = function (self, ...)
    original(self, ...)
    callback(self, ...)
  end
end
local combat = false
InCombatLockdown = function () return combat end
local function frame()
  local object = {points = {}, scripts = {}, regions = {}, width = 250}
  function object:ClearAllPoints() self.points = {} end
  function object:SetPoint(point, relative, relativePoint, x, y)
    assert(not self.inNativePass or not self.glassyPass, "Reanchored during native placement")
    for index, anchor in ipairs(self.points) do
      if anchor[1] == point then self.points[index] = {point, relative, relativePoint, x, y}; return end
    end
    self.points[#self.points + 1] = {point, relative, relativePoint, x, y}
  end
  function object:GetNumPoints() return #self.points end
  function object:GetPoint(index) return unpack(self.points[index]) end
  function object:HookScript(event, callback) self.scripts[event] = callback end
  function object:IsProtected() return self.protected end
  function object:GetChildren() return unpack(self.children or {}) end
  function object:GetWidth() return self.width end
  function object:GetRegions() return unpack(self.regions) end
  function object:CreateTexture()
    local region = {SetAllPoints = noop, SetPoint = noop, SetHeight = noop, SetColorTexture = noop,
      Show = function (self) self.shown = true end, Hide = function (self) self.shown = false end}
    self.regions[#self.regions + 1] = region
    return region
  end
  return object
end
local ui = {notificationPlacers = {}, voiceNotes = {}, notificationStyles = {}}
local profile = {notificationStyle = true, font = "Glassy", chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0.5}}
local core = {
  db = {profile = profile},
  Libs = {LSM = {Fetch = function () return "glassy.ttf" end}},
  GetModule = function () return ui end,
  GetThemeColor = function () return {r = 1, g = 1, b = 1} end,
}
assert(loadfile("Glassy/Modules/ChatNotifications.lua"))("Glassy", {core, {}})

local toast, mover, native = frame(), frame(), frame()
ui:AttachNotificationFrame(toast, mover)
toast:SetPoint("BOTTOMLEFT", native, "TOPLEFT", 3, 5)
assert(select(2, toast:GetPoint(1)) == native, "Native anchoring must finish before Glassy moves the toast")
flush()
assert(select(2, toast:GetPoint(1)) == mover)
toast.protected, combat = true, true
toast:ClearAllPoints()
toast:SetPoint("BOTTOMLEFT", native, "TOPLEFT", 3, 5)
flush()
assert(select(2, toast:GetPoint(1)) == native, "Protected combat anchors must remain untouched")
combat = false
ui.notificationPlacers[1]()
assert(select(2, toast:GetPoint(1)) == mover)

local manager, first, second, external, inactive = frame(), frame(), frame(), frame(), frame()
VoiceActivityManager = manager
ui.voiceMover = frame()
manager.children = {first, second, external, inactive}
manager.notificationFrameToParentFrame = {[first] = manager, [second] = manager, [external] = frame()}
first:SetPoint("BOTTOMLEFT", native, "BOTTOMLEFT", 0, 0)
second:SetPoint("BOTTOMLEFT", first, "TOPLEFT", 0, 0)
external:SetPoint("CENTER", native, "CENTER", 0, 0)
ui:RefreshVoiceNotifications()
assert(ui.voiceNotes[first] and ui.voiceNotes[second] and not ui.voiceNotes[external] and not ui.voiceNotes[inactive])
assert(select(2, first:GetPoint(1)) == native, "Unmoved voice notifications retain native anchors")
profile.voicePosition = {point = "CENTER", x = 20, y = 10}
ui:RefreshVoiceNotifications()
assert(select(2, first:GetPoint(1)) == ui.voiceMover, "Only the root follows the voice mover")
assert(select(2, second:GetPoint(1)) == first, "Voice stack spacing and ordering remain native")
first:ClearAllPoints()
first:SetPoint("BOTTOMLEFT", native, "TOPLEFT", 4, 7)
assert(select(2, first:GetPoint(1)) == native)
flush()
assert(select(2, first:GetPoint(1)) == ui.voiceMover)
profile.voicePosition = nil
ui:RefreshVoiceNotifications()
local _, relative, relativePoint, x, y = first:GetPoint(1)
assert(relative == native and relativePoint == "TOPLEFT" and x == 4 and y == 7, "Reset restores the latest native root anchor")

local backdrop = {alpha = 0.6, IsObjectType = function (_, kind) return kind == "Texture" end,
  GetDrawLayer = function () return "BACKGROUND" end, GetWidth = function () return 250 end,
  GetAlpha = function (self) return self.alpha end, SetAlpha = function (self, alpha) self.alpha = alpha end}
local label = {font = {"native.ttf", 12, "OUTLINE"}, color = {0.1, 0.1, 0.1, 1},
  IsObjectType = function (_, kind) return kind == "FontString" end,
  GetFont = function (self) return unpack(self.font) end, SetFont = function (self, ...) self.font = {...} end,
  GetTextColor = function (self) return unpack(self.color) end, SetTextColor = function (self, ...) self.color = {...} end}
local styled = frame()
styled.regions = {backdrop, label}
ui:StyleNotification(styled, "notificationStyle")
assert(backdrop.alpha == 0 and label.font[1] == "glassy.ttf" and label.color[1] == 1)
profile.notificationStyle = false
ui:StyleNotification(styled, "notificationStyle")
assert(backdrop.alpha == 0.6 and label.font[1] == "native.ttf" and label.color[1] == 0.1)
assert(not styled.glassyNotificationBackground.shown and not styled.glassyNotificationLine.shown)
print("PASS: Deferred notification anchoring, protected frames, native voice stacks, and reversible skins")
