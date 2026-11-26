-- Run from the repository root with Lua 5.1.
local secret = setmetatable({}, {__tostring = function () error("Secret value inspected") end})
canaccessvalue = function (value) return value ~= secret end
GetServerTime = function () return 12345 end
local modes = {whisperMode = "popout_and_inline", bnWhisperMode = "popout"}
GetCVar = function (name) return modes[name] end
SetCVar = function (name, value) modes[name] = value; return true end
local registered, handler = {}, nil
CreateFrame = function () return {
  RegisterEvent = function (_, event) registered[event] = true end,
  SetScript = function (_, event, callback) assert(event == "OnEvent"); handler = callback end,
} end
local shutdown, updateConfig
local module = {}
local core = {
  db = {profile = {}, char = {}, global = {}, RegisterCallback = function (_, event, callback)
    assert(event == "OnDatabaseShutdown"); shutdown = callback
  end},
  GetModule = function (_, name)
    if name == "TextProcessing" then return {IsMessageBlacklisted = function (_, text) return text == "blocked" end} end
    assert(name == "WhisperWindows")
    return module
  end,
  Subscribe = function (_, event, callback) assert(event == "UPDATE_CONFIG"); updateConfig = callback end,
}
assert(loadfile("Glassy/Modules/WhisperWindows.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "UPDATE_CONFIG"}}})
local updated, autoOpen
function module:UpdateViews(conversation, open) updated, autoOpen = conversation, open end
local function receive(event, text, name, id, account, guid)
  handler(nil, event, text, name, "", "", "", "", 0, 0, "", 0, id, guid, account)
end

module:OnEnable()
assert(not module:IsActive() and modes.whisperMode == "popout_and_inline")
core.db.char.whisperWindows = {{name = "preserved", messages = {}}}
shutdown()
assert(core.db.char.whisperWindows[1].name == "preserved", "A disabled startup preserves history it has not loaded")
core.db.char.whisperWindows = nil
receive("CHAT_MSG_WHISPER", "ignored", "Alice", 1)
assert(#module:GetConversations() == 0 and registered.CHAT_MSG_BN_WHISPER_INFORM)
core.db.profile.dedicatedWhisperWindows = true
core.db.profile.whisperWindowsAutoOpen = true
updateConfig("dedicatedWhisperWindows")
assert(module:IsActive() and modes.whisperMode == "inline" and modes.bnWhisperMode == "inline")
assert(core.db.global.whisperWindowModes.whisperMode == "popout_and_inline")
module:ApplySettings()
assert(core.db.global.whisperWindowModes.whisperMode == "popout_and_inline", "Applying twice preserves the actual native preference")

receive("CHAT_MSG_WHISPER", "hello", "Alice-Realm", 5, 0, "Player-1")
local alice = module:GetConversations()[1]
assert(alice.name == "Alice-Realm" and not alice.battleNet and alice.unread == 1)
assert(updated == alice and autoOpen and module:HasCapturedLine(5))
assert(alice.messages[1].text == "hello" and not alice.messages[1].outgoing and alice.messages[1].time == 12345)
receive("CHAT_MSG_WHISPER_INFORM", "reply", "ALICE-Realm", 6)
assert(#module:GetConversations() == 1 and #alice.messages == 2 and alice.unread == 1 and not autoOpen)
assert(alice.messages[2].outgoing)
module:MarkRead(alice)
assert(alice.unread == 0)
receive("CHAT_MSG_WHISPER", secret, "Alice", 7)
receive("CHAT_MSG_WHISPER", "secret sender", secret, 8)
receive("CHAT_MSG_BN_WHISPER", "no readable ID", "Friend", 9, secret)
receive("CHAT_MSG_WHISPER", "private recipient token", "|Kprivate|k", 9)
receive("CHAT_MSG_WHISPER", "blocked", "Other", 9)
assert(#module:GetConversations() == 1 and not module:HasCapturedLine(secret))
C_BattleNet = {GetAccountInfoByID = function (id) return id == 222 and {battleTag = "Friend#1234"} end}
receive("CHAT_MSG_BN_WHISPER", "Hidden Battle.net contact", "|Kprivate|k", 10, 111)
receive("CHAT_MSG_BN_WHISPER", "BN hello", "|Kprivate|k", 10, 222)
local friend = module:GetConversations()[2]
assert(friend.battleNet and friend.name == "Friend#1234" and friend.target == 222 and friend.unread == 1)

C_ChatInfo = {IsChatLineCensored = function (lineID) return lineID == 11 end}
receive("CHAT_MSG_WHISPER", "censored", "Other", 11)
assert(#module:GetConversations() == 2 and not module:HasCapturedLine(11))
C_ChatInfo.IsChatLineCensored = function () return secret end
receive("CHAT_MSG_WHISPER", "hidden censorship state", "Other", 12)
C_ChatInfo.IsChatLineCensored = function () error("unavailable") end
receive("CHAT_MSG_WHISPER", "unavailable censorship state", "Other", 13)
assert(#module:GetConversations() == 2)
C_ChatInfo.IsChatLineCensored = nil

local sent, draft
C_ChatInfo.SendChatMessage = function (...) sent = {...} end
C_BattleNet = {SendWhisper = function (...) sent = {...}; return true end}
assert(module:Send(alice, "outgoing") and sent[1] == "outgoing" and sent[2] == "WHISPER" and sent[4] == "Alice-Realm")
assert(#alice.messages == 2, "Only confirmed INFORM events create outgoing lines")
assert(module:Send(friend, "BN outgoing") and sent[1] == 222 and sent[2] == "BN outgoing")
C_BattleNet.SendWhisper = function () return false end
assert(not module:Send(friend, "declined"))
assert(not module:Send({target = "Injected"}, "outgoing") and not module:Send(alice, secret) and not module:Send(alice, "  "))
C_ChatInfo.InChatMessagingLockdown = function () return true end
ChatFrameUtil = {SendTellWithMessage = function (...) draft = {...} end}
assert(module:Send(alice, "native draft") and draft[1] == "Alice-Realm" and draft[2] == "native draft")
assert(not module:Send(friend, "restricted BN"))
ChatFrameUtil.GetActiveWindow = function () return {GetText = function () return "unsent native draft" end} end
assert(not module:Send(alice, "another draft"), "A reply must not replace an existing native draft")
C_ChatInfo.InChatMessagingLockdown = nil
C_ChatInfo.SendChatMessage = function () error("restricted") end
assert(not module:Send(alice, "failed"))

for index = 1, 110 do receive("CHAT_MSG_WHISPER", "line "..index, "Alice-Realm", index + 100) end
assert(#alice.messages == 100 and alice.messages[1].text == "line 11" and not module:HasCapturedLine(5))
receive("CHAT_MSG_WHISPER", "Token |Kprivate|k", "Alice-Realm", 999)
shutdown()
local saved = core.db.char.whisperWindows
assert(#saved == 1 and saved[1].name == "Alice-Realm" and #saved[1].messages == 100)
assert(saved[1].messages[100].text == "Token ???" and saved[1].messages[100].lineID == nil,
  "Only normal bounded history persists, without session IDs or account tokens")

-- A fresh module session retains the original native preference through reload.
module.conversations, module.capturedLines, module.restored = nil, {}, nil
module:ApplySettings()
alice = module:GetConversations()[1]
assert(#module:GetConversations() == 1 and #alice.messages == 100 and alice.unread == 0)
module:ApplySettings()
assert(#alice.messages == 100 and core.db.char.whisperWindows == nil, "Saved messages restore only once")
core.db.profile.dedicatedWhisperWindows = false
updateConfig("dedicatedWhisperWindows")
assert(modes.whisperMode == "popout_and_inline" and modes.bnWhisperMode == "popout" and not module:IsActive())
assert(next(core.db.global.whisperWindowModes) == nil)
assert(not module:Send(alice, "disabled"))
assert(not module:HasCapturedLine(999), "Disabling immediately relinquishes native rendering")
shutdown()
assert(#core.db.char.whisperWindows == 1 and #core.db.char.whisperWindows[1].messages == 100,
  "Turning off dedicated windows retains their transcript while history is enabled")
core.db.profile.dedicatedWhisperWindows = true
updateConfig("dedicatedWhisperWindows")
core.db.profile.saveChatHistory = false
updateConfig("saveChatHistory")
shutdown()
assert(#core.db.char.whisperWindows == 0, "Disabling history clears persisted transcripts")

for index = 1, 60 do receive("CHAT_MSG_WHISPER", "hello", "Contact"..index, 2000 + index) end
assert(#module:GetConversations() == 50 and not module:HasCapturedLine(999) and not module:HasCapturedLine(2001))
modes.whisperMode = "popout"
core.db.profile.dedicatedWhisperWindows = false
module:ApplySettings()
assert(modes.whisperMode == "popout", "Disabling preserves a native preference changed outside Glassy")

core.db.profile.dedicatedWhisperWindows = true
module:ApplySettings()
core.db.profile.dedicatedWhisperWindows = false
local nativeWrite = SetCVar
SetCVar = function () return false end
module:ApplySettings()
assert(core.db.global.whisperWindowModes.whisperMode == "popout", "A failed restoration retains the original mode for retry")
SetCVar = nativeWrite
module:ApplySettings()
assert(modes.whisperMode == "popout" and next(core.db.global.whisperWindowModes) == nil)

-- Unsupported Classic CVars are never written, and absent secret APIs remain supported.
canaccessvalue = nil
modes.bnWhisperMode = nil
core.db.profile.dedicatedWhisperWindows = true
module:ApplySettings()
receive("CHAT_MSG_WHISPER", "Classic", "ClassicFriend", 3000)
assert(module:GetConversations()[50].name == "ClassicFriend" and modes.bnWhisperMode == nil)
print("PASS: whisper conversations, safe capture, bounded persistence, CVar restoration and sending")
