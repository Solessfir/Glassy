local Core = unpack(select(2, ...))
local ChatHistory = Core:GetModule("ChatHistory")
local Helpers = Core.Components.SlidingMessageFrameHelpers

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local C_Timer = C_Timer
local GetServerTime = GetServerTime
local GetTime = GetTime
local date = date
-- luacheck: pop

local function canAccess(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

local function readableNumber(value)
  if canAccess(value) and type(value) == "number" and value == value and math.abs(value) < math.huge then
    return value
  end
end

local function receivedAt(entry)
  if not entry then return end
  local exact = Helpers.restoredReceivedAt[entry] or readableNumber(entry.serverTime)
  if exact then return exact end
  local uptime = readableNumber(entry.timestamp)
  if uptime then return GetServerTime() - math.max(0, GetTime() - uptime), true end
end

local function sameTime(savedTime, liveTime, estimated)
  -- Converting a native uptime timestamp uses a whole-second server clock.
  return savedTime and liveTime and (liveTime == savedTime or (estimated and math.abs(liveTime - savedTime) < 1))
end

local function readableLine(line)
  return type(line) == "table" and canAccess(line[1]) and type(line[1]) == "string" and line[1] ~= ""
    and canAccess(line[2]) and (line[2] == nil or readableNumber(line[2]))
    and canAccess(line[3]) and (line[3] == nil or readableNumber(line[3]))
    and canAccess(line[4]) and (line[4] == nil or readableNumber(line[4]))
end

local function eachChatWindow(callback)
  for _, window in pairs(Core:GetModule("UIManager").state.windows) do
    local chatFrame = window.chatFrame
    if window.active and not window.temporary and chatFrame and not chatFrame.isTemporary and chatFrame ~= _G.ChatFrame2 then
      callback(chatFrame, window.slidingMessageFrame)
    end
  end
end

local function savedLines(saved, limit)
  local lines = {}
  for index = math.max(1, #saved - limit + 1), #saved do
    if readableLine(saved[index]) then lines[#lines + 1] = saved[index] end
  end
  return lines
end

-- The native buffer can already contain a suffix of the saved transcript.
local function lastMissingLine(lines, count, matches)
  for first = math.max(1, #lines - count + 1), #lines do
    local matched = true
    for offset = 0, #lines - first do
      if not matches(lines[first + offset], offset + 1) then
        matched = false
        break
      end
    end
    if matched then return first - 1 end
  end
  return #lines
end

local function mergeHistory(saved, live, limit, estimatedTimes)
  if #live >= limit then return live end
  local previous = savedLines(saved, limit)
  local last = lastMissingLine(previous, #live, function (line, index)
    -- Identical text sent again after login is still a new message.
    return line[1] == live[index][1] and sameTime(readableNumber(line[5]), live[index][5], estimatedTimes[index])
  end)
  local merged = {}
  for index = math.max(1, last - (limit - #live) + 1), last do
    merged[#merged + 1] = previous[index]
  end
  for _, line in ipairs(live) do merged[#merged + 1] = line end
  return merged
end

function ChatHistory:Save()
  local history = {}
  if Core.db.profile.saveChatHistory ~= false then
    local limit = Helpers.getScrollbackLimit()
    local previous = Core.db.char.chatHistory
    if self.restorePending and type(previous) == "table" then
      -- Some windows may still be waiting to restore or may not have been created yet.
      for name, saved in pairs(previous) do
        if type(saved) == "table" then history[name] = saved end
      end
    end
    eachChatWindow(function (chatFrame)
      local name = chatFrame:GetName()
      local saved = history[name]
      local estimatedTimes = saved and {}
      local lines = {}
      local count = chatFrame:GetNumMessages()
      for index = math.max(1, count - limit + 1), count do
        local text, red, green, blue, _, _, _, event, eventArgs = chatFrame:GetMessageInfo(index)
        local line = {text, red, green, blue}
        local whisperLineID = Helpers.getWhisperLineID(text, event, eventArgs)
        if readableLine(line) and not (whisperLineID and Core:GetModule("WhisperWindows"):SavesCapturedLine(whisperLineID)) then
          line[1] = text:gsub("|K.-|k", "???")
          local timestamp, estimated = receivedAt(Helpers.getHistoryEntry(chatFrame, index))
          line[5] = timestamp or GetServerTime()
          if estimatedTimes and estimated then estimatedTimes[#lines + 1] = true end
          lines[#lines + 1] = line
        end
      end
      if #lines > 0 then
        history[name] = saved and mergeHistory(saved, lines, limit, estimatedTimes) or lines
      end
    end)
  end
  Core.db.char.chatHistory = history
end

local function addDateSeparators(slidingMessageFrame, first)
  local queue = slidingMessageFrame.state.incomingScrollbackMessages
  local previousDay
  for index = #queue, first, -1 do
    local args = queue[index]
    local ok, day = pcall(date, "%Y-%m-%d", args.receivedAt)
    if ok and day ~= previousDay then
      local separator = {args[1], day, 0.5, 0.5, 0.5}
      separator.historyDateSeparator = true
      table.insert(queue, index + 1, separator)
      previousDay = day
    end
  end
end

function ChatHistory:Restore()
  local history = Core.db.char.chatHistory
  if Core.db.profile.saveChatHistory == false or type(history) ~= "table"
    or Core:IsPratModuleEnabled("History", "scrollback") then
    Core.db.char.chatHistory = nil
    self.restorePending = nil
    return
  end

  eachChatWindow(function (chatFrame, slidingMessageFrame)
    local saved = history[chatFrame:GetName()]
    if type(saved) ~= "table" or slidingMessageFrame.state.didNativeBackfill or not chatFrame.historyBuffer then return end

    local limit, count = Helpers.getScrollbackLimit(), chatFrame:GetNumMessages()
    local lines = savedLines(saved, limit)
    local last = lastMissingLine(lines, count, function (line, index)
      local text = chatFrame:GetMessageInfo(index)
      if not canAccess(text) or text ~= line[1] then return false end
      local liveTime, estimated = receivedAt(Helpers.getHistoryEntry(chatFrame, index))
      local savedTime = readableNumber(line[5])
      return not liveTime or not savedTime or sameTime(savedTime, liveTime, estimated)
    end)
    local available = limit - count
    local firstQueued = #slidingMessageFrame.state.incomingScrollbackMessages + 1
    for index = last, math.max(1, last - available + 1), -1 do
      local line = lines[index]
      -- Keep the fallback time on the saved row so a partial restore can still be deduplicated.
      line[5] = readableNumber(line[5]) or GetServerTime()
      -- Use the native secure barrier; keep original times in addon bookkeeping.
      slidingMessageFrame.state.restoringReceivedAt = line[5]
      local ok, err = pcall(chatFrame.BackFillMessage, chatFrame, line[1], line[2], line[3], line[4])
      slidingMessageFrame.state.restoringReceivedAt = nil
      if not ok then error(err) end
    end
    if Core.db.profile.chatHistoryDateSeparators then addDateSeparators(slidingMessageFrame, firstQueued) end
  end)
  Core.db.char.chatHistory = nil
  self.restorePending = nil
end

function ChatHistory:OnEnable()
  self.restorePending = true
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function ()
    pcall(self.Save, self)
  end)
  -- Let the client and other addons restore their own chat before deciding what is missing.
  C_Timer.After(2, function () self:Restore() end)
end
