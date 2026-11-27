local Core, Constants = unpack(select(2, ...))
local Utilities = Core:GetModule("ChatUtilities")

local CHAT_TYPES = {
  {"SAY", "Say"}, {"YELL", "Yell"}, {"EMOTE", "Emote"}, {"PARTY", "Party"},
  {"RAID", "Raid"}, {"RAID_WARNING", "Raid warning"}, {"INSTANCE_CHAT", "Instance"},
  {"GUILD", "Guild"}, {"OFFICER", "Officer"}, {"WHISPER", "Whisper"},
  {"BN_WHISPER", "Battle.net whisper"}, {"CHANNEL", "Public channels"},
}

local function readable(value)
  return not (_G.issecretvalue and _G.issecretvalue(value))
    and (not _G.canaccessvalue or _G.canaccessvalue(value))
end

local function publicString(value)
  return readable(value) and type(value) == "string" and value ~= ""
end

local function component(value)
  return readable(value) and type(value) == "number" and value >= 0 and value <= 1
end

local function validColor(color)
  return type(color) == "table" and component(color.r) and component(color.g) and component(color.b)
end

local function joinedChannels()
  local channels = {}
  if not _G.GetChannelList then return channels end
  local list = {_G.GetChannelList()}
  for index = 1, #list, 3 do
    local id, name = list[index], list[index + 1]
    if readable(id) and type(id) == "number" and id > 0 and id % 1 == 0 and publicString(name) then
      channels["CHANNEL"..id] = name
    end
  end
  return channels
end

function Utilities:ApplyStickySettings(restore)
  self.stickyOverrides = self.stickyOverrides or {}
  local settings = Core.db.profile.stickyChatTypes or {}
  local enabled = not restore and not Core:IsPratModuleEnabled("ChannelSticky")
  for _, entry in ipairs(CHAT_TYPES) do
    local chatType = entry[1]
    local info = _G.ChatTypeInfo and _G.ChatTypeInfo[chatType]
    local saved = self.stickyOverrides[chatType]
    local choice = enabled and settings[chatType]
    local value = choice == "sticky" and 1 or choice == "reset" and 0 or nil
    if info and value ~= nil then
      if not saved then saved = {previous = info.sticky}; self.stickyOverrides[chatType] = saved end
      -- Keep an intervening addon's value as the new value to restore.
      if saved.applied ~= nil and info.sticky ~= saved.applied then saved.previous = info.sticky end
      info.sticky, saved.applied = value, value
    elseif saved then
      if info and info.sticky == saved.applied then info.sticky = saved.previous end
      self.stickyOverrides[chatType] = nil
    end
  end
end

function Utilities:RememberColor(chatType, red, green, blue)
  if self.applyingColors or not Core.db.profile.rememberChannelColors
    or Core:IsPratModuleEnabled("ChannelColorMemory") or not publicString(chatType)
    or not component(red) or not component(green) or not component(blue) then return end
  local name = joinedChannels()[chatType]
  if not name then return end
  Core.db.profile.channelColors[name] = {r = red, g = green, b = blue}
end

function Utilities:ApplyChannelColors()
  if not Core.db.profile.rememberChannelColors or Core:IsPratModuleEnabled("ChannelColorMemory")
    or not _G.ChangeChatColor then return end
  self.applyingColors = true
  local colors = Core.db.profile.channelColors
  for chatType, name in pairs(joinedChannels()) do
    -- AceDB's wildcard defaults otherwise create a black color for unseen names.
    local color = rawget(colors, name)
    local info = _G.ChatTypeInfo and _G.ChatTypeInfo[chatType]
    if validColor(color) then
      _G.ChangeChatColor(chatType, color.r, color.g, color.b)
    elseif validColor(info) then
      colors[name] = {r = info.r, g = info.g, b = info.b}
    end
  end
  self.applyingColors = false
end

function Utilities:ScheduleChannelColors()
  if self.colorsPending then return end
  self.colorsPending = true
  _G.C_Timer.After(0, function ()
    self.colorsPending = false
    if self.active then self:ApplyChannelColors() end
  end)
end

function Utilities:TargetCommandOccupied()
  local handler = _G.hash_SlashCmdList and _G.hash_SlashCmdList["/TT"]
  if handler and handler ~= self.targetCommand then return true end
  for key, value in pairs(_G) do
    if type(key) == "string" and key:match("^SLASH_.*%d+$") and publicString(value)
      and value:lower() == "/tt" then
      if key ~= "SLASH_ACECONSOLE_TT1" or not self.targetCommand
        or _G.SlashCmdList.ACECONSOLE_TT ~= self.targetCommand then return true end
    end
  end
  return false
end

function Utilities:ApplyTargetCommand(restore)
  local enabled = not restore and Core.db.profile.whisperTarget and not Core:IsPratModuleEnabled("TellTarget")
  if self.targetCommand and (not enabled or self:TargetCommandOccupied()) then
    if _G.SlashCmdList.ACECONSOLE_TT == self.targetCommand then
      local handler = _G.hash_SlashCmdList and _G.hash_SlashCmdList["/TT"]
      self:UnregisterChatCommand("tt")
      if handler and handler ~= self.targetCommand then _G.hash_SlashCmdList["/TT"] = handler end
    end
    self.targetCommand = nil
  end
  if enabled and not self.targetCommand and not self:TargetCommandOccupied() then
    self.targetCommand = function (text, editBox) self:WhisperTarget(text, editBox) end
    self:RegisterChatCommand("tt", self.targetCommand)
  end
end

function Utilities:WhisperTarget(text, editBox)
  if not Core.db.profile.whisperTarget or Core:IsPratModuleEnabled("TellTarget") then return end
  local player = _G.UnitIsPlayer and _G.UnitIsPlayer("target")
  local friendly = _G.UnitCanCooperate and _G.UnitCanCooperate("player", "target")
  if not readable(player) or not player or not readable(friendly) or not friendly then return end
  if _G.UnitIsHumanPlayer then
    local human = _G.UnitIsHumanPlayer("target")
    if not readable(human) or not human then return end
  end
  if _G.UnitIsConnected then
    local connected = _G.UnitIsConnected("target")
    if not readable(connected) or not connected then return end
  end
  local restriction = _G.C_SocialRestrictions
  if restriction and restriction.IsAgeVerificationRestricted then
    local restricted = restriction.IsAgeVerificationRestricted()
    if not readable(restricted) or restricted then return end
  end
  if not _G.UnitName then return end
  local character, realm = _G.UnitName("target")
  if not publicString(character) or not readable(realm) then return end
  local separators = _G.Constants and _G.Constants.CharacterNameSeparatorConsts
  local separator = separators and separators.CHARACTERNAME_REALMNAME_SEPARATOR or "-"
  local name = publicString(realm) and character..separator..realm or character
  if canaccessvalue and not canaccessvalue(name) then return end
  if name:find("[|%c]") or not readable(text) then return end
  text = type(text) == "string" and text or ""
  local util = _G.ChatFrameUtil
  local frame = editBox and editBox.chatFrame
  if util and util.SendTellWithMessage then
    util.SendTellWithMessage(name, text, frame)
  elseif _G.ChatFrame_SendTell then
    _G.ChatFrame_SendTell(name, frame)
    local box = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()
    if box then box:SetText(text) end
  end
end

function Utilities:ApplySettings()
  self:ApplyStickySettings()
  self:ApplyTargetCommand()
  self:ApplyChannelColors()
end

function Utilities:OnEnable()
  self.active = true
  self.eventFrame = self.eventFrame or _G.CreateFrame("Frame")
  for _, event in ipairs({"PLAYER_ENTERING_WORLD", "ADDON_LOADED", "CHANNEL_UI_UPDATE", "CHANNEL_COUNT_UPDATE", "CHAT_MSG_CHANNEL_NOTICE", "UPDATE_CHAT_COLOR"}) do
    self.eventFrame:RegisterEvent(event)
  end
  self.eventFrame:SetScript("OnEvent", function (_, event, ...)
    if event == "UPDATE_CHAT_COLOR" then
      self:RememberColor(...)
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ADDON_LOADED" then
      self:ApplySettings()
      self:ScheduleChannelColors()
    else
      self:ScheduleChannelColors()
    end
  end)
  if not self.subscribed then
    Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
      if self.active and (not key or key == "chatUtilities" or key == "stickyChatTypes"
        or key == "rememberChannelColors" or key == "channelColors" or key == "whisperTarget") then self:ApplySettings() end
    end)
    self.subscribed = true
  end
  self:ApplySettings()
end

function Utilities:OnDisable()
  self.active = false
  if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
  self:ApplyStickySettings(true)
  self:ApplyTargetCommand(true)
end

function Utilities:BuildOptions()
  local function changed()
    Core:Dispatch(Constants.ACTIONS.UpdateConfig("chatUtilities"))
  end
  local args = {
    rememberChannelColors = {
      type = "toggle", name = "Remember public channel colors", order = 1,
      desc = "Remember colors by the joined channel's name when its number changes. Prat's ChannelColorMemory takes priority.",
      disabled = function () return Core:IsPratModuleEnabled("ChannelColorMemory") end,
      get = function () return Core.db.profile.rememberChannelColors end,
      set = function (_, value) Core.db.profile.rememberChannelColors = value; changed() end,
    },
    whisperTarget = {
      type = "toggle", name = "Whisper target with /tt", order = 2,
      desc = "Use /tt to open a whisper to a friendly player target, optionally with draft text. Does not send the message. An existing /tt command or Prat's TellTarget takes priority.",
      disabled = function () return Core:IsPratModuleEnabled("TellTarget") or self:TargetCommandOccupied() end,
      get = function () return Core.db.profile.whisperTarget end,
      set = function (_, value) Core.db.profile.whisperTarget = value; changed() end,
    },
    sticky = {type = "group", name = "Sticky chat types", inline = true, order = 3,
      args = {description = {type = "description", order = 0,
        name = "Keep the last chat type after sending, reset it, or leave its current behavior unchanged. Prat's ChannelSticky takes priority."}}},
    logging = {type = "group", name = "Logging to disk", inline = true, order = 4, args = {
      description = {type = "description", order = 0,
        name = "These controls change the game's current logging state only. Chat is written to Logs/WoWChatLog.txt and combat to the game's combat log in Logs. Glassy does not start logging at login. Prat's ChatLog takes priority."},
    }},
  }
  for index, entry in ipairs(CHAT_TYPES) do
    local chatType, label = entry[1], entry[2]
    args.sticky.args[chatType] = {
      type = "select", name = label, order = index,
      values = {default = "Unchanged", sticky = "Keep chat type", reset = "Reset after sending"},
      disabled = function () return not (_G.ChatTypeInfo and _G.ChatTypeInfo[chatType]) or Core:IsPratModuleEnabled("ChannelSticky") end,
      get = function () return Core.db.profile.stickyChatTypes[chatType] or "default" end,
      set = function (_, value) Core.db.profile.stickyChatTypes[chatType] = value ~= "default" and value or nil; changed() end,
    }
  end
  for index, entry in ipairs({{"chat", "Chat logging", "LoggingChat", "IsLoggingChat"}, {"combat", "Combat logging", "LoggingCombat", "IsLoggingCombat"}}) do
    local key, label, setter, getter = unpack(entry)
    args.logging.args[key] = {
      type = "toggle", name = label, order = index,
      disabled = function () return not _G[setter] or Core:IsPratModuleEnabled("ChatLog") end,
      get = function ()
        local query = _G.C_ChatInfo and _G.C_ChatInfo[getter] or _G[setter]
        return query and not not query() or false
      end,
      set = function (_, enabled)
        if _G[setter] and not Core:IsPratModuleEnabled("ChatLog") then _G[setter](enabled) end
      end,
    }
  end
  return {type = "group", name = "Chat utilities", args = args}
end
