-- Run from the repository root with Lua 5.1.
local function noop() end
local secretText, secretNumber = {}, {}
canaccessvalue = function (value) return value ~= secretText and value ~= secretNumber end
GetServerTime = function () return 10000 end
GetTime = function () return 100 end
date = os.date
local delayed, shutdown
C_Timer = {After = function (delay, callback) assert(delay == 2); delayed = callback end}

local history, uiManager = {}, {state = {windows = {}}, QueueFrameForUpdate = noop}
local capturedWhispers = {}
local whisperWindows = {HasCapturedLine = function (_, id) return capturedWhispers[id] end}
local pratHistory = false
local core = {
  Components = {}, Libs = {AceHook = {}, LibEasing = {}},
  defaults = {profile = {scrollbackLines = 500}},
  db = {profile = {scrollbackLines = 4}, char = {}, RegisterCallback = function (_, event, callback)
    assert(event == "OnDatabaseShutdown"); shutdown = callback
  end},
  GetModule = function (_, name)
    if name == "ChatHistory" then return history end
    if name == "UIManager" then return uiManager end
    if name == "WhisperWindows" then return whisperWindows end
    return {IsMessageBlacklisted = function (_, text) return text == "blocked" end}
  end,
  IsPratModuleEnabled = function (_, name) assert(name == "History"); return pratHistory end,
}
local constants, utils = {ENV = "retail", EVENTS = {}}, {hookPresentation = noop}
for _, path in ipairs({"Components/SlidingMessageFrame", "Components/SlidingMessageFrameNative", "Modules/ChatHistory"}) do
  assert(loadfile("Glassy/"..path..".lua"))("Glassy", {core, constants, utils})
end

local function line(text, receivedAt)
  return {message = text, r = 1, g = 0.5, b = 0, serverTime = receivedAt}
end

local function savedLine(text, receivedAt)
  return {text, 1, 0.5, 0, receivedAt}
end

local function newWindow(name, entries, fields)
  local frame = {entries = entries or {}, dirty = 0, isDocked = false}
  for key, value in pairs(fields or {}) do frame[key] = value end
  _G[name] = frame
  function frame:GetName() return name end
  function frame:GetNumMessages() return #self.entries end
  function frame:GetMessageInfo(index)
    local entry = self.entries[index]
    if entry then return entry.message, entry.r, entry.g, entry.b, nil, nil, nil, entry.event, entry.eventArgs end
  end
  function frame:PackageEntry(text, red, green, blue)
    return {message = text, r = red, g = green, b = blue, timestamp = GetTime()}
  end
  function frame:MarkDisplayDirty() self.dirty = self.dirty + 1 end
  frame.historyBuffer = {
    GetEntryAtIndex = function (_, index) return frame.entries[#frame.entries - index + 1] end,
    PushBack = function (_, entry)
      assert(frame.inNativeBackfill, "Restoration must use the native secure BackFillMessage path")
      if #frame.entries >= core.db.profile.scrollbackLines then return end
      table.insert(frame.entries, 1, entry)
      return true
    end,
  }
  function frame:AddMessage(text, red, green, blue)
    self.entries[#self.entries + 1] = self:PackageEntry(text, red, green, blue)
  end
  function frame:BackFillMessage(text, red, green, blue)
    self.inNativeBackfill = true
    if self.historyBuffer:PushBack(self:PackageEntry(text, red, green, blue)) then self:MarkDisplayDirty() end
    self.inNativeBackfill = nil
  end
  frame.Clear, frame.EnableMouse, frame.EnableMouseWheel, frame.SetAlpha, frame.SetShown = noop, noop, noop, noop, noop
  local view = setmetatable({chatFrame = frame, historyBuffer = frame.historyBuffer,
    state = {messages = {}, incomingMessages = {}, incomingScrollbackMessages = {}}},
    {__index = core.Components.SlidingMessageFrameMixin})
  view.HookChatFrameVisibility = noop
  function view:SecureHook(object, method, callback)
    local original = object[method]
    object[method] = function (...)
      local result = original(...)
      callback(...)
      return result
    end
  end
  view:HookNativeMessages(frame, false)
  local window = {active = true, chatFrame = frame, slidingMessageFrame = view}
  uiManager.state.windows[name] = window
  return frame, view, window
end

-- Saving reads the complete native buffer, independently of the capped rendered rows.
local first = newWindow("ChatFrame1", {line("trimmed", 1), line("first", 100), line("second", 200),
  line(secretText, 250), line("third", 300)})
local detached = newWindow("ChatFrame3", {{message = "default colors", timestamp = 90}, line("secret color", 5)})
detached.entries[2].r = secretNumber
newWindow("ChatFrame2", {line("combat", 1)})
local _, _, temporary = newWindow("ChatFrame11", {line("whisper", 1)}, {isTemporary = true})
temporary.temporary = true
local _, _, closed = newWindow("ChatFrame4", {line("closed", 1)})
closed.active = false
history:OnEnable()
shutdown()
local saved = core.db.char.chatHistory
assert(#saved.ChatFrame1 == 3 and saved.ChatFrame1[1][1] == "first" and saved.ChatFrame1[3][5] == 300)
assert(#saved.ChatFrame3 == 1 and saved.ChatFrame3[1][5] == 9990, "Detached history keeps uptime-based arrival times and default colors")
assert(not saved.ChatFrame2 and not saved.ChatFrame11 and not saved.ChatFrame4, "Combat, temporary, and closed windows are excluded")
assert(#first.entries == 5, "Saving never changes live messages")

local many = {}
for index = 1, 150 do many[index] = line("line "..index, index) end
many[1].message = "Message from |Kaccount-token|k"
core.db.profile.scrollbackLines = 200
newWindow("ChatFrame5", many)
history:Save()
assert(#core.db.char.chatHistory.ChatFrame5 == 150, "Persistence uses native scrollback rather than the 128 rendered rows")
assert(core.db.char.chatHistory.ChatFrame5[1][1] == "Message from ???", "Protected player tokens are not saved")
pratHistory = true
history:Save()
assert(#core.db.char.chatHistory.ChatFrame5 == 150, "Saving also captures the transcript while Prat History owns restoration")
pratHistory = false
core.db.profile.saveChatHistory = false
shutdown()
assert(next(core.db.char.chatHistory) == nil, "Disabling persistence clears saved transcripts on shutdown")
core.db.profile.saveChatHistory = nil

local function restoreSetup(entries, limit)
  uiManager.state.windows = {}
  core.db.profile.scrollbackLines = limit or 4
  local frame, view = newWindow("ChatFrame1", entries)
  core.db.char.chatHistory = {ChatFrame1 = {savedLine("first", 100), savedLine("second", 200), savedLine("third", 300)}}
  return frame, view
end

local frame, view = restoreSetup({line("live", 9999)})
delayed()
assert(frame:GetNumMessages() == 4 and frame:GetMessageInfo(1) == "first" and frame:GetMessageInfo(4) == "live",
  "Restoration backfills native history in chronological order, retaining messages received during login")
local queued = view.state.incomingScrollbackMessages
assert(#queued == 3 and queued[1][2] == "third" and queued[3][2] == "first")
assert(queued[1].receivedAt == 300 and queued[3].receivedAt == 100, "The real renderer hook receives original timestamps")
assert(frame.dirty == 3 and not view.state.didNativeBackfill and core.db.char.chatHistory == nil)
assert(frame.entries[1].serverTime == nil and core.Components.SlidingMessageFrameHelpers.getReceivedAt(frame.entries[1]) == 100,
  "Restored timestamps live in addon bookkeeping, leaving native entries unchanged for secure chat processing")
history:Restore()
assert(frame:GetNumMessages() == 4, "Saved history is consumed only once")
history:Save()
assert(core.db.char.chatHistory.ChatFrame1[1][5] == 100, "Subsequent sessions preserve the original receivedAt")

frame, view = restoreSetup({line("live", 9999)}, 2)
history:Restore()
assert(frame:GetNumMessages() == 2 and frame:GetMessageInfo(1) == "third", "The retention limit favors newer saved messages and current-session messages")
assert(#view.state.incomingScrollbackMessages == 1)

frame, view = restoreSetup({line("second", 200), line("third", 300), line("live", 9999)})
history:Restore()
assert(frame:GetNumMessages() == 4 and frame:GetMessageInfo(1) == "first" and #view.state.incomingScrollbackMessages == 1,
  "A native history already present before hooks only receives its missing older prefix")

frame, view = restoreSetup({line("first", 100), line("second", 200), line("third", 300)})
history:Restore()
assert(frame:GetNumMessages() == 3 and #view.state.incomingScrollbackMessages == 0, "Existing complete history is not duplicated")

frame, view = restoreSetup({})
frame:BackFillMessage("native restoration", 1, 1, 1)
history:Restore()
assert(frame:GetNumMessages() == 1 and frame:GetMessageInfo(1) == "native restoration", "A native backfill after hooks takes precedence")

frame, view = restoreSetup({})
pratHistory = true
history:Restore()
assert(frame:GetNumMessages() == 0, "Only the enabled Prat History module suppresses Glassy restoration")
pratHistory = false

frame, view = restoreSetup({})
core.db.char.chatHistory.ChatFrame1 = {savedLine(secretText, 5), {false}, savedLine("blocked", 20),
  savedLine("first", secretNumber)}
history:Restore()
assert(frame:GetNumMessages() == 2 and frame:GetMessageInfo(1) == "blocked", "Malformed and secret saved lines are skipped")
assert(#view.state.incomingScrollbackMessages == 1 and view.state.incomingScrollbackMessages[1][2] == "first",
  "Native restoration keeps Glassy's existing blacklist behavior")
assert(view.state.incomingScrollbackMessages[1].receivedAt == 10000, "An unreadable saved timestamp falls back safely")

frame, view = restoreSetup({})
frame.BackFillMessage = function () error("native failure") end
local ok = pcall(history.Restore, history)
assert(not ok and view.state.restoringReceivedAt == nil, "A native failure cannot leak the scoped timestamp into later chat")

frame = restoreSetup({})
core.db.profile.saveChatHistory = false
history:Restore()
assert(frame:GetNumMessages() == 0, "Explicit false disables restoration")

canaccessvalue = nil
core.db.profile.saveChatHistory = true
frame = restoreSetup({})
history:Restore()
history:Save()
assert(#core.db.char.chatHistory.ChatFrame1 == 3 and frame:GetMessageInfo(1) == "first",
  "Classic clients without secret-value APIs retain the same history behavior")

core.db.profile.dedicatedWhisperWindows = true
canaccessvalue = function (value) return value ~= secretText and value ~= secretNumber end
local function whisper(text, id)
  local entry = line(text, 100)
  entry.event, entry.eventArgs = "CHAT_MSG_WHISPER", {[11] = id}
  return entry
end
frame, view = restoreSetup({
  whisper("captured", 41), whisper("native only", 42), whisper(secretText, 41), whisper("restricted ID", secretNumber),
})
local shown = {}
view.Update = function (_, incoming) shown = incoming end
view:LoadInitialMessages(frame)
capturedWhispers[41] = true -- The inbox can receive the event after AddMessage queues its row.
view:OnFrame()
assert(#shown == 3 and shown[1][2] == "native only" and shown[2][2] == secretText and shown[3][2] == "restricted ID",
  "Only readable whisper rows with an exact inbox match are hidden")
history:Save()
saved = core.db.char.chatHistory.ChatFrame1
assert(#saved == 2 and saved[1][1] == "native only" and saved[2][1] == "restricted ID" and #frame.entries == 4,
  "Dedicated history owns captured whispers without changing Blizzard's scrollback")
core.db.profile.chatHistoryDateSeparators = true
frame, view = restoreSetup({line("live", 180000)}, 5)
core.db.char.chatHistory.ChatFrame1 = {
  savedLine("day one first", 100), savedLine("day one last", 200),
  savedLine("day two first", 90000), savedLine("day two last", 91000),
}
history:Restore()
queued = view.state.incomingScrollbackMessages
assert(#queued == 6 and queued[3].historyDateSeparator and queued[6].historyDateSeparator,
  "Each restored day has one display-only separator before its first line in chronological order")
assert(queued[3][2] == os.date("%Y-%m-%d", 90000) and queued[6][2] == os.date("%Y-%m-%d", 100))
assert(frame:GetNumMessages() == 5 and frame:GetMessageInfo(1) == "day one first",
  "Separators never consume native scrollback capacity or change Blizzard's transcript")
history:Save()
assert(#core.db.char.chatHistory.ChatFrame1 == 5 and core.db.char.chatHistory.ChatFrame1[1][1] == "day one first",
  "Display separators never persist into subsequent sessions")
history:Restore()
assert(#queued == 6, "Restoring already-present native history never duplicates separators")

frame, view = restoreSetup({}, 5)
core.db.char.chatHistory.ChatFrame1 = {savedLine("blocked", 100), savedLine("visible", 90000)}
history:Restore()
queued = view.state.incomingScrollbackMessages
assert(#queued == 2 and queued[1][2] == "visible" and queued[2].historyDateSeparator,
  "A day with no displayed rows receives no separator")
frame, view = restoreSetup({line("live", 180000)}, 2)
history:Restore()
queued = view.state.incomingScrollbackMessages
assert(frame:GetNumMessages() == 2 and #queued == 2 and queued[1][2] == "third" and queued[2].historyDateSeparator,
  "Partial restoration inserts one marker for the retained day without displacing native messages")
frame, view = restoreSetup({})
pratHistory = true
history:Restore()
assert(#view.state.incomingScrollbackMessages == 0 and frame:GetNumMessages() == 0,
  "Prat history ownership also suppresses date separators")
pratHistory = false
core.db.profile.chatHistoryDateSeparators = false
print("PASS: native persistent chat history retains timestamps, limits, secret safety, and restoration ownership")
