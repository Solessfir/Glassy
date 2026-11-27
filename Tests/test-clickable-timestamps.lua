-- Run from the repository root: lua Tests/test-clickable-timestamps.lua
_G.unpack = _G.unpack or table.unpack
_G.strfind, _G.strlen, _G.strsub = string.find, string.len, string.sub
_G.strjoin = function(separator, ...) return table.concat({...}, separator) end
_G.strsplit = function(separator, text)
  local parts = {}
  for part in (text..separator):gmatch("(.-)"..separator) do parts[#parts + 1] = part end
  return unpack(parts)
end
_G.date = os.date
local secret = {}
_G.canaccessvalue = function(value) return value ~= secret end
local modules = {TextProcessing = {}, ChatCopy = {}, Hyperlinks = {}, ChatLinks = {}}
local profile = {
  timestampsEnabled = true, timestampClickable = false, timestampFormat = "[%H:%M:%S]",
  timestampFrames = {ChatFrame1 = true}, timestampColorEnabled = false,
  frameWidth = 400, chatBackgroundColor = {r = 0, g = 0, b = 0, a = 0},
}
local events = {HYPERLINK_CLICK = "click", HYPERLINK_ENTER = "enter", HYPERLINK_LEAVE = "leave"}
local core = {db = {profile = profile}, Libs = {AceGUI = {}}, Components = {}, subscriptions = {}}
function core:GetModule(name) return assert(modules[name], name) end
function core:IsPratModuleEnabled() return self.prat end
function core:Localize(text) return text end
function core:Subscribe(event, callback) self.subscriptions[event] = callback end
function core:Dispatch(event, payload) self.subscriptions[event](payload) end
local constants = {EVENTS = events, ACTIONS = {
  HyperlinkClick = function(payload) return events.HYPERLINK_CLICK, payload end,
}}
local addon = {core, constants, {lower = string.lower}}
assert(loadfile("Glassy/Modules/TextProcessing.lua"))("Glassy", addon)
assert(loadfile("Glassy/Modules/ChatCopy.lua"))("Glassy", addon)
local tp, copy = modules.TextProcessing, modules.ChatCopy
local frame = {GetName = function() return "ChatFrame1" end}
local raw = "|cff00ff00Alice|r: |Hitem:123|h[Sword]|h || hi :) |Ticon:12|t |Kprotected|k"
local receivedAt = 1700000000
local stamp = os.date(profile.timestampFormat, receivedAt)
assert(tp:ProcessText(raw, frame, receivedAt) == stamp.." "..raw)
profile.timestampClickable = true
assert(tp:ProcessText(raw, frame, receivedAt) == "|Hglassytime:copy|h"..stamp.."|h "..raw)
profile.timestampColorEnabled, profile.timestampColor = true, {r = 1, g = 0, b = 0}
assert(tp:ProcessText(raw, frame, receivedAt) == "|cffff0000|Hglassytime:copy|h"..stamp.."|h|r "..raw)
assert(tp:ProcessText(raw, {GetName = function() return "ChatFrame2" end}, receivedAt) == raw)
core.prat = true
assert(tp:ProcessText(raw, frame, receivedAt) == raw)
core.prat = false
assert(tp:ProcessText(secret, frame, receivedAt) == secret)
profile.timestampsEnabled = false
assert(tp:ProcessText(raw, frame, receivedAt) == raw)
profile.timestampsEnabled = true

local copied, inserted, opened
function copy:ShowText(title, text) copied = {title, text} end
local active = {Insert = function(_, text) inserted = text end}
_G.ChatFrameUtil = {
  GetActiveWindow = function() return active end,
  OpenChat = function(text, chatFrame) opened = {text, chatFrame} end,
}
copy:CopyMessage(raw, frame, false)
assert(copied[1] == "Glassy: Copy message")
assert(copied[2] == "Alice: [Sword] | hi :)  <protected>")
copy:CopyMessage(raw, frame, true)
assert(inserted == "Alice: [Sword] || hi :)  <protected>")
active = nil
copy:CopyMessage(raw, frame, true)
assert(opened[1] == inserted and opened[2] == frame)
_G.ChatFrameUtil = nil
_G.ChatEdit_GetActiveWindow = function() return active end
_G.ChatFrame_OpenChat = function(text, chatFrame) opened = {text, chatFrame, "classic"} end
copy:CopyMessage("classic", frame, true)
assert(opened[1] == "classic" and opened[2] == frame and opened[3] == "classic")
local before = copied
copy:CopyMessage(secret, frame, false)
assert(copied == before)
copy:CopyMessage(nil, frame, false)
assert(copied == before)
copy:CopyMessage("2 |4apple:apples;", frame, false)
assert(copied[2] == "2 apples")

_G.hooksecurefunc = function() end
local fallback
_G.SetItemRef = function(...) fallback = {...} end
local shift = false
_G.IsShiftKeyDown = function() return shift end
assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", addon)
modules.Hyperlinks:OnInitialize()
modules.Hyperlinks:OnEnable()
local click = core.subscriptions[events.HYPERLINK_CLICK]
click({"glassytime:copy", stamp, "LeftButton", frame, "first"})
assert(copied[2] == "first" and fallback == nil)
shift = true
click({"glassytime:copy", stamp, "LeftButton", frame, "second"})
assert(opened[1] == "second" and opened[2] == frame)
_G.C_ChatInfo = {InChatMessagingLockdown = function () return true end}
click({"glassytime:copy", stamp, "LeftButton", frame, "locked"})
assert(copied[2] == "locked" and opened[1] == "second", "Shift-click during lockdown falls back to copying")
_G.C_ChatInfo = nil
shift = false
before = copied
click({"glassytime:copy", stamp, "RightButton", frame, raw})
assert(copied == before and fallback == nil)
core.prat = true
click({"glassytime:copy", stamp, "LeftButton", frame, raw})
assert(copied == before)
core.prat = false
profile.timestampClickable = false
click({"glassytime:copy", stamp, "LeftButton", frame, raw})
assert(copied == before)
profile.timestampClickable = true
click({"item:123", "[Sword]", "LeftButton", frame})
assert(fallback[1] == "item:123" and fallback[4] == frame)

-- Exercise the actual row click handler, including reused and clipped rows.
local function noop() end
core.Components.FadingFrameMixin = {Init = noop}
core.Components.GradientBackgroundMixin = {Init = noop}
_G.Mixin = function(object, ...)
  for _, mixin in ipairs({...}) do for key, value in pairs(mixin) do object[key] = value end end
  return object
end
local visible = true
local viewport = {IsMouseOver = function() return visible end}
local parent = {GetParent = function() return viewport end}
_G.CreateFrame = function()
  local object = {scripts = {}, text = {SetIndentedWordWrap = noop}, glassyTopAlpha = 1}
  function object:SetScript(event, callback) self.scripts[event] = callback end
  function object:GetAlpha() return 0 end
  function object:GetParent() return parent end
  for _, name in ipairs({"SetWidth", "SetGradientBackground", "DisableDrawLayer", "SetHyperlinksEnabled"}) do
    object[name] = noop
  end
  return object
end
assert(loadfile("Glassy/Components/MessageLine.lua"))("Glassy", addon)
local row = core.Components.CreateMessageLine(parent)
row.sourceFrame, row.sourceText = frame, "restored"
row.scripts.OnHyperlinkClick(row, "glassytime:copy", stamp, "LeftButton")
assert(copied[2] == "restored")
row.sourceText = "reused"
row.scripts.OnHyperlinkClick(row, "glassytime:copy", stamp, "LeftButton")
assert(copied[2] == "reused")
visible = false
row.scripts.OnHyperlinkClick(row, "glassytime:copy", stamp, "LeftButton")
assert(copied[2] == "reused")
print("Clickable timestamp checks passed")
