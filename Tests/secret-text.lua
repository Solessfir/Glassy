local function noop() end
local SECRET = "secret boss emote"
-- Secret values error on arithmetic, so model them as tables.
local secretNumber = setmetatable({}, {__add = function () error("arithmetic on secret") end})
canaccessvalue = function (value) return value ~= SECRET and value ~= secretNumber end
CreateColor = function (r, g, b, a) return {r = r, g = g, b = b, a = a} end
Mixin = function (object, ...)
  for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do object[key] = value end
  end
  return object
end

local function fontString()
  local text = {SetWidth = noop, SetIndentedWordWrap = noop, SetFontObject = noop, Hide = noop,
    GetLineHeight = function () return 10 end}
  function text:SetText(value) self.value = value end
  function text:ClearText() self.value = nil end
  function text:GetStringHeight()
    if self.value == SECRET then return secretNumber end
    return self.value and 30 or 0
  end
  function text:ClearAllPoints() self.points = {} end
  function text:SetPoint(...)
    assert(self.value ~= SECRET, "Secret text must be cleared before anchoring")
    self.points = self.points or {}
    self.points[#self.points + 1] = {...}
  end
  return text
end
local measure = fontString()
UIParent = {CreateFontString = function () return measure end}
measure.SetPoint = noop

local parent = {}
CreateFrame = function ()
  local text = fontString()
  local frame = {
    leftBg = {}, centerBg = {}, rightBg = {},
    SetWidth = noop, SetHyperlinksEnabled = noop, SetScript = noop,
    SetFadeInDuration = noop, SetFadeOutDuration = noop, SetFadeEasing = noop,
    GetParent = function () return parent end,
    GetWidth = function () error("Message bounds must not be read") end,
    CreateFontString = function () return text end,
    ClearAllPoints = noop, DisableDrawLayer = noop, GetAlpha = function () return 1 end,
  }
  function frame:SetPoint(_, relativeTo)
    assert(relativeTo ~= self.text or self.text.value ~= SECRET, "Secret text must be cleared before anchoring to it")
  end
  return frame
end
local core = {
  Components = {FadingFrameMixin = {Init = noop}, GradientBackgroundMixin = {Init = noop, SetGradientBackground = noop}},
  db = {profile = {frameWidth = 600, textLeftPadding = 4, messageLinePadding = 0.5, indentWordWrap = true,
    chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0}}},
}
assert(loadfile("Glassy/Components/MessageLine.lua"))("Glassy", {core, {ACTIONS = {}, TEXT_RIGHT_PADDING = 15}})

local public = core.Components.CreateMessageLine(parent)
public:SetDisplayText("hello")
public:UpdateFrame()
assert(public.glassyHeight == 40, "Public rows use the detached measurement")
assert(public.text.points[1][2] == parent and public.text.points[1][5] == 5)

local secret = core.Components.CreateMessageLine(parent)
secret:SetDisplayText(SECRET)
secret:UpdateFrame()
assert(secret.glassyHeight == 20, "Secret rows fall back to one line for scroll accounting")
assert(secret.text.value == SECRET, "Secret text is restored after anchoring")
assert(measure.value == nil, "Measurement text is cleared")

public:SetChainAnchor(secret, "TOPLEFT")
assert(public.text.points[1][2] == secret and public.text.points[1][3] == "TOPLEFT")
secret:SetChainAnchor(public, "TOPLEFT")
assert(secret.text.value == SECRET)
print("PASS: secret chat text is anchored without reading or measuring secret values")
