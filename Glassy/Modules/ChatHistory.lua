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

function ChatHistory:Save()
  local history = {}
  if Core.db.profile.saveChatHistory ~= false then
    eachChatWindow(function (chatFrame)
      local lines = {}
      local count = chatFrame:GetNumMessages()
      for index = math.max(1, count - Helpers.getScrollbackLimit() + 1), count do
        local text, red, green, blue, _, _, _, event, eventArgs = chatFrame:GetMessageInfo(index)
        local line = {text, red, green, blue}
        local whisperLineID = Helpers.getWhisperLineID(text, event, eventArgs)
        if readableLine(line) and not (whisperLineID and Core:GetModule("WhisperWindows"):HasCapturedLine(whisperLineID)) then
          line[1] = text:gsub("|K.-|k", "???")
          local entry = Helpers.getHistoryEntry(chatFrame, index)
          local serverTime = entry and readableNumber(entry.serverTime)
          local timestamp = entry and readableNumber(entry.timestamp)
          line[5] = (entry and Helpers.restoredReceivedAt[entry]) or serverTime
            or (timestamp and GetServerTime() - math.max(0, GetTime() - timestamp)) or GetServerTime()
          lines[#lines + 1] = line
        end
      end
      if #lines > 0 then history[chatFrame:GetName()] = lines end
    end)
  end
  Core.db.char.chatHistory = history
end

-- A native history loaded before Glassy's hooks can already contain the saved tail.
local function lastMissingLine(chatFrame, lines)
  local count = chatFrame:GetNumMessages()
  for first = 1, #lines do
    local length = #lines - first + 1
    if length <= count then
      local matches = true
      for offset = 0, length - 1 do
        local text = chatFrame:GetMessageInfo(offset + 1)
        if not canAccess(text) or text ~= lines[first + offset][1] then
          matches = false
          break
        end
      end
      if matches then return first - 1 end
    end
  end
  return #lines
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
  Core.db.char.chatHistory = nil
  if Core.db.profile.saveChatHistory == false or type(history) ~= "table"
    or Core:IsPratModuleEnabled("History", "scrollback") then return end

  eachChatWindow(function (chatFrame, slidingMessageFrame)
    local saved = history[chatFrame:GetName()]
    if type(saved) ~= "table" or slidingMessageFrame.state.didNativeBackfill or not chatFrame.historyBuffer then return end

    local lines = {}
    for index = math.max(1, #saved - Helpers.getScrollbackLimit() + 1), #saved do
      if readableLine(saved[index]) then lines[#lines + 1] = saved[index] end
    end
    local last = lastMissingLine(chatFrame, lines)
    local available = Helpers.getScrollbackLimit() - chatFrame:GetNumMessages()
    local firstQueued = #slidingMessageFrame.state.incomingScrollbackMessages + 1
    for index = last, math.max(1, last - available + 1), -1 do
      local line = lines[index]
      -- Use the native secure barrier; keep original times in addon bookkeeping.
      slidingMessageFrame.state.restoringReceivedAt = readableNumber(line[5]) or GetServerTime()
      local ok, err = pcall(chatFrame.BackFillMessage, chatFrame, line[1], line[2], line[3], line[4])
      slidingMessageFrame.state.restoringReceivedAt = nil
      if not ok then error(err) end
    end
    if Core.db.profile.chatHistoryDateSeparators then addDateSeparators(slidingMessageFrame, firstQueued) end
  end)
end

function ChatHistory:OnEnable()
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function ()
    pcall(self.Save, self)
  end)
  -- Let the client and other addons restore their own chat before deciding what is missing.
  C_Timer.After(2, function () self:Restore() end)
end
