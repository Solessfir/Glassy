-- Run from the repository root: lua Tests/test-whisper-window-views.lua
_G.unpack = _G.unpack or table.unpack
local legacyScroll = arg and arg[1] == "legacy"
local frames = {}
local frame
frame = function(kind)
  local object = {kind = kind, scripts = {}, text = "", shown = true, messages = {}, offset = 0}
  function object:SetScript(event, handler) self.scripts[event] = handler end
  function object:HookScript(event, handler) self.scripts[event] = handler end
  function object:Show() self.shown = true end
  function object:Hide()
    self.shown = false
    if self.scripts.OnHide then self.scripts.OnHide(self) end
  end
  function object:IsShown() return self.shown end
  function object:SetText(text) self.text = text end
  function object:GetText() return self.text end
  function object:ClearFocus() self.focused = false end
  function object:HasFocus() return self.focused == true end
  function object:SetFocus() self.focused = true end
  function object:Insert(text) self.text = self.text..text end
  function object:SetShown(shown) if shown then self:Show() else self:Hide() end end
  function object:SetWidth(width) self.width = width end
  function object:SetHeight(height) self.height = height end
  function object:SetSize(width, height) self.width, self.height = width, height end
  function object:GetParent() return self.parent end
  function object:GetChildren()
    local children = {}
    for _, child in ipairs(frames) do
      if child.parent == self and child.kind ~= "FontString" and child.kind ~= "Texture" then
        children[#children + 1] = child
      end
    end
    return unpack(children)
  end
  function object:IsObjectType(kind) return self.kind == kind end
  function object:SetPoint(...) self.point = {...} end
  function object:GetWidth() return rawget(self, "width") or 400 end
  function object:GetVerticalScrollRange() return rawget(self, "range") or 0 end
  function object:GetVerticalScroll() return rawget(self, "scroll") or 0 end
  function object:SetVerticalScroll(scroll)
    self.scroll = math.max(0, math.min(scroll, self:GetVerticalScrollRange()))
    if self.scripts.OnVerticalScroll then self.scripts.OnVerticalScroll(self, self.scroll) end
  end
  function object:SetScrollChild(child) self.child = child end
  function object:UpdateScrollChildRect()
    self.range = math.max(0, self.child.height - 100)
    self:SetVerticalScroll(self:GetVerticalScroll())
  end
  function object:GetStringHeight() return 20 * math.max(1, math.ceil(#self.text / 60)) end
  function object:GetStringWidth() return #self.text * 6 end
  function object:CreateTexture() return frame("Texture") end
  function object:CreateFontString()
    local text = frame("FontString")
    text.parent = self
    return text
  end
  function object:SetEnabled(enabled) self.enabled = enabled end
  function object:AtBottom() return self.offset == 0 end
  function object:GetScrollOffset() return self.offset end
  if not legacyScroll then
    function object:SetOnScrollChangedCallback(callback) self.onScrollChanged = callback end
  end
  function object:SetScrollOffset(offset)
    self.offset = math.max(0, math.min(offset, math.max(0, #self.messages - 1)))
    if rawget(self, "onScrollChanged") then self.onScrollChanged(self, self.offset) end
    if self.scripts.OnMessageScrollChanged then self.scripts.OnMessageScrollChanged(self) end
  end
  function object:ScrollUp() self:SetScrollOffset(self.offset + 1) end
  function object:ScrollDown() self:SetScrollOffset(self.offset - 1) end
  function object:ScrollToBottom() self:SetScrollOffset(0) end
  function object:Clear() self.messages = {}; self:SetScrollOffset(0) end
  function object:AddMessage(text)
    self.messages[#self.messages + 1] = text
    if self.offset > 0 then self:ScrollUp() end
  end
  setmetatable(object, {__index = function (_, key)
    if key == "SetOnScrollChangedCallback" then return nil end
    return function () end
  end})
  frames[#frames + 1] = object
  return object
end

_G.CreateFrame = function(kind, name, parent, template)
  local object = frame(kind)
  object.name, object.parent = name, parent
  if template == "ScrollFrameTemplate" then
    object.ScrollBar = frame("Frame")
    function object.ScrollBar:SetHideIfUnscrollable(hide) self.hideWhenEmpty = hide end
  end
  return object
end
_G.CLOSE = "Close"
_G.UIParent = frame("Frame")
_G.ChatFrame1 = frame("Frame")
_G.GameTooltip = frame("Frame")
_G.date = os.date
local windows = {}
local conversations = {
  {name = "Alice-Realm", target = "Alice-Realm", unread = 2, messages = {{text = "Hi", outgoing = false, time = 1}}},
  {name = "Bob-Realm", target = "Bob-Realm", unread = 1, messages = {}},
}
local module = {active = false, sent = {}}
function module:IsActive() return self.active end
function module:GetConversations() return conversations end
function module:MarkRead(conversation) conversation.unread = 0 end
function module:Send(conversation, text)
  if self.reject then return false end
  self.sent[#self.sent + 1] = {conversation, text}
  return true
end
local core = {Libs = {AceGUI = {}}, db = {profile = {}}}
local skinned, skinnedRows = {}, {}
local ellesmere = {
  SkinWindow = function (_, window, parts) skinned[window] = parts end,
  SkinPart = function (_, part) skinnedRows[#skinnedRows + 1] = part end,
}
local dock = frame("Frame")
dock.state, dock.layouts, dock.reveals, dock.fades = {}, 0, 0, 0
function dock:ScheduleTabOrder() self.layouts = self.layouts + 1 end
function dock:Show() self.reveals = self.reveals + 1 end
function dock:UpdateAutomaticVisibility() self.fades = self.fades + 1 end
function core:Subscribe() end
function core:GetThemeColor() return {r = 1, g = 1, b = 1, a = 1} end
function core:Dispatch(action)
  self.action = action
  if self.menuObserver then self.menuObserver() end
end
function core:Localize(text) return text end
function core:GetModule(name)
  if name == "WhisperWindows" then return module end
  if name == "UIManager" then return {dock = dock} end
  if name == "Ellesmere" then return ellesmere end
  return {}
end
function core.Libs.AceGUI:Create()
  local window = {frame = frame("Frame"), content = frame("Frame")}
  local title, status, close = frame("Frame"), frame("Button"), frame("Button")
  title.parent, status.parent, close.parent = window.frame, window.frame, window.frame
  window.titletext, window.statustext = title:CreateFontString(), status:CreateFontString()
  close.obj = window
  close:SetText(CLOSE)
  window.close = close
  windows[#windows + 1] = window
  function window:SetTitle(text) self.titletext:SetText(text) end
  function window:Hide() self.frame:Hide() end
  function window:Show() self.frame:Show() end
  setmetatable(window, {__index = function () return function () end end})
  return window
end
local utils = {closeOnEscape = function () end}
local menuHooks = {}
_G.Menu = {ModifyMenu = function (tag, hook) menuHooks[tag] = hook end}
local linkHook
_G.ChatFrameUtil = {InsertLink = function () end}
_G.hooksecurefunc = function (_, key, hook) assert(key == "InsertLink"); linkHook = hook end
_G.GetTime = function () return 1 end
local constants = {DOCK_HEIGHT = 20, EVENTS = {UPDATE_CONFIG = "config"},
  ACTIONS = {HyperlinkClick = function(payload) return payload end}}
assert(loadfile("Glassy/Modules/WhisperWindowViews.lua"))("Glassy", {core, constants, utils})
module:UpdateViews()
assert(#windows == 0, "Disabled feature must not create UI")
module.active = true
local savedConversations = conversations
conversations = {}
module:UpdateViews()
local emptyWindow = windows[1]
local emptyLabel, inboxList
for _, part in ipairs(skinned[emptyWindow]) do
  if part.type == "FontString" and part.fontString.parent == emptyWindow.content then emptyLabel = part.fontString end
  if part.type == "ScrollFrame" then
    for _, object in ipairs(frames) do
      if rawget(object, "ScrollBar") == part.scrollbar then inboxList = object end
    end
  end
end
assert(emptyWindow.close.point[1] == "TOPRIGHT" and not emptyWindow.statustext:GetParent():IsShown())
assert(emptyLabel:IsShown() and emptyLabel:GetText():find("No whispers yet.", 1, true))
assert(not inboxList:IsShown() and inboxList.ScrollBar.hideWhenEmpty)
conversations = savedConversations
module:UpdateViews(conversations[1], true)
local inboxWindow, aliceWindow = windows[1], windows[2]
assert(aliceWindow.frame:IsShown() and not inboxWindow.frame:IsShown())
assert(conversations[1].unread == 0)
assert(inboxList:IsShown() and not emptyLabel:IsShown() and #skinnedRows == 2)
local inbox = dock.glassyWhisperInbox
assert(inbox:GetParent() == dock and inbox.point[2] == dock and inbox.point[3] == "LEFT",
  "The inbox belongs in the tab row, inside the chat bounds")
assert(inbox.height == constants.DOCK_HEIGHT and inbox.width == 28)
assert(inbox.count:GetText() == "1" and dock.reveals == 1 and dock.fades == 1)
inbox.scripts.OnEnter(inbox)
assert(GameTooltip:GetText() == "Whispers")
inbox.scripts.OnLeave(inbox)
local function controls(window)
  local reply, send, transcript
  for _, object in ipairs(frames) do
    if object.parent == window.content then
      if object.kind == "EditBox" then reply = object end
      if object.text == "Send" then send = object end
      if object.kind == "ScrollingMessageFrame" then transcript = object end
    end
  end
  return reply, send, transcript
end
local aliceReply, aliceSend, aliceTranscript = controls(aliceWindow)
assert(aliceReply and aliceSend and aliceTranscript and not aliceReply:HasFocus(), "Auto-open never steals focus")
local replyError, sendSkinned
for _, part in ipairs(skinned[aliceWindow]) do
  if part.type == "FontString" and part.fontString.parent == aliceWindow.content then replyError = part.fontString end
  if part.type == "Button" and part.button == aliceSend then sendSkinned = true end
end
assert(sendSkinned and replyError and not replyError:IsShown(), "Reply panels skin the Send button and show errors only when necessary")
assert(module:IsConversationPinned(conversations[1]), "An open conversation is protected from automatic eviction")
local menuClose
local menuRoot = {CreateDivider = function () end, CreateButton = function (_, label, callback)
  assert(label == "Close conversation"); menuClose = callback
end}
_G.SetItemRef = function () end
core.menuObserver = function () menuHooks.MENU_UNIT_PLAYER(nil, menuRoot) end
conversations[1].lineID = 321
module:ShowConversationMenu(conversations[1], aliceWindow.frame)
assert(core.action[1] == "player:Alice-Realm:321:WHISPER:Alice-Realm" and core.action[3] == "RightButton")
local closed
function module:CloseConversation(conversation) closed = conversation end
menuClose()
assert(closed == conversations[1], "Native person menus receive an explicit close action")
conversations[1].lineID = nil
module:ShowConversationMenu(conversations[1], aliceWindow.frame)
assert(core.action[1] == "player:Alice-Realm", "Restored conversations never reuse old report IDs")
local multiword = {name = "Native Friend-Moon Guard", target = "Native Friend-Moon Guard", lineID = 456}
module:ShowConversationMenu(multiword, aliceWindow.frame)
assert(core.action[1] == "player:Native Friend-Moon Guard:456:WHISPER:Native Friend-Moon Guard",
  "Native person menus preserve multi-word character and realm names")
core.menuObserver = nil
menuClose = nil
menuHooks.MENU_UNIT_PLAYER(nil, menuRoot)
assert(not menuClose, "Other native menus remain unchanged")
aliceTranscript.scripts.OnHyperlinkClick(aliceTranscript, "item:1", "Item", "LeftButton")
assert(core.action[1] == "item:1" and core.action[4] == _G.ChatFrame1)
aliceReply:SetText("Alice draft")
aliceReply.focused = true
module:UpdateViews(conversations[2], true)
assert(#windows == 2 and conversations[2].unread == 1, "Auto-open must defer while typing")
module:OpenConversation(conversations[2])
local bobWindow = windows[3]
local bobReply = controls(bobWindow)
assert(aliceWindow.frame:IsShown() and bobWindow.frame:IsShown(), "Each sender needs an independent window")
assert(conversations[2].unread == 0 and aliceReply:GetText() == "Alice draft")
assert(inbox.count:GetText() == "" and inbox.width == 20, "An empty badge leaves room for only the icon")
bobReply:SetText("Bob draft")
aliceWindow:Hide()
assert(module:IsConversationPinned(conversations[1]), "A closed window keeps its unfinished draft")
conversations[1].unread = 1
module:UpdateViews()
assert(conversations[1].unread == 1, "Hidden conversations must retain unread messages")
module:OpenConversation(conversations[1])
assert(aliceReply:GetText() == "Alice draft" and bobReply:GetText() == "Bob draft")
assert(#module.sent == 0, "Updates must not send a message")
assert(module:OpenConversation(conversations[1], true) and aliceReply:HasFocus(), "Explicit Whisper opens a focused reply")
linkHook("|Hitem:1|h[Test]|h")
linkHook("|Hitem:1|h[Test]|h")
assert(aliceReply:GetText() == "Alice draft|Hitem:1|h[Test]|h", "Shift-click inserts into the focused reply once")
aliceReply:SetText("Alice draft")
core.db.profile.whisperWindowsBubbles = true
module:UpdateViews()
local bubbleScroll
for _, object in ipairs(frames) do
  if object.parent == aliceWindow.content and object.kind == "ScrollFrame" then bubbleScroll = object end
end
assert(bubbleScroll:IsShown() and not aliceTranscript:IsShown(), "Bubble mode replaces the transcript")
bubbleScroll.scripts.OnMouseWheel(bubbleScroll, 1)
assert(bubbleScroll:GetVerticalScroll() == 0, "A short conversation has no bubble scrollback")
core.db.profile.whisperWindowsBubbles = false
module:UpdateViews()
assert(aliceTranscript:IsShown() and not bubbleScroll:IsShown())
module.reject = true
aliceSend.scripts.OnClick()
assert(aliceReply:GetText() == "Alice draft" and replyError:IsShown() and replyError:GetText():find("Unable to send", 1, true))
module.reject = false
aliceReply.scripts.OnEnterPressed()
assert(#module.sent == 1 and module.sent[1][1] == conversations[1] and module.sent[1][2] == "Alice draft")
assert(aliceReply:GetText() == "" and bobReply:GetText() == "Bob draft")
assert(not replyError:IsShown())

local alice = conversations[1]
local function append(text, trim)
  alice.messages[#alice.messages + 1] = {text = text, outgoing = false}
  if trim then table.remove(alice.messages, 1) end
  alice.unread = alice.unread + 1
end
alice.messages = {}
for index = 1, 99 do alice.messages[index] = {text = "History "..index, outgoing = false} end
module:UpdateViews(alice)
aliceTranscript:SetScrollOffset(40)
local viewed = aliceTranscript.messages[#aliceTranscript.messages - aliceTranscript:GetScrollOffset()]
append("New 101")
module:UpdateViews(alice)
assert(aliceTranscript:GetScrollOffset() == 41 and alice.unread == 1 and inbox.count:GetText() == "1",
  "An incoming transcript append retains unread and shifts the offset with the viewed message")
assert(aliceTranscript.messages[#aliceTranscript.messages - aliceTranscript:GetScrollOffset()] == viewed)
append("New 102", true)
module:UpdateViews(alice)
assert(aliceTranscript:GetScrollOffset() == 42 and alice.unread == 2,
  "Trimming the oldest transcript entry must preserve the viewed message")
assert(aliceTranscript.messages[#aliceTranscript.messages - aliceTranscript:GetScrollOffset()] == viewed)
aliceWindow:Hide()
append("New while hidden", true)
module:UpdateViews(alice)
module:OpenConversation(alice)
assert(alice.unread == 3 and aliceTranscript:GetScrollOffset() == 43,
  "Opening an existing panel in scrollback must retain its position and unread count")
module:UpdateViews()
assert(alice.unread == 3, "A general view refresh must not acknowledge scrollback")
while not aliceTranscript:AtBottom() do aliceTranscript.scripts.OnMouseWheel(aliceTranscript, -1) end
assert(alice.unread == 0 and inbox.count:GetText() == "", "Scrolling to the newest transcript message acknowledges unread")
aliceTranscript:SetScrollOffset(20)
append("Direct transcript scroll", true)
module:UpdateViews(alice)
aliceTranscript:ScrollToBottom()
assert(alice.unread == 0 and inbox.count:GetText() == "", "Native scroll callbacks also acknowledge unread")
aliceTranscript:SetScrollOffset(99)
alice.messages = {
  {text = "Oldest retained", outgoing = false},
  {text = "Newest retained", outgoing = false},
}
alice.unread = 1
module:UpdateViews(alice)
assert(aliceTranscript:GetScrollOffset() == 1 and alice.unread == 1,
  "An expired transcript anchor falls back to the oldest retained message")
aliceTranscript:ScrollToBottom()
for index = 3, 100 do alice.messages[index] = {text = "More history "..index, outgoing = false} end
alice.messages[1].text = string.rep("Wrapped bubble history ", 12)
module:UpdateViews(alice)

core.db.profile.whisperWindowsBubbles = true
module:UpdateViews()
local bubbleChild = bubbleScroll.child
local bubbleRows = {}
for _, object in ipairs(frames) do
  if object.parent == bubbleChild and object.kind == "Frame" then bubbleRows[#bubbleRows + 1] = object end
end
local firstHeight = bubbleRows[1].height + 6
local secondHeight = bubbleRows[2].height + 6
local firstViewedTop = -bubbleRows[10].point[5]
bubbleScroll:SetVerticalScroll(firstViewedTop + 9)
local bubbleOffset = bubbleScroll:GetVerticalScroll()
append("Bubble append", true)
module:UpdateViews(alice)
assert(bubbleScroll:GetVerticalScroll() == bubbleOffset - firstHeight and alice.unread == 1,
  "Bubble history truncation retains the viewed message and its pixel inset")
append("Bubble no trim")
module:UpdateViews(alice)
assert(bubbleScroll:GetVerticalScroll() == bubbleOffset - firstHeight and alice.unread == 2,
  "Bubble appends preserve scrollback and unread")
aliceWindow:Hide()
append("Bubble while hidden", true)
module:UpdateViews(alice)
module:OpenConversation(alice)
assert(bubbleScroll:GetVerticalScroll() == bubbleOffset - firstHeight - secondHeight and alice.unread == 3,
  "Reopening bubble scrollback must not mark unseen messages read")
bubbleScroll:SetVerticalScroll(bubbleScroll:GetVerticalScrollRange())
assert(alice.unread == 0 and inbox.count:GetText() == "", "Dragging the bubble scrollbar to newest acknowledges unread")
bubbleScroll.scripts.OnMouseWheel(bubbleScroll, 1)
append("Bubble wheel", true)
module:UpdateViews(alice)
assert(alice.unread == 1)
while bubbleScroll:GetVerticalScroll() < bubbleScroll:GetVerticalScrollRange() do
  bubbleScroll.scripts.OnMouseWheel(bubbleScroll, -1)
end
assert(alice.unread == 0, "The bubble mouse wheel acknowledges unread at newest")
bubbleScroll:SetVerticalScroll(10)
alice.messages = {{text = "Replacement", outgoing = false}}
alice.unread = 1
module:UpdateViews(alice)
assert(bubbleScroll:GetVerticalScroll() == 0 and alice.unread == 0,
  "If all viewed history expires, clamp to the remaining content and acknowledge only when it fits")

core.db.profile.whisperWindowsBubbles = false
module:UpdateViews()
aliceTranscript:SetScrollOffset(1)
table.remove(conversations, 1)
module:UpdateViews()
assert(not aliceWindow.frame:IsShown(), "Evicted senders must release their panel")
conversations[#conversations + 1] = {name = "Charlie-Realm", unread = 1, messages = {}}
module:OpenConversation(conversations[2])
assert(#windows == 3 and aliceWindow.frame:IsShown(), "New sender must reuse the evicted panel")
assert(aliceReply:GetText() == "", "Reused panels must not expose old drafts")
assert(aliceTranscript:AtBottom() and conversations[2].unread == 0, "Reused transcript panels start at newest")
conversations[2].messages = {}
for index = 1, 20 do conversations[2].messages[index] = {text = "Charlie "..index, outgoing = false} end
core.db.profile.whisperWindowsBubbles = true
module:UpdateViews()
assert(bubbleScroll:GetVerticalScroll() == bubbleScroll:GetVerticalScrollRange(), "Reused bubble panels start at newest")
inbox.scripts.OnClick()
assert(inboxWindow.frame:IsShown() and bobWindow.frame:IsShown())
local previousLayouts = dock.layouts
module.active = false
module:UpdateViews()
assert(not inboxWindow.frame:IsShown() and not inbox:IsShown())
assert(dock.layouts == previousLayouts + 1, "Disabling the inbox gives its space back to the tabs")
assert(not aliceWindow.frame:IsShown() and not bobWindow.frame:IsShown())
print("Whisper window view checks passed")
