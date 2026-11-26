local Core, Constants = unpack(select(2, ...))
local Whispers = Core:GetModule("WhisperWindows")

local MAX_CONVERSATIONS, MAX_MESSAGES = 50, 100
local CVARS = {"whisperMode", "bnWhisperMode"}
local EVENTS = {
  CHAT_MSG_WHISPER = {battleNet = false, outgoing = false},
  CHAT_MSG_WHISPER_INFORM = {battleNet = false, outgoing = true},
  CHAT_MSG_BN_WHISPER = {battleNet = true, outgoing = false},
  CHAT_MSG_BN_WHISPER_INFORM = {battleNet = true, outgoing = true},
}

local function canAccess(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

local function readableText(value)
  return canAccess(value) and type(value) == "string" and value ~= ""
end

local function positiveNumber(value)
  return canAccess(value) and type(value) == "number" and value > 0 and value < math.huge
end

local function characterTarget(name)
  local character, realm = name:match("^([^-]+)%-(.+)$")
  local home = _G.GetNormalizedRealmName and _G.GetNormalizedRealmName()
  -- Some realms require the unqualified name for a local whisper.
  if character and readableText(home) and realm:lower() == home:lower() then return character end
  return name
end

local function battleNetName(name, accountID)
  if not name:find("|K", 1, true) then return name end
  local lookup = _G.C_BattleNet and _G.C_BattleNet.GetAccountInfoByID
  if not lookup then return end
  local ok, account = pcall(lookup, accountID)
  if not ok or not canAccess(account) or type(account) ~= "table" then return end
  local tag = account.battleTag
  if readableText(tag) and not tag:find("|", 1, true) then return tag end
end

local function currentTime()
  return _G.GetServerTime()
end

local function getCVar(name)
  local read = (_G.C_CVar and _G.C_CVar.GetCVar) or _G.GetCVar
  if not read then return end
  local ok, value = pcall(read, name)
  if ok and readableText(value) then return value end
end

local function setCVar(name, value)
  local write = (_G.C_CVar and _G.C_CVar.SetCVar) or _G.SetCVar
  if not write then return false end
  local ok, accepted = pcall(write, name, value)
  return ok and accepted ~= false
end

function Whispers:IsActive()
  return self.active == true
end

function Whispers:GetConversations()
  self.conversations = self.conversations or {}
  return self.conversations
end

function Whispers:HasCapturedLine(lineID)
  return self:IsActive() and positiveNumber(lineID) and self.capturedLines and self.capturedLines[lineID] ~= nil or false
end

function Whispers:ForgetMessage(message)
  if message.lineID and self.capturedLines[message.lineID] == message then
    self.capturedLines[message.lineID] = nil
  end
end

function Whispers:GetConversation(name, battleNet, target)
  local conversations = self:GetConversations()
  for _, conversation in ipairs(conversations) do
    if conversation.battleNet == battleNet and (battleNet and conversation.target == target
      or not battleNet and conversation.name:lower() == name:lower()) then
      conversation.name = name
      return conversation
    end
  end
  if #conversations >= MAX_CONVERSATIONS then
    local oldest = table.remove(conversations, 1)
    for _, message in ipairs(oldest.messages) do self:ForgetMessage(message) end
  end
  local conversation = {name = name, battleNet = battleNet, target = target, unread = 0, messages = {}}
  conversations[#conversations + 1] = conversation
  return conversation
end

function Whispers:MarkRead(conversation)
  conversation.unread = 0
end

function Whispers:Capture(event, text, name, ...)
  if not self:IsActive() or not readableText(text) or not readableText(name) then return end
  local kind = EVENTS[event]
  if not kind or Core:GetModule("TextProcessing"):IsMessageBlacklisted(text) then return end
  local lineID, _, accountID = select(9, ...)
  local censored = _G.C_ChatInfo and _G.C_ChatInfo.IsChatLineCensored
  if censored then
    if not positiveNumber(lineID) then return end
    local ok, hidden = pcall(censored, lineID)
    if not ok or not canAccess(hidden) or hidden ~= false then return end
  end
  if kind.battleNet then
    if not positiveNumber(accountID) then return end
    name = battleNetName(name, accountID)
    if not name then return end
  elseif name:find("|K", 1, true) then
    return
  else
    name = characterTarget(name)
  end
  local conversation = self:GetConversation(name, kind.battleNet, kind.battleNet and accountID or name)
  local message = {text = text, outgoing = kind.outgoing, time = currentTime()}
  self.capturedLines = self.capturedLines or {}
  if positiveNumber(lineID) then
    message.lineID = lineID
    self.capturedLines[lineID] = message
  end
  local messages = conversation.messages
  messages[#messages + 1] = message
  if #messages > MAX_MESSAGES then self:ForgetMessage(table.remove(messages, 1)) end
  if not kind.outgoing then conversation.unread = conversation.unread + 1 end
  if self.UpdateViews then self:UpdateViews(conversation, not kind.outgoing and Core.db.profile.whisperWindowsAutoOpen == true) end
end

function Whispers:Save()
  if not self.restored and Core.db.profile.saveChatHistory ~= false then return end
  local saved = {}
  if Core.db.profile.saveChatHistory ~= false then
    for _, conversation in ipairs(self:GetConversations()) do
      if not conversation.battleNet then
        local record = {name = conversation.name, messages = {}}
        for _, message in ipairs(conversation.messages) do
          record.messages[#record.messages + 1] = {
            text = message.text:gsub("|K.-|k", "???"), outgoing = message.outgoing, time = message.time,
          }
        end
        saved[#saved + 1] = record
      end
    end
  end
  Core.db.char.whisperWindows = saved
end

function Whispers:Restore()
  if self.restored then return end
  self.restored = true
  local saved = Core.db.char.whisperWindows
  Core.db.char.whisperWindows = nil
  if Core.db.profile.saveChatHistory == false or type(saved) ~= "table" then return end
  for index = math.max(1, #saved - MAX_CONVERSATIONS + 1), #saved do
    local record = saved[index]
    if type(record) == "table" and readableText(record.name) and not record.name:find("|K", 1, true)
      and type(record.messages) == "table" then
      local name = characterTarget(record.name)
      local conversation = self:GetConversation(name, false, name)
      for line = math.max(1, #record.messages - MAX_MESSAGES + 1), #record.messages do
        local message = record.messages[line]
        if type(message) == "table" and readableText(message.text) and canAccess(message.outgoing)
          and type(message.outgoing) == "boolean" then
          conversation.messages[#conversation.messages + 1] = {
            text = message.text, outgoing = message.outgoing, time = positiveNumber(message.time) and message.time or currentTime(),
          }
          if #conversation.messages > MAX_MESSAGES then table.remove(conversation.messages, 1) end
        end
      end
    end
  end
end

function Whispers:Send(conversation, text)
  if not self:IsActive() or not readableText(text) or not text:find("%S") then return false end
  local known = false
  for _, contact in ipairs(self:GetConversations()) do
    if contact == conversation then known = true; break end
  end
  if not known then return false end
  if conversation.battleNet then
    if not positiveNumber(conversation.target) or not readableText(conversation.name)
      or conversation.name:find("|K", 1, true) then return false end
  elseif not readableText(conversation.target) or conversation.target:find("[%s|/\\%c]") then
    return false
  end
  local chatInfo = _G.C_ChatInfo
  if chatInfo and chatInfo.InChatMessagingLockdown and chatInfo.InChatMessagingLockdown() then
    -- The native edit box keeps the draft for a permitted hardware send.
    if not conversation.battleNet then
      local chatFrameUtil = _G.ChatFrameUtil
      local getActiveWindow = (chatFrameUtil and chatFrameUtil.GetActiveWindow) or _G.ChatEdit_GetActiveWindow
      local active = getActiveWindow and getActiveWindow()
      if active then
        local activeText = active:GetText()
        if not canAccess(activeText) or activeText ~= "" then return false end
      end
      local draft = (chatFrameUtil and chatFrameUtil.SendTellWithMessage) or _G.ChatFrame_SendTellWithMessage
      if draft then
        local ok = pcall(draft, conversation.target, text)
        return ok
      end
    end
    return false
  end
  if conversation.battleNet then
    local send = (_G.C_BattleNet and _G.C_BattleNet.SendWhisper) or _G.BNSendWhisper
    if not send then return false end
    local ok, accepted = pcall(send, conversation.target, text)
    return ok and accepted ~= false
  end
  local send = (chatInfo and chatInfo.SendChatMessage) or _G.SendChatMessage
  if not send then return false end
  local ok, accepted = pcall(send, text, "WHISPER", nil, conversation.target)
  return ok and accepted ~= false
end

function Whispers:ApplySettings()
  self.active = Core.db.profile.dedicatedWhisperWindows == true
  local modes = Core.db.global.whisperWindowModes
  if self.active then
    modes = modes or {}
    Core.db.global.whisperWindowModes = modes
    for _, name in ipairs(CVARS) do
      local value = getCVar(name)
      if value and value ~= "inline" then
        modes[name] = modes[name] or value
        setCVar(name, "inline")
      end
    end
    self:Restore()
  elseif modes then
    for _, name in ipairs(CVARS) do
      local previous = modes[name]
      local current = getCVar(name)
      if previous and current and (current ~= "inline" or setCVar(name, previous)) then modes[name] = nil end
    end
  end
  if Core.db.profile.saveChatHistory == false then Core.db.char.whisperWindows = nil end
  if self.UpdateViews then self:UpdateViews() end
end

function Whispers:OnEnable()
  self.capturedLines = {}
  self.eventFrame = _G.CreateFrame("Frame")
  for event in pairs(EVENTS) do self.eventFrame:RegisterEvent(event) end
  self.eventFrame:SetScript("OnEvent", function (_, event, ...) self:Capture(event, ...) end)
  Core.db.RegisterCallback(self, "OnDatabaseShutdown", function () self:Save() end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "dedicatedWhisperWindows" or key == "whisperWindowsAutoOpen" or key == "saveChatHistory" then self:ApplySettings() end
  end)
  self:ApplySettings()
end
