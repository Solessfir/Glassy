local Core, _, Utils = unpack(select(2, ...))
local Alerts = Core:GetModule("ChatAlerts")
local L = function (text) return Core:Localize(text) end

local CHANNELS = {"SAY", "YELL", "EMOTE", "TEXT_EMOTE", "PARTY", "PARTY_LEADER", "RAID",
  "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER", "GUILD", "OFFICER",
  "WHISPER", "BN_WHISPER", "CHANNEL"}
local NATIVE_WHISPERS = {WHISPER = true, BN_WHISPER = true}
local BUILTIN_SOUNDS = {
  ["builtin:READY_CHECK"] = {kit = "READY_CHECK", name = "Ready check"},
  ["builtin:IG_MAINMENU_OPTION_CHECKBOX_ON"] = {kit = "IG_MAINMENU_OPTION_CHECKBOX_ON", name = "Checkbox"},
}
local selectedChannel = "GUILD"

local function accessible(value)
  return not (_G.issecretvalue and _G.issecretvalue(value))
    and (not _G.canaccessvalue or _G.canaccessvalue(value))
end

local function readable(value)
  return accessible(value) and type(value) == "string" and value ~= ""
end

local function positiveNumber(value)
  return accessible(value) and type(value) == "number" and value > 0 and value < math.huge
end

local function visibleText(text)
  -- Hidden names remain opaque, and link payloads must never trigger a match.
  text = text:gsub("||", "\001")
  if text:find("|K", 1, true) then return end
  return (text:gsub("|H.-|h(.-)|h", "%1"):gsub("|T.-|t", " "):gsub("|A.-|a", " ")
    :gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("\001", "|"))
end

local function containsWord(text, word)
  local cursor = 1
  while true do
    local first, last = text:find(word, cursor, true)
    if not first then return false end
    local before, after = text:sub(first - 1, first - 1), text:sub(last + 1, last + 1)
    if not before:find("[%w_\128-\255]") and not after:find("[%w_\128-\255]") then return true end
    cursor = last + 1
  end
end

local function isOwnMessage(author, guid)
  local ownGUID = _G.UnitGUID and _G.UnitGUID("player")
  if readable(guid) and readable(ownGUID) then return guid == ownGUID end
  local name, realm
  if _G.UnitFullName then name, realm = _G.UnitFullName("player")
  elseif _G.UnitName then name, realm = _G.UnitName("player") end
  if not readable(name) then return false end
  if Utils.lower(author) == Utils.lower(name) then return true end
  if not readable(realm) and _G.GetNormalizedRealmName then realm = _G.GetNormalizedRealmName() end
  return readable(realm) and Utils.lower(author) == Utils.lower(name.."-"..realm:gsub("%s", "")) or false
end

function Alerts:Matches(text)
  local profile, lower = Core.db.profile, Utils.lower(text)
  if profile.chatAlertOwnName and _G.UnitName then
    local name = _G.UnitName("player")
    if readable(name) and containsWord(lower, Utils.lower(name)) then return true end
  end
  if readable(profile.chatAlertWords) then
    for word in profile.chatAlertWords:gmatch("[^,\r\n]+") do
      word = Utils.lower(word:match("^%s*(.-)%s*$"))
      if word ~= "" and containsWord(lower, word) then return true end
    end
  end
  return false
end

function Alerts:PlaySound(name)
  if not readable(name) then return false end
  local builtin = BUILTIN_SOUNDS[name]
  if builtin then
    local kit = _G.SOUNDKIT and _G.SOUNDKIT[builtin.kit]
    if not kit or not _G.PlaySound then return false end
    _G.PlaySound(kit, "Master")
    return true
  end
  if not _G.PlaySoundFile then return false end
  local path = Core.Libs.LSM:Fetch("sound", name, true)
  if not readable(path) then return false end
  _G.PlaySoundFile(path, "Master")
  return true
end

function Alerts:ShowPopup(text, author)
  if not self.popup then
    local frame = _G.CreateFrame("Frame", nil, _G.UIParent)
    frame:SetSize(500, 100)
    frame:SetPoint("TOP", _G.UIParent, "TOP", 0, -160)
    frame:SetFrameStrata("DIALOG")
    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0, 0, 0, 0.8)
    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("TOPLEFT", 12, -12)
    frame.text:SetPoint("BOTTOMRIGHT", -12, 12)
    frame.text:SetWordWrap(true)
    self.popup = frame
  end
  local message = (author..": "..text):gsub("|", "||")
  self.popup.text:SetText(message)
  self.popup:Show()
  self.popupGeneration = (self.popupGeneration or 0) + 1
  local generation = self.popupGeneration
  _G.C_Timer.After(5, function ()
    if self.popupGeneration == generation then self.popup:Hide() end
  end)
end

function Alerts:Receive(event, text, author, ...)
  local profile = Core.db.profile
  local hasSounds = type(profile.chatSounds) == "table" and next(profile.chatSounds)
    or type(profile.chatOutgoingSounds) == "table" and next(profile.chatOutgoingSounds)
  if not hasSounds and not profile.chatAlertPopup and not readable(profile.chatAlertSound) then return end
  if not readable(text) or not readable(author) then return end
  local kind = event:match("^CHAT_MSG_(.+)$")
  if not kind then return end
  local outgoing = kind == "WHISPER_INFORM" or kind == "BN_WHISPER_INFORM"
  if outgoing then kind = kind:gsub("_INFORM$", "") end
  local channelNumber, _, _, lineID, guid = select(6, ...)
  outgoing = outgoing or isOwnMessage(author, guid)
  local sounds
  if outgoing then sounds = profile.chatOutgoingSounds else sounds = profile.chatSounds end
  local sound = type(sounds) == "table" and sounds[kind]
  if kind == "CHANNEL" and positiveNumber(channelNumber) and type(sounds) == "table" then
    local numbered = sounds["CHANNEL"..channelNumber]
    if readable(numbered) then sound = numbered end
  end
  local ownsSounds = Core:IsPratModuleEnabled("Sounds")
  local canSound = not ownsSounds and (outgoing or not NATIVE_WHISPERS[kind])
  local canMention = not outgoing and not Core:IsPratModuleEnabled("Mentions")
  if not (canSound and readable(sound)) and not (canMention and (profile.chatAlertPopup or readable(profile.chatAlertSound))) then return end
  local processing = Core:GetModule("TextProcessing")
  if processing:IsMessageBlacklisted(text) then return end
  local censored = _G.C_ChatInfo and _G.C_ChatInfo.IsChatLineCensored
  if censored then
    if not positiveNumber(lineID) then return end
    local ok, hidden = pcall(censored, lineID)
    if not ok or not accessible(hidden) or hidden ~= false then return end
  end
  text, author = visibleText(text), visibleText(author)
  if not text or not author then return end
  local mentioned = canMention and self:Matches(text)
  -- One event produces at most one custom sound; Blizzard keeps its whisper sound.
  local played = canSound and self:PlaySound(sound)
  if mentioned then
    if not played and canSound and not Core:IsPratModuleEnabled("PopupMessage") then self:PlaySound(profile.chatAlertSound) end
    if profile.chatAlertPopup and not Core:IsPratModuleEnabled("PopupMessage") then self:ShowPopup(text, author) end
  end
end

function Alerts:OnEnable()
  if self.eventFrame then return end
  local frame = _G.CreateFrame("Frame")
  for _, kind in ipairs(CHANNELS) do pcall(frame.RegisterEvent, frame, "CHAT_MSG_"..kind) end
  frame:RegisterEvent("CHAT_MSG_WHISPER_INFORM")
  frame:RegisterEvent("CHAT_MSG_BN_WHISPER_INFORM")
  -- Live events run once per message regardless of how many chat windows display it.
  frame:SetScript("OnEvent", function (_, event, ...) self:Receive(event, ...) end)
  self.eventFrame = frame
end

function Alerts:OnDisable()
  if self.eventFrame then self.eventFrame:UnregisterAllEvents(); self.eventFrame = nil end
  if self.popup then self.popup:Hide() end
end

local function soundValues()
  local values = {[""] = L("None")}
  for key, builtin in pairs(BUILTIN_SOUNDS) do
    if _G.SOUNDKIT and _G.SOUNDKIT[builtin.kit] then values[key] = L(builtin.name) end
  end
  for name in pairs(Core.Libs.LSM:HashTable("sound")) do values[name] = name end
  return values
end

local function soundOption(key, name, order, disabled)
  return {type = "select", name = L(name), order = order, values = soundValues, disabled = disabled,
    get = function () return Core.db.profile[key] or "" end,
    set = function (_, value) Core.db.profile[key] = value end}
end

function Alerts:BuildOptions()
  local function mentionsOwned() return Core:IsPratModuleEnabled("Mentions") end
  local function soundsOwned() return Core:IsPratModuleEnabled("Sounds") end
  local function channelSound(key, name, order, incoming)
    local option = soundOption(key, name, order, function ()
      return soundsOwned() or (incoming and NATIVE_WHISPERS[selectedChannel]) or false
    end)
    option.get = function ()
      local sounds = Core.db.profile[key]
      return type(sounds) == "table" and sounds[selectedChannel] or ""
    end
    option.set = function (_, value)
      Core.db.profile[key] = Core.db.profile[key] or {}
      Core.db.profile[key][selectedChannel] = value ~= "" and value or nil
    end
    return option
  end
  return {type = "group", name = L("Chat alerts and sounds"), args = {
    mentions = {type = "group", name = L("Mentions"), inline = true, order = 1, args = {
      ownName = {type = "toggle", name = L("Alert on my name"), order = 1, disabled = mentionsOwned,
        get = function () return not not Core.db.profile.chatAlertOwnName end,
        set = function (_, value) Core.db.profile.chatAlertOwnName = value end},
      words = {type = "input", name = L("Custom words"), order = 2, width = "full", multiline = true,
        desc = L("Case-insensitive whole words or phrases, separated by commas or new lines."), disabled = mentionsOwned,
        get = function () return Core.db.profile.chatAlertWords or "" end,
        set = function (_, value) Core.db.profile.chatAlertWords = value end},
      sound = soundOption("chatAlertSound", "Mention sound", 3, function ()
        return mentionsOwned() or soundsOwned() or Core:IsPratModuleEnabled("PopupMessage")
      end),
      popup = {type = "toggle", name = L("Show mention popup"), order = 4,
        disabled = function () return mentionsOwned() or Core:IsPratModuleEnabled("PopupMessage") end,
        get = function () return not not Core.db.profile.chatAlertPopup end,
        set = function (_, value)
          Core.db.profile.chatAlertPopup = value
          if not value and self.popup then self.popup:Hide() end
        end},
    }},
    sounds = {type = "group", name = L("Channel sounds"), inline = true, order = 2, args = {
      description = {type = "description", order = 1,
        name = L("Choose sounds for incoming and outgoing messages. Blizzard retains incoming whisper sounds. Enabled Prat modules take precedence.")},
      channel = {type = "select", name = L("Channel"), order = 2,
        values = function ()
          local values = {}
          for _, kind in ipairs(CHANNELS) do values[kind] = _G[kind] or kind end
          for number = 1, 20 do values["CHANNEL"..number] = L("Channel").." "..number end
          return values
        end,
        get = function () return selectedChannel end,
        set = function (_, value) selectedChannel = value end},
      incoming = channelSound("chatSounds", "Incoming sound", 3, true),
      outgoing = channelSound("chatOutgoingSounds", "Outgoing sound", 4),
    }},
  }}
end
