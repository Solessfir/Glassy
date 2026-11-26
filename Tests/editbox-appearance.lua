local function noop() end
local methods = {}
local function node()
  return setmetatable({shown = true, scripts = {}, width = 400, height = 24, alpha = 1}, {__index = methods})
end
function methods:CreateTexture() return node() end
function methods:ClearAllPoints() self.points = {} end
function methods:SetPoint(...) self.points = self.points or {}; self.points[#self.points + 1] = {...} end
function methods:SetSize(width, height) self.width, self.height = width, height end
function methods:SetWidth(width) self.width = width end
function methods:SetHeight(height) self.height = height end
function methods:GetWidth() return self.width end
function methods:GetHeight() return self.height end
function methods:GetEffectiveScale() return 1 end
function methods:GetAlpha() return self.alpha end
function methods:SetAlpha(alpha)
  self.alpha = alpha
  if self.afterAlpha then self.afterAlpha() end
end
function methods:SetShown(shown) self.shown = shown end
function methods:Show() self.shown = true end
function methods:Hide() self.shown = false end
function methods:IsShown() return self.shown end
function methods:IsMouseOver() return true end
function methods:HasFocus() return self.focus end
function methods:SetFocus() self.focus = true end
function methods:GetName() return "ChatFrame1EditBox" end
function methods:GetTextColor() return 0.2, 0.5, 0.8 end
function methods:SetTexture(path) self.texture = path end
function methods:SetVertexColor(...) self.color = {...} end
function methods:SetColorTexture(...) self.color = {...} end
function methods:SetGradient(_, left, right) self.gradient = {left, right} end
function methods:SetScript(name, callback) self.scripts[name] = callback end
function methods:HookScript(name, callback) self.scripts[name] = callback end
function methods:Insert(text) self.inserted = text end
methods.SetAllPoints, methods.SetFrameStrata, methods.SetClampedToScreen = noop, noop, noop
methods.EnableMouse, methods.SetHighlightTexture = noop, noop

local created = {}
CreateFrame = function (kind, name, parent)
  local result = node()
  result.kind, result.name, result.parent = kind, name, parent
  created[#created + 1] = result
  return result
end
CreateColor = function (r, g, b, a) return {r = r, g = g, b = b, a = a} end
Mixin = function (object, ...)
  for index = 1, select("#", ...) do
    for key, value in pairs(select(index, ...)) do object[key] = value end
  end
  return object
end
UISpecialFrames, UIParent = {}, node()
GameTooltip = {Hide = noop}
strfind, strlen, strsub, strjoin = string.find, string.len, string.sub, function (separator, ...) return table.concat({...}, separator) end
local processing = {}
local core = {
  Components = {}, Libs = {},
  db = {profile = {
    editBoxBackgroundColor = {r = 0.1, g = 0.2, b = 0.3, a = 0.5},
    editBoxMessageSeparatorColor = {a = 0.2}, editBoxAnchor = {position = "BELOW"},
    backgroundFadeLeftPercent = 0, backgroundFadeRightPercent = 60,
    emotePickerEnabled = false, emojisEnabled = true,
  }},
  GetModule = function () return processing end,
  GetThemeColor = function (self, key) return self.db.profile[key] end,
}
local constants = {ACTIONS = {}, EVENTS = {UPDATE_CONFIG = "config"}}
local utils = {super = function () return methods end}
for _, file in ipairs({"GradientBackground", "EditBox", "EditBoxAppearance", "EditBoxNative"}) do
  assert(loadfile("Glassy/Components/"..file..".lua"))("Glassy", {core, constants, utils})
end
assert(loadfile("Glassy/Modules/TextProcessing.lua"))("Glassy", {core, constants, utils})
local edit = Mixin(node(), core.Components.GradientBackgroundMixin, core.Components.EditBoxMixin)
edit.header, edit.messageSeparator = node(), node()
edit.messageSeparator.SetSeparatorColor = function (self) self:Show() end
edit.glassyBackgroundAlpha = 0.5

edit:UpdateGlassyBackground()
assert(edit.centerBg.shown and not edit.glassyInputLayers, "Default Solid appearance changed")
core.db.profile.editBoxStyle = "minimal"
edit:UpdateGlassyBackground()
local layers = edit.glassyInputLayers
assert(not edit.centerBg.shown and not edit.messageSeparator.shown)
assert(not layers[1].shown and layers[3].shown and layers[5].shown)
assert(layers[3].gradient[1].a == 0 and layers[3].gradient[2].a == 0.25)
assert(layers[4].gradient[1].a == 0.25 and layers[4].gradient[2].a == 0)
assert(layers[5].gradient[2].r == 0.2 and layers[5].gradient[2].a == 0.4, "Minimal line lost the channel color or fade")
core.db.profile.editBoxStyle = "framed"
edit:UpdateGlassyBackground()
assert(layers[1].shown and layers[2].shown and not layers[3].shown)
assert(layers[1].color[4] == 0.25 and layers[2].color[4] == 0.45)
edit.glassyBackgroundTopInset = edit.height
edit:UpdateGlassyBackground()
for _, texture in ipairs(layers) do assert(not texture.shown, "Input styling escaped background clipping") end
edit.glassyBackgroundTopInset = 0
core.db.profile.editBoxStyle = "solid"
edit:UpdateGlassyBackground()
edit:UpdateMessageSeparator()
assert(edit.centerBg.shown and edit.messageSeparator.shown)
for _, texture in ipairs(layers) do assert(not texture.shown, "Switching back to Solid left new styling visible") end

edit:UpdateEmotePicker()
assert(not edit.glassyEmoteButton, "Disabled picker allocated its grid")
core.db.profile.emotePickerEnabled = true
edit:UpdateEmotePicker()
assert(edit.glassyEmoteButton.shown and #UISpecialFrames == 1)
local names = {}
for _, pick in ipairs(processing.EMOTE_PICKS) do
  assert(not names[pick[1]], "Picker duplicates a shortcode alias")
  names[pick[1]] = true
  local file = assert(io.open("Glassy/Assets/Emotes/twemoji_"..pick[1]..".tga", "rb"))
  file:close()
  assert(processing:ProcessText(pick[2]):find("twemoji_"..pick[1], 1, true), "Picker inserts an unsupported code")
end
local cell
for _, frame in ipairs(created) do if frame.kind == "Button" then cell = frame; break end end
ChatFrameUtil = {ActivateChat = function (box) box:Show(); box:SetFocus() end}
cell.scripts.OnClick()
assert(edit.inserted == processing.EMOTE_PICKS[1][2].." " and edit.focus)
edit.inserted = nil
C_ChatInfo = {InChatMessagingLockdown = function () return true end}
cell.scripts.OnClick()
assert(not edit.inserted, "Picker inserted into locked chat")
C_ChatInfo = nil
edit.scripts.OnMouseUp(edit, "LeftButton")
assert(edit.glassyEmotePanel.shown)
core.db.profile.emojisEnabled = false
edit:UpdateEmotePicker()
assert(not edit.glassyEmoteButton.shown and not edit.glassyEmotePanel.shown)

edit.focus = true
edit.afterAlpha = function () edit:RestoreFocusedAlpha() end
edit:SetAlpha(0)
assert(edit.alpha == 1 and not edit.glassyRestoringAlpha, "Focused input stayed invisible or recursed")
edit.focus = false
edit:SetAlpha(0.2)
assert(edit.alpha == 0.2, "Unfocused input blocked another addon's fade")
canaccessvalue = function () return false end
edit.focus = true
edit:RestoreFocusedAlpha()
assert(edit.alpha == 0.2, "Protected opacity was inspected")
print("PASS: input styles, clipping, Twemoji picker, locked chat and focused alpha restoration")
