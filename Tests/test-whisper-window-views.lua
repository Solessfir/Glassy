-- Run from the repository root: lua Tests/test-whisper-window-views.lua
_G.unpack = _G.unpack or table.unpack
local frames = {}
local function frame(kind)
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
  function object:SetFocus() error("Opening the panel must not steal focus") end
  function object:SetEnabled(enabled) self.enabled = enabled end
  function object:AtBottom() return self.offset == 0 end
  function object:GetScrollOffset() return self.offset end
  function object:SetScrollOffset(offset) self.offset = offset end
  function object:ScrollToBottom() self.offset = 0 end
  function object:Clear() self.messages = {} end
  function object:AddMessage(text) self.messages[#self.messages + 1] = text end
  setmetatable(object, {__index = function () return function () end end})
  frames[#frames + 1] = object
  return object
end

_G.CreateFrame = function(kind, name, parent)
  local object = frame(kind)
  object.name, object.parent = name, parent
  return object
end
_G.UIParent = frame("Frame")
_G.ChatFrame1 = frame("Frame")
_G.date = os.date
local windows = {}
local conversations = {
  {name = "Alice-Realm", unread = 2, messages = {{text = "Hi", outgoing = false, time = 1}}},
  {name = "Bob-Realm", unread = 1, messages = {}},
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
local core = {Libs = {AceGUI = {}}}
function core:Dispatch(action) self.action = action end
function core:Localize(text) return text end
function core:GetModule(name)
  if name == "WhisperWindows" then return module end
  if name == "Ellesmere" then return {SkinWindow = function () end} end
  return {}
end
function core.Libs.AceGUI:Create()
  local window = {frame = frame("Frame"), content = frame("Frame")}
  windows[#windows + 1] = window
  function window:SetStatusText(text) self.status = text end
  function window:Hide() self.frame:Hide() end
  function window:Show() self.frame:Show() end
  setmetatable(window, {__index = function () return function () end end})
  return window
end
local utils = {closeOnEscape = function () end}
local constants = {ACTIONS = {HyperlinkClick = function(payload) return payload end}}
assert(loadfile("Glassy/Modules/WhisperWindowViews.lua"))("Glassy", {core, constants, utils})
module:UpdateViews()
assert(#windows == 0, "Disabled feature must not create UI")
module.active = true
module:UpdateViews(conversations[1], true)
local inboxWindow, aliceWindow = windows[1], windows[2]
assert(aliceWindow.frame:IsShown() and not inboxWindow.frame:IsShown())
assert(conversations[1].unread == 0)
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
assert(aliceReply and aliceSend and aliceTranscript)
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
bobReply:SetText("Bob draft")
aliceWindow:Hide()
conversations[1].unread = 1
module:UpdateViews()
assert(conversations[1].unread == 1, "Hidden conversations must retain unread messages")
module:OpenConversation(conversations[1])
assert(aliceReply:GetText() == "Alice draft" and bobReply:GetText() == "Bob draft")
assert(#module.sent == 0, "Updates must not send a message")
module.reject = true
aliceSend.scripts.OnClick()
assert(aliceReply:GetText() == "Alice draft" and aliceWindow.status:find("Unable to send", 1, true))
module.reject = false
aliceReply.scripts.OnEnterPressed()
assert(#module.sent == 1 and module.sent[1][1] == conversations[1] and module.sent[1][2] == "Alice draft")
assert(aliceReply:GetText() == "" and bobReply:GetText() == "Bob draft")
table.remove(conversations, 1)
module:UpdateViews()
assert(not aliceWindow.frame:IsShown(), "Evicted senders must release their panel")
conversations[#conversations + 1] = {name = "Charlie-Realm", unread = 1, messages = {}}
module:OpenConversation(conversations[2])
assert(#windows == 3 and aliceWindow.frame:IsShown(), "New sender must reuse the evicted panel")
assert(aliceReply:GetText() == "", "Reused panels must not expose old drafts")
local inbox
for _, object in ipairs(frames) do
  if object.name == "GlassyWhisperInbox" then inbox = object end
end
assert(inbox)
inbox.scripts.OnClick()
assert(inboxWindow.frame:IsShown() and bobWindow.frame:IsShown())
module.active = false
module:UpdateViews()
assert(not inboxWindow.frame:IsShown() and not inbox:IsShown())
assert(not aliceWindow.frame:IsShown() and not bobWindow.frame:IsShown())
print("Whisper window view checks passed")
