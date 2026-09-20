local transfer = {}
local core = {Components = {}, db = {profile = {}}, GetModule = function () return transfer end}
assert(loadfile("Glassy/Modules/ProfileTransfer.lua"))("Glassy", {core})
assert(loadfile("Glassy/Components/GradientBackground.lua"))("Glassy", {core})
local defaults = {frameWidth = 600, backgroundFadeLeftPercent = 0, backgroundFadeRightPercent = 60}
local profile = {frameWidth = 800, backgroundFadeLeftWidth = 80, backgroundFadeRightWidth = 200}
transfer:NormalizeBackgroundFades(profile, defaults)
assert(profile.backgroundFadeLeftPercent == 10 and profile.backgroundFadeRightPercent == 25)
assert(profile.backgroundFadeLeftWidth == nil and profile.backgroundFadeRightWidth == nil)
profile.frameWidth = 1200
transfer:NormalizeBackgroundFades(profile, defaults)
assert(profile.backgroundFadeRightPercent == 25, "Resizing must not migrate percentages again")
local imported = assert(transfer:Import(assert(transfer:Export({frameWidth = 800, backgroundFadeRightWidth = 200})), defaults))
assert(imported.backgroundFadeRightPercent == 25, "Import must migrate before dropping obsolete keys")
local legacy = {backgroundFadeLeft = false, backgroundFadeRight = true}
transfer:NormalizeBackgroundFades(legacy, defaults)
assert(legacy.backgroundFadeLeftPercent == 0 and legacy.backgroundFadeRightPercent == 250 / 600 * 100)

function CreateColor(r, g, b, a) return {r = r, g = g, b = b, a = a} end
local function noop() end
local frame = {width = 600}
function frame:GetWidth() return self.width end
function frame:CreateTexture()
  return {ClearAllPoints = noop, SetPoint = noop, SetColorTexture = noop,
    SetWidth = function (self, width) self.width = width end,
    SetGradient = function (self, _, first, last) self.first, self.last = first, last end,
    Show = function (self) self.shown = true end,
    Hide = function (self) self.shown = false end}
end
core.db.profile = profile
local function render()
  core.Components.GradientBackgroundMixin.SetGradientBackground(frame, {r = 0, g = 0, b = 0, a = 0.4})
end
render()
assert(frame.leftBg.width == 60 and frame.rightBg.width == 150)
assert(frame.leftBg.first.a == 0 and frame.rightBg.last.a == 0, "Outer edges must be transparent")
frame.width = 1200
render()
assert(frame.leftBg.width == 120 and frame.rightBg.width == 300)
assert(frame.centerBg.shown, "Partial fades need the solid center")
profile.backgroundFadeLeftPercent, profile.backgroundFadeRightPercent = 0, 100
render()
assert(not frame.centerBg.shown, "A full-width fade must hide the collapsed solid texture")
assert(frame.rightBg.last.a == 0)
profile.backgroundFadeLeftPercent, profile.backgroundFadeRightPercent = 100, 100
render()
assert(frame.leftBg.width == 600 and frame.rightBg.width == 600, "Fades must not overlap")
assert(not frame.centerBg.shown)
profile.backgroundFadeLeftPercent, profile.backgroundFadeRightPercent = 0, 0
render()
assert(not frame.leftBg.shown and not frame.rightBg.shown)
assert(frame.centerBg.shown, "Disabling fades must restore the solid center")
print("PASS: percentage fades resize, reach transparent edges, and migrate saved/imported profiles")
