-- Run from the repository root with Lua 5.1.
local pending, subscriptions = {}, {}
C_Timer = {After = function (_, callback) pending[#pending + 1] = callback end}
local function flush()
  local callbacks = pending
  pending = {}
  for _, callback in ipairs(callbacks) do callback() end
end
local function frame(parent)
  local object = {parent = parent, points = {}, width = 400, height = 180, shown = true, level = 1}
  function object:GetAlpha() return self.alpha or 1 end
  function object:SetAlpha(value) self.alpha = value end
  function object:GetParent() return self.parent end
  function object:SetParent(value) self.parent = value end
  function object:GetName() return self.name end
  function object:SetPoint(...) self.points[#self.points + 1] = {...} end
  function object:GetPoint(index) return unpack(self.points[index]) end
  function object:GetNumPoints() return #self.points end
  function object:ClearAllPoints() self.points = {} end
  function object:SetSize(width, height) self.width, self.height = width, height end
  function object:GetSize() return self.width, self.height end
  function object:IsIgnoringParentAlpha() return self.ignoreAlpha or false end
  function object:SetIgnoreParentAlpha(value) self.ignoreAlpha = value end
  function object:GetFrameLevel() return self.level end
  function object:SetFrameLevel(value) self.level = value end
  function object:GetFrameStrata() return self.strata or "MEDIUM" end
  function object:SetFrameStrata(value) self.strata = value end
  function object:Show()
    if self.shown then return end
    self.shown = true
    if self.onShow then self.onShow() end
  end
  function object:HookScript(event, callback)
    assert(event == "OnShow")
    self.onShow = callback
  end
  function object:Hide() self.shown = false end
  function object:IsShown() return self.shown end
  function object:QuickHide() self:Hide() end
  function object:RegisterEvent(event) self.event = event end
  function object:UnregisterEvent(event) assert(self.event == event) end
  function object:SetScript(_, callback) self.callback = callback end
  return object
end
CreateFrame = function (_, _, parent) return frame(parent) end
hooksecurefunc = function (object, method, callback)
  if type(object) == "string" then callback, method, object = method, object, _G end
  local original = object[method]
  object[method] = function (...)
    original(...)
    callback(...)
  end
end
ChatFrame2 = frame()
GENERAL_CHAT_DOCK = {}
function FCFDock_SelectWindow(dock, selected) dock.selected = selected end
local manager = {}
local core = {
  db = {profile = {}},
  GetModule = function () return manager end,
  Subscribe = function (_, event, callback) subscriptions[event] = callback end,
}
assert(loadfile("Glassy/Modules/DetailsEmbed.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "config"}}})
local chat = frame()
chat.name, chat.isDocked = "ChatFrame3", true
ChatFrame3Background = frame(chat)
local background = ChatFrame3Background
local renderer = frame()
renderer.chatFrame, renderer.config = chat, {width = 500, height = 240, overflowHeight = 60}
renderer.state = {scrollAtBottom = false}
renderer.viewport, renderer.overlay = frame(renderer), frame(renderer)
renderer.level = 5
renderer.hooks = {[chat] = {Show = function (value) value:Show() end, Hide = function (value) value:Hide() end}}
local window = {active = true, slidingMessageFrame = renderer}
manager.GetChatWindow = function (_, value) if value == chat then return window end end
GENERAL_CHAT_DOCK.selected = chat
local first, second = frame(chat), frame(chat)
local firstRows, secondRows = frame(first), frame(second)
first.strata, firstRows.strata = "LOW", "LOW"
local embedCalls = 0
local instances = {{baseframe = first, rowframe = firstRows}, {baseframe = second, rowframe = secondRows}}
local function nativeEmbed(single)
  for index, value in ipairs({first, second}) do
    value:ClearAllPoints()
    value:SetParent((index == 1 or not single) and chat or nil)
  end
  first:SetParent(chat)
  first:SetPoint("TOPLEFT", background, "TOPLEFT", 0, -13)
  if single then
    first:SetPoint("BOTTOMRIGHT", background, "BOTTOMRIGHT", 6, 14)
  else
    second:SetParent(chat)
    second:SetPoint("TOPRIGHT", background, "TOPRIGHT", 6, -13)
    first:SetSize(203, 153)
    second:SetSize(203, 153)
  end
end

manager:InitializeDetailsEmbed()
assert(not manager.detailsEmbedState, "Missing Details must leave chat untouched")
Details = {
  chat_tab_embed = {enabled = true, single_window = true},
  chat_tab_embed_onframe = chat,
  GetInstance = function (_, index) return instances[index] end,
  chat_embed = {
    DoEmbed = function ()
      embedCalls = embedCalls + 1
      Details.chat_tab_embed_onframe = chat
      nativeEmbed(Details.chat_tab_embed.single_window)
    end,
    ReleaseEmbed = function ()
      first:ClearAllPoints()
      first:SetParent(nil)
      first:SetPoint("CENTER", background, "CENTER", 12, 30)
      first:SetSize(321, 123)
    end,
    SetTabSettings = function () end,
  },
}
nativeEmbed(true)
manager.detailsEmbedEvents.callback()
assert(not renderer.detailsEmbedHost, "Late addon load must schedule adoption")
flush()
assert(not renderer.detailsEmbedHost and renderer.viewport:IsShown(), "Unset integration must leave chat untouched")
assert(first.points[1][2] == background and not first.ignoreAlpha, "Unset integration must preserve the native embed")
core.db.profile.detailsChatEmbed = false
subscriptions.config("detailsChatEmbed")
assert(not renderer.detailsEmbedHost, "Disabled integration must leave chat untouched")
core.db.profile.detailsChatEmbed = true
subscriptions.config("detailsChatEmbed")
local host = renderer.detailsEmbedAnchor
assert(renderer.detailsEmbedHost and not renderer.viewport:IsShown() and not renderer.overlay:IsShown())
assert(first:GetParent() == chat and first.ignoreAlpha and chat:IsShown(), "Keep Details native parent and selected visibility")
assert(host:GetParent() == renderer and host.width == 500 and host.height == 240, "Host must exclude animated overflow")
assert(first.points[1][2] == host and first.points[1][5] == -13 and first.points[2][4] == 6)
assert(first.level == 6, "Embedded windows must remain above the Glassy background")
assert(first.strata == "MEDIUM" and firstRows.strata == "MEDIUM" and firstRows.level == 6,
  "Details explicitly layered rows must also be above the Glassy background")
assert(not second.ignoreAlpha, "Single mode must leave the second window untouched")

renderer.config.height = 260
manager:ResizeDetailsEmbed(renderer)
assert(host.height == 260 and first.height == 180, "Two-anchor single mode must retain native sizing")
core.db.profile.detailsChatEmbed = false
subscriptions.config("detailsChatEmbed")
assert(not renderer.detailsEmbedHost and renderer.viewport:IsShown() and not chat:IsShown())
assert(first.points[1][2] == background and first.points[2][5] == 14 and not first.ignoreAlpha and first.level == 1)
assert(first.strata == "LOW" and firstRows.strata == "LOW" and firstRows.level == 1 and renderer.overlay:IsShown(),
  "Releasing must restore native layers and the existing scrollback overlay")
core.db.profile.detailsChatEmbed = true
subscriptions.config("detailsChatEmbed")
assert(renderer.detailsEmbedHost and chat:IsShown(), "Enabling an already-selected host must show its native parent")

Details.chat_tab_embed.single_window = false
local general = frame()
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, general)
Details.chat_embed:DoEmbed()
assert(#pending == 1)
flush()
chat:Show()
assert(not first.ignoreAlpha and not second.ignoreAlpha,
  "Startup embeds inherit the unselected native chat frame's zero alpha even when it is shown")
assert(not first:IsShown() and not second:IsShown(), "Unselected meter windows are explicitly hidden")
first:Show()
assert(not first:IsShown(), "Details cannot reveal an embedded window on the wrong tab after startup")
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, chat)
assert(first:GetParent() == chat and second:GetParent() == chat and first.ignoreAlpha and second.ignoreAlpha)
assert(first:IsShown() and second:IsShown(), "Selecting Damage restores the hidden windows")
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, general)
assert(not first.ignoreAlpha and not second.ignoreAlpha, "Switching tabs removes both meters from view")
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, chat)
assert(first.width == 253 and second.width == 253 and first.height == 233 and second.height == 233,
  "Dual panels must retain native offsets while taking half the width delta and all the height delta")
renderer.config.width, renderer.config.height = 600, 300
manager:ResizeDetailsEmbed(renderer)
assert(first.width == 303 and second.width == 303 and first.height == 273, "Dual resizing must not accumulate deltas")
core.db.profile.detailsChatEmbed = false
subscriptions.config("detailsChatEmbed")
assert(first.width == 203 and first.height == 153 and second.width == 203 and not second.ignoreAlpha)

core.db.profile.detailsChatEmbed = true
subscriptions.config("detailsChatEmbed")
Details.chat_embed:ReleaseEmbed()
flush()
assert(first:GetParent() == nil and first.points[1][1] == "CENTER" and first.width == 321 and first.height == 123,
  "A native release must keep its new position and size")
assert(not first.ignoreAlpha, "Release must restore inherited alpha even after native reparenting")
assert(first.strata == "LOW" and firstRows.strata == "LOW", "Release must restore layers even after native reparenting")
assert(renderer.detailsEmbedHost, "One remaining stock window can continue to host")
second:ClearAllPoints()
second:SetPoint("CENTER", background, "CENTER", 50, 50)
manager:RefreshDetailsEmbed()
assert(not renderer.detailsEmbedHost and second.points[1][4] == 50 and not second.ignoreAlpha,
  "A native re-anchor must not be overwritten or adopted as a stock embed")

Details.chat_tab_embed.single_window = true
nativeEmbed(true)
window.secondaryGroup = {}
manager:RefreshDetailsEmbed()
assert(not renderer.detailsEmbedHost, "Secondary groups must remain untouched")
window.secondaryGroup = nil
window.temporary = true
manager:RefreshDetailsEmbed()
assert(not renderer.detailsEmbedHost, "Temporary windows must remain untouched")
window.temporary = nil
chat.isDocked = false
manager:RefreshDetailsEmbed()
assert(not renderer.detailsEmbedHost, "Detached chats must remain untouched")
chat.isDocked = true
manager:RefreshDetailsEmbed()
renderer.state.scrollAtBottom = true
chat.isDocked = false
manager:RefreshDetailsEmbed()
assert(chat:IsShown() and renderer.viewport:IsShown(), "Undocking must restore native standalone visibility")
assert(not renderer.overlay:IsShown(), "Releasing at the latest message must not revive the scrollback overlay")

chat.isDocked = true
nativeEmbed(true)
first.GetPoint = false
manager:RefreshDetailsEmbed()
assert(not renderer.detailsEmbedHost, "Unsupported Details frames must be skipped")
first.GetPoint = second.GetPoint
Details.chat_tab_embed_onframe = nil
Details.chat_tab_embed.single_window = false
Details.chat_tab_embed.tab_name = "DAMAGE"
Details.chat_embed.GetTab = function (_, name)
  if name == "DAMAGE" then return chat end
end
UIParent = frame()
first:SetParent(UIParent)
second:SetParent(UIParent)
second:SetAlpha(0.75)
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, general)
local previousEmbedCalls = embedCalls
ChatFrame1 = chat
manager:RecoverDetailsStartupEmbed()
assert(embedCalls == previousEmbedCalls, "Startup recovery must never embed into General")
ChatFrame1 = general
manager.detailsEmbedEvents.callback(nil, "PLAYER_ENTERING_WORLD")
assert(first:GetAlpha() == 0 and second:GetAlpha() == 0, "Standalone meters must be transparent during startup")
flush()
assert(first:GetAlpha() == 1 and second:GetAlpha() == 0.75, "Startup must restore the original meter alpha")
assert(embedCalls == previousEmbedCalls + 1 and Details.chat_tab_embed_onframe == chat)
assert(renderer.detailsEmbedHost and not first:IsShown() and not second:IsShown(),
  "Startup recovery must attach both meters without covering General")
manager:RecoverDetailsStartupEmbed()
assert(embedCalls == previousEmbedCalls + 1, "An existing native embed must not be retried")
FCFDock_SelectWindow(GENERAL_CHAT_DOCK, chat)
assert(first:IsShown() and second:IsShown(), "Recovered meters must show on the Damage tab")
print("Details embed tests passed")
