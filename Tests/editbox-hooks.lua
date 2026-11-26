-- Run from the repository root with Lua 5.1 and the bundled libraries available.
local editBoxFile, hookFile = ...
strmatch = string.match
issecurevariable = function () return false end
dofile("libs/LibStub/LibStub.lua")
dofile(hookFile or "libs/AceHook-3.0/AceHook-3.0.lua")
local AceHook = LibStub("AceHook-3.0")
local Core = {Libs = {AceHook = AceHook, LibEasing = {}}, Components = {}}
local Constants = {ACTIONS = {}, EVENTS = {}}
ChatFrameUtil = {}
local nativeHandledTab
ChatEdit_CustomTabPressed = function () return nativeHandledTab end

local function newEditBox()
  local scripts = {}
  local nativeChatFrame = {shown = false}
  return {
    parent = nativeChatFrame,
    chatFrame = nativeChatFrame,
    SetParent = function (self, parent) self.parent = parent end,
    GetParent = function (self) return self.parent end,
    IsVisible = function (self) return self.shown and self.parent.shown end,
    hooks = {external = true},
    GetScript = function (_, name) return scripts[name] end,
    HasScript = function () return true end,
    HookScript = function (_, name, callback)
      local previous = scripts[name]
      scripts[name] = function (...)
        if previous then previous(...) end
        callback(...)
      end
    end,
    Show = function (self) self.shown = true end,
  }
end

Mixin = function (object, ...)
  for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do object[key] = value end
  end
  return object
end

-- Isolate hook ownership from visual initialization, which needs the game renderer.
Core.Components.GradientBackgroundMixin = {
  Init = function (object) object.Init = function () end end,
}
assert(loadfile(editBoxFile or "Glassy/Components/EditBox.lua"))("Glassy", {Core, Constants, {}})
assert(loadfile("Glassy/Components/EditBoxNative.lua"))("Glassy", {Core, Constants, {super = function () end}})
assert(type(Core.Components.EditBoxMixin.Init) == "function", "EditBox native integration did not load")

Core.db = {profile = {
  editBoxAnchor = {position = "BELOW", yOfs = 0},
  editBoxBackgroundColor = {a = 0.4},
  editBoxMessageSeparatorColor = {a = 0},
}}

local typed = "Hello Mi"
local cursor = #typed
local pratNames
Core.IsPratModuleEnabled = function (_, name) return name == "PlayerNames" and pratNames end
Core.GetModule = function ()
  return {CompletePlayerName = function (_, prefix) if prefix == "Mi" then return "Mira" end end}
end
local entry = {
  glassyEditBoxInitialized = true,
  GetText = function () return typed end,
  GetCursorPosition = function () return cursor end,
  SetText = function (_, text) typed = text end,
  SetCursorPosition = function (_, index) cursor = index end,
}
Core.db.profile.completePlayerNames = true
nativeHandledTab = true
assert(ChatEdit_CustomTabPressed(entry) and typed == "Hello Mi", "Native autocomplete takes priority")
nativeHandledTab = false
pratNames = true
assert(not ChatEdit_CustomTabPressed(entry) and typed == "Hello Mi", "Prat autocomplete takes priority")
pratNames = false
assert(ChatEdit_CustomTabPressed(entry) and typed == "Hello Mira " and cursor == #typed)
typed, cursor = "/w Mi", 5
assert(not ChatEdit_CustomTabPressed(entry) and typed == "/w Mi", "Native slash autocomplete stays in charge")
local editBoxLayout = Mixin({glassyEntryVisible = false, GetHeight = function () return 24 end}, Core.Components.EditBoxMixin)
assert(editBoxLayout:GetReusableMessageHeight() == 24, "Message area did not reclaim the full hidden edit-box height")

for _, pratFirst in ipairs({false, true}) do
  ChatFrame1EditBox = newEditBox()
  local nativeHookScript, externalHooks = ChatFrame1EditBox.HookScript, ChatFrame1EditBox.hooks
  local prat, calls = AceHook:Embed({}), 0
  local function installPrat()
    prat:SecureHookScript(ChatFrame1EditBox, "OnTextChanged", function () calls = calls + 1 end)
  end
  if pratFirst then installPrat() end
  local nativeChatFrame = ChatFrame1EditBox.chatFrame
  local glassyParent = {shown = true}
  local editBox = Core.Components.CreateEditBox(glassyParent)
  assert(editBox:GetParent() == glassyParent, "The input still inherits the hidden native chat frame")
  assert(editBox.chatFrame == nativeChatFrame, "The input lost its native chat channel association")
  assert(editBox.HookScript == nativeHookScript, "Glassy replaced the native HookScript method")
  assert(editBox.hooks == externalHooks, "Glassy changed another addon's hook storage")
  assert(editBox.glassyHooks and editBox.glassyHooks ~= editBox, "Glassy needs a separate hook owner")
  if not pratFirst then installPrat() end
  editBox:GetScript("OnTextChanged")(editBox)
  assert(calls == 1, "Prat's secure script hook did not run")
  prat:UnhookAll()
  editBox:GetScript("OnTextChanged")(editBox)
  assert(calls == 1, "Prat's hook was not disabled")
  editBox.glassyHooks:RawHook(editBox, "Show", function (frame)
    editBox.glassyHooks.hooks[frame].Show(frame)
  end, true)
  editBox:Show()
  assert(editBox.shown, "Glassy's raw hook lost the original method")
  assert(editBox:IsVisible(), "The input is invisible while the original chat frame is hidden")
  nativeChatFrame.shown = true
  nativeChatFrame.shown = false
  assert(editBox:IsVisible(), "Switching native chat tabs hid the input")
  glassyParent.shown = false
  assert(not editBox:IsVisible(), "The input should follow the Glassy container's visibility")
  editBox.glassyHooks:UnhookAll()
end
-- A chat shortcut pressed in the box toggles: when the switch leaves an empty box in the same chat, it closes.
local escaped, box
-- Mirrors Blizzard's redirects: Party goes to Instance in a dungeon group, Reply to a whisper to the last teller.
local REDIRECTS = {PARTY = "INSTANCE_CHAT", REPLY = "WHISPER"}
local function chatBox(chatType, channel, tell, text)
  local b
  b = Mixin({
    GetChatType = function () return chatType end,
    GetChannelTarget = function () return channel or 0 end,
    GetTellTarget = function () return tell end,
    GetText = function () return text or "" end,
    GetScript = function (_, name) return name == "OnEscapePressed" and function () escaped = true end end,
    ProcessChatType = function (_, _, target)
      if target == "REPLY" then
        if not ChatFrameUtil.GetLastTellTarget() then return true end
        tell = "Bob"
      end
      chatType = REDIRECTS[target] or target
      return true
    end,
    HandleChatType = function (_, _, command)
      local joined = tonumber(command:sub(2)) <= 3
      if joined then chatType, channel = "CHANNEL", tonumber(command:sub(2)) end
      return joined
    end,
  }, Core.Components.EditBoxMixin)
  escaped = false
  return b
end
local function check(b, target, closes, message)
  b:SwitchChat(target, true)
  assert(escaped == closes, message)
  return b
end
check(chatBox("GUILD"), "GUILD", true, "The same chat shortcut did not close the open box")
check(chatBox("GUILD", nil, nil, "brb"), "GUILD", false, "The same chat shortcut threw away a draft")
assert(check(chatBox("GUILD"), "PARTY", false, "Another chat shortcut closed the box"):GetChatType() == "INSTANCE_CHAT")
check(chatBox("INSTANCE_CHAT"), "PARTY", true, "Party did not close a box Blizzard redirected to the instance")
check(chatBox("CHANNEL", 2), 2, true, "The same channel shortcut did not close the open box")
assert(check(chatBox("CHANNEL", 2), 3, false, "Another channel shortcut closed the box"):GetChannelTarget() == 3)
check(chatBox("CHANNEL", 2), 5, false, "A shortcut for a channel not joined closed the box")
ChatFrameUtil.GetLastTellTarget = function () end
check(chatBox("SAY"), "REPLY", false, "Reply with no whispers yet closed the box")
ChatFrameUtil.GetLastTellTarget = function () return "Bob", "WHISPER" end
check(chatBox("WHISPER", nil, "Bob"), "REPLY", true, "Reply did not close a box already whispering the last teller")
check(chatBox("WHISPER", nil, "Ann"), "REPLY", false, "Reply closed a box whispering someone else")
-- The binding runs only while no box has focus, so it opens or resumes the box and never closes it.
box = chatBox("GUILD")
ChatFrameUtil.GetActiveWindow = function () return box end
GlassySwitchChat("GUILD")
assert(not escaped, "The binding closed the box instead of resuming it")

print("PASS: native hooks preserved; Prat works in both load orders; input follows Glassy visibility and keeps its chat association.")
