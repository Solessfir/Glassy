local function noop() end
CreateColor = function (r, g, b, a) return {r = r, g = g, b = b, a = a} end
Mixin = function (object, ...)
  for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do object[key] = value end
  end
  return object
end
local function texture()
  return {SetGradient = noop, SetColorTexture = function (self, _, _, _, alpha) self.alpha = alpha end}
end
CreateFrame = function ()
  local frame = {
    alpha = 1, leftBg = texture(), centerBg = texture(), rightBg = texture(),
    text = {ClearAllPoints = noop, SetPoint = noop, SetWidth = noop, SetIndentedWordWrap = noop},
    SetWidth = noop, SetHyperlinksEnabled = noop, SetScript = noop,
    SetFadeInDuration = noop, SetFadeOutDuration = noop, SetFadeEasing = noop,
    GetWidth = function () return 600 end,
    GetAlpha = function (self) return self.alpha end,
    DisableDrawLayer = function (self) self.hidden = true end,
    EnableDrawLayer = function (self) self.hidden = false end,
  }
  return frame
end
local core = {
  Components = {FadingFrameMixin = {Init = noop}, GradientBackgroundMixin = {Init = noop, SetGradientBackground = noop}},
  db = {profile = {frameWidth = 600, textLeftPadding = 0, chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0.4}}},
}
assert(loadfile("Glassy/Components/MessageLine.lua"))("Glassy", {core, {ACTIONS = {}, TEXT_RIGHT_PADDING = 15}})
local message = core.Components.CreateMessageLine()
for _, opacity in ipairs({0, 0.4, 1}) do
  core.db.profile.chatBackgroundColor.a = opacity
  for _, messageAlpha in ipairs({0, 0.01, 0.25, 0.5, 1}) do
    message.alpha = messageAlpha
    for _, coverage in ipairs({0, 0.01, 0.25, 0.5, 1}) do
      message:SetBackgroundCoverage(coverage)
      local base = opacity * coverage
      local residual = message.hidden and 0 or message.centerBg.alpha * messageAlpha
      local combined = base + (1 - base) * residual
      assert(math.abs(combined - opacity * math.max(messageAlpha, coverage)) < 0.000001,
        "Hover must preserve existing message opacity without darkening returning messages")
    end
  end
end
print("PASS: background transitions preserve message opacity across hover and message fades")
