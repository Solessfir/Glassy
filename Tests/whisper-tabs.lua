-- Run from the repository root with Lua 5.1.
local secret = setmetatable({}, {})
canaccessvalue = function (value) return value ~= secret end
local delayed
C_Timer = {After = function (_, callback) delayed = callback end}

local function chatFrame(name, fields, lines)
  local frame = {name = name, lines = lines or {}, backfilled = {}}
  for key, value in pairs(fields) do frame[key] = value end
  function frame:GetNumMessages() return #self.lines end
  function frame:GetMessageInfo(index) return unpack(self.lines[index]) end
  function frame:BackFillMessage(text, r, g, b) self.backfilled[#self.backfilled + 1] = {text, r, g, b} end
  _G[name] = frame
  return frame
end

local lines = {}
for index = 1, 105 do lines[index] = {"line "..index, 1, 0.5, 1} end
lines[105] = {secret, 1, 1, 1}
chatFrame("ChatFrame1", {})
chatFrame("ChatFrame11", {isTemporary = true, inUse = true, chatType = "WHISPER", chatTarget = "Elowen"}, lines)
chatFrame("ChatFrame12", {isTemporary = true, inUse = true, chatType = "BN_WHISPER", chatTarget = "Friend"})
chatFrame("ChatFrame13", {isTemporary = true, inUse = false, chatType = "WHISPER", chatTarget = "Closed"})
chatFrame("ChatFrame14", {isTemporary = true, inUse = true, chatType = "WHISPER", chatTarget = secret})
CHAT_FRAMES = {"ChatFrame1", "ChatFrame11", "ChatFrame12", "ChatFrame13", "ChatFrame14"}

local module = {}
local shutdown
local core = {
  db = {profile = {keepWhisperTabs = true}, char = {},
    RegisterCallback = function (_, event, callback) assert(event == "OnDatabaseShutdown"); shutdown = callback end},
  GetModule = function () return module end,
}
assert(loadfile("Glassy/Modules/WhisperTabs.lua"))("Glassy", {core})
module:OnEnable()
shutdown()
local saved = core.db.char.whisperTabs
assert(#saved == 1 and saved[1].target == "Elowen", "Only open character whispers with readable targets are kept")
assert(#saved[1].lines == 99 and saved[1].lines[1][1] == "line 6" and saved[1].lines[99][1] == "line 104",
  "The newest 100 lines are read and secret lines are skipped")

-- After login the tab reopens once, and its saved lines are backfilled newest first.
local opened = {}
FCF_OpenTemporaryWindow = function (chatType, target, source, select)
  assert(chatType == "WHISPER" and source == nil and select == false, "Tabs reopen without stealing focus")
  opened[#opened + 1] = target
  return chatFrame("ChatFrame15", {isTemporary = true, inUse = true, chatType = "WHISPER", chatTarget = target})
end
CHAT_FRAMES = {"ChatFrame1"}
delayed()
assert(#opened == 1 and opened[1] == "Elowen")
local restored = _G.ChatFrame15.backfilled
assert(#restored == 99 and restored[1][1] == "line 104" and restored[99][1] == "line 6")
assert(core.db.char.whisperTabs == nil, "Restored tabs are not restored twice")

-- A whisper that reopened the tab first gets the saved lines without a second tab.
core.db.char.whisperTabs = {{target = "ELOWEN", lines = {{"earlier", 1, 1, 1}}}}
CHAT_FRAMES = {"ChatFrame15"}
module:Restore()
assert(#opened == 1 and restored[#restored][1] == "earlier", "An open tab is matched by name, ignoring case")

core.db.profile.keepWhisperTabs = false
shutdown()
assert(#core.db.char.whisperTabs == 0, "Disabled kept tabs save nothing")
print("PASS: whisper tabs persist with their readable history and reopen once")
