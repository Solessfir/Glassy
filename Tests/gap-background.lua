local dock = {visible = true, alpha = 0.5}
function dock:IsVisible() return self.visible end
function dock:GetAlpha() return self.alpha end
local ui = {dock = dock}
function ui:GetChatWindow() return self.window end
local resizeDuration
local core = {
  Libs = {LibEasing = {Ease = function (_, _, _, _, duration) resizeDuration = duration end}},
  db = {profile = {chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0.4}}},
  Components = {SlidingMessageFrameMixin = {}, SlidingMessageFrameHelpers = {
    getMessageTopInset = function () return 22 end,
    getBaseMessageTopInset = function () return 20 end,
    getEditBoxEasing = function () return function () end end,
  }},
}
function core:GetModule() return ui end
assert(loadfile("Glassy/Components/SlidingMessageFrameLayout.lua"))("Glassy", {core, {}})
local background = {}
function background:SetAlpha(value) self.alpha = value end
function background:SetPoint(point, relative, relativePoint, x, y)
  if point == "TOPLEFT" then
    self.topRelative = relative
    self.topOffset = y
  end
  if point == "BOTTOMLEFT" then
    self.bottomRelative = relative
    self.bottomPoint = relativePoint
    self.bottomOffset = y
  end
end
function background:SetHeight(value) self.height = value end
function background:SetGradientBackground(_, alpha) self.opacity = alpha end
local message = {top = 150, visible = true}
function message:SetBackgroundCoverage(value) self.coverage = value end
function message:DisableDrawLayer(layer)
  assert(layer == "BACKGROUND", "Text must remain visible")
  self.backgroundHidden = true
end
function message:EnableDrawLayer(layer)
  assert(layer == "BACKGROUND")
  self.backgroundHidden = false
end
function message:GetTop() return self.top end
function message:IsVisible() return self.visible end
function message:GetAlpha() return 1 end
local frame = {
  chatFrame = {}, gapBackground = background,
  config = {height = 200}, state = {messages = {message}},
}
function frame:GetTop() return self.viewportTop or 300 end
function frame:GetHeight() return 220 end
function frame:GetWidth() return 600 end
local update = core.Components.SlidingMessageFrameMixin.UpdateGapBackground
update(frame)
assert(background.bottomRelative == frame and background.bottomOffset == -200,
  "Visible tabs must fill the whole viewport")
assert(message.coverage == 0.5, "Message backgrounds must blend with the continuous background")
assert(background.alpha == 0.5 and background.opacity == 0.4)
for _, viewportTop in ipairs({290, 300, 310}) do
  frame.viewportTop = viewportTop
  update(frame)
  assert(background.topRelative == frame and background.topOffset == 0,
    "Gap fill must preserve positive, zero, and negative tab spacing")
  assert(background.glassyHeight == 200)
end
frame.viewportTop = 300
message.top = 310
update(frame)
assert(background.alpha == 0.5 and message.coverage == 0.5, "Full message viewport must blend backgrounds")
message.visible = false
update(frame)
assert(background.bottomRelative == frame and background.bottomOffset == -200,
  "Empty chat must fill to the bottom without animation overflow")
dock.visible = false
update(frame)
assert(background.alpha == 0, "Hidden tabs must leave the gap transparent")
assert(message.coverage == 0, "Hidden tabs must restore message backgrounds")
dock.visible = true
core.db.profile.chatBackgroundColor.a = 0
update(frame)
assert(background.alpha == 0, "Transparent chat must stay transparent")
core.db.profile.chatBackgroundColor.a = 0.4
frame.detachedContainer = {}
ui.window = {detachedLayout = {dock = dock}}
update(frame)
assert(background.alpha == 0.5, "Detached tabs must fill their own gap")
print("PASS: tab gap background geometry, fades, transparency, and detached windows")

local resizing = {
  config = {height = 250}, state = {},
  IsShown = function () return true end,
  CancelDynamicEditBoxLayout = function () end,
  GetMessageFrameHeight = function (self) return self.nextHeight end,
}
core.db.profile.chatFadeInDuration = 3
core.db.profile.chatFadeOutDuration = 4
core.db.profile.editBoxFadeInDuration = 0.2
core.db.profile.editBoxFadeOutDuration = 0.3
local resize = core.Components.SlidingMessageFrameMixin.UpdateDynamicEditBoxLayout
resizing.nextHeight = 230
resize(resizing)
assert(resizeDuration == 0.2, "Making room must use the edit-box fade-in duration")
resizing.nextHeight = 270
resize(resizing)
assert(resizeDuration == 0.3, "Reclaiming space must use the edit-box fade-out duration")
core.db.profile.editBoxFadeOutDuration = 0
resize(resizing)
assert(resizeDuration == 0, "Zero duration must reclaim space instantly")
print("PASS: message-area resizing follows edit-box durations independently of message fades")
