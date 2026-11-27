local Core, Constants, Utils = unpack(select(2, ...))
local Formatting = Core:GetModule("MessageFormatting")
local canaccessvalue = _G.canaccessvalue
local players = {}
local raidGroups = {}
local playerKeys, playerIndex = {}, 1
local recentNames, recentNameCounts, recentIndex = {}, {}, 1

local function readable(value)
  return not _G.canaccessvalue or _G.canaccessvalue(value)
end

local function plainString(value)
  return readable(value) and type(value) == "string"
end

local function remember(name, class, level, race, sex)
  if not plainString(name) or name == "" then return end
  if not players[name] then
    local old = playerKeys[playerIndex]
    if old then players[old] = nil end
    playerKeys[playerIndex] = name
    playerIndex = playerIndex % 2000 + 1
  end
  local player = players[name] or {}
  if plainString(class) then player.class = class end
  if readable(level) and type(level) == "number" and level > 0 then player.level = level end
  if plainString(race) then player.race = race end
  if readable(sex) then player.sex = sex end
  players[name] = player
end

local function wantsPlayerInfo()
  local profile = Core.db.profile
  return ((profile.formatPlayerNames or profile.chatRaidSubgroups) and not Core:IsPratModuleEnabled("PlayerNames"))
    or ((profile.chatClassIcons or profile.chatRaceIcons) and not Core:IsPratModuleEnabled("LinkInfoIcons"))
end

local function updateUnit(unit)
  if not ((_G.GetUnitName or _G.UnitName) and _G.UnitClass and _G.UnitLevel) then return end
  local _, class = _G.UnitClass(unit)
  local race = _G.UnitRace and select(2, _G.UnitRace(unit))
  local level, sex = _G.UnitLevel(unit), _G.UnitSex and _G.UnitSex(unit)
  local guid = _G.UnitGUID and _G.UnitGUID(unit)
  remember(guid, class, level, race, sex)
  if _G.GetUnitName then
    -- The client joins Forever surnames or foreign realms with the right separator.
    local ok, fullName = pcall(_G.GetUnitName, unit, true)
    if ok then
      remember(fullName, class, level, race, sex)
      return fullName, guid
    end
    return nil, guid
  end
  local name, realm = _G.UnitName(unit)
  remember(name, class, level, race, sex)
  if canaccessvalue and not canaccessvalue(realm) then return name, guid end
  if plainString(name) and plainString(realm) and realm ~= "" then
    name = name.."-"..realm
    remember(name, class, level, race, sex)
  end
  return name, guid
end

function Formatting:RefreshPlayers()
  raidGroups = {}
  if not wantsPlayerInfo() then return end
  updateUnit("player")
  updateUnit("target")
  updateUnit("mouseover")
  for i = 1, 4 do updateUnit("party"..i) end
  local inRaid = Core.db.profile.chatRaidSubgroups and _G.IsInRaid and _G.IsInRaid()
  local raidSize = _G.GetRaidRosterInfo and readable(inRaid) and inRaid
    and _G.GetNumGroupMembers and _G.GetNumGroupMembers()
  if not readable(raidSize) or type(raidSize) ~= "number" then raidSize = 0 end
  for i = 1, 40 do
    local name, guid = updateUnit("raid"..i)
    if i <= raidSize then
      local rosterName, _, subgroup = _G.GetRaidRosterInfo(i)
      if readable(subgroup) and type(subgroup) == "number" and subgroup >= 1 and subgroup <= 8
        and subgroup % 1 == 0 then
        if (not canaccessvalue or canaccessvalue(name)) and type(name) == "string" then raidGroups[name] = subgroup end
        if plainString(rosterName) then raidGroups[rosterName] = subgroup end
        if (not canaccessvalue or canaccessvalue(guid)) and type(guid) == "string" then raidGroups[guid] = subgroup end
      end
    end
  end
  if _G.GetNumGuildMembers and _G.GetGuildRosterInfo then
    for i = 1, _G.GetNumGuildMembers() do
      local name, _, _, level, _, _, _, _, _, _, class = _G.GetGuildRosterInfo(i)
      remember(name, class, level)
      if plainString(name) then
        local short, realm = name:match("^(.-)%-(.+)$")
        local ownRealm = _G.GetNormalizedRealmName and _G.GetNormalizedRealmName()
        if short and plainString(ownRealm) and realm == ownRealm then remember(short, class, level) end
      end
    end
  end
  local friends = _G.C_FriendList
  if friends and friends.GetNumFriends and friends.GetFriendInfoByIndex then
    for i = 1, friends.GetNumFriends() do
      local info = friends.GetFriendInfoByIndex(i)
      if info then remember(info.name, nil, info.level) end
    end
  end
end

function Formatting:OnEnable()
  self:RefreshPlayers()
  self.stopConfigListener = Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "messageFormatting" then self:RefreshPlayers() end
  end)
  local frame = _G.CreateFrame("Frame")
  for _, event in ipairs({"PLAYER_ENTERING_WORLD", "PLAYER_LEVEL_UP", "GROUP_ROSTER_UPDATE",
    "GUILD_ROSTER_UPDATE", "FRIENDLIST_UPDATE", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "UNIT_LEVEL", "UNIT_NAME_UPDATE"}) do
    frame:RegisterEvent(event)
  end
  frame:SetScript("OnEvent", function (_, event, unit)
    if not wantsPlayerInfo() then return end
    if event == "UNIT_LEVEL" or event == "UNIT_NAME_UPDATE" then updateUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then updateUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then updateUnit("mouseover")
    else self:RefreshPlayers() end
  end)
  self.eventFrame = frame
end

function Formatting:OnDisable()
  if self.eventFrame then self.eventFrame:UnregisterAllEvents() end
  if self.stopConfigListener then self.stopConfigListener() end
end

local function colorText(text, color, restore)
  if not color then return text end
  local hex = color.colorStr
  if not plainString(hex) and color.r and color.g and color.b then
    hex = string.format("ff%02x%02x%02x", math.floor(color.r * 255 + 0.5),
      math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
  end
  return hex and ("|c"..hex..text.."|r"..restore) or text
end

local function texture(icon, size)
  return "|T"..icon..":"..size..":"..size..":0:-2:64:64:4:60:4:60|t"
end

local function atlas(name, size)
  local textures = _G.C_Texture
  if textures and textures.GetAtlasInfo and textures.GetAtlasInfo(name) then
    return "|A:"..name..":"..size..":"..size..":0:-2|a"
  end
  return ""
end

local RACE_ATLAS = {
  Scourge = "undead", LightforgedDraenei = "lightforged", DarkIronDwarf = "darkiron",
  HighmountainTauren = "highmountain", MagharOrc = "magharorc", ZandalariTroll = "zandalari",
  EarthenDwarf = "earthen", KulTiran = "kultiran",
}

local RAID_CHANNELS = {RAID = true, RAID_LEADER = true, RAID_WARNING = true,
  INSTANCE_CHAT = true, INSTANCE_CHAT_LEADER = true}

local function playerInfo(data)
  local name, line, channel = data:match("^player:([^:]+):?(%d*):?([^:]*)")
  if not name then return end
  local player = players[name] or {}
  local subgroup = RAID_CHANNELS[channel] and raidGroups[name] or nil
  local getGUID = _G.C_ChatInfo and _G.C_ChatInfo.GetChatLineSenderGUID
  if getGUID and line ~= "" then
    local ok, guid = pcall(getGUID, tonumber(line))
    if ok and type(guid) == "string" and (not canaccessvalue or canaccessvalue(guid)) then
      player = players[guid] or player
      if RAID_CHANNELS[channel] then subgroup = raidGroups[guid] or subgroup end
      if not _G.GetPlayerInfoByGUID then return player, subgroup end
      local infoOK, _, class, _, race, sex = pcall(_G.GetPlayerInfoByGUID, guid)
      if infoOK then
        player = {class = plainString(class) and class or player.class, level = player.level,
          race = plainString(race) and race or player.race, sex = readable(sex) and sex or player.sex}
      end
    end
  end
  return player, subgroup
end

local function playerText(data, shown, restore, profile, names, icons, raidSubgroups)
  if shown:find("|K", 1, true) then return shown, "" end
  local player, subgroup = playerInfo(data)
  if not player then return shown, "" end
  if names then
    local colors = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS
    local color = colors and colors[player.class]
    if color then
      shown = shown:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
      if not profile.chatNameBrackets then shown = shown:match("^%[(.*)%]$") or shown end
      shown = colorText(shown, color, restore)
    elseif not profile.chatNameBrackets then
      shown = shown:gsub("^%[", ""):gsub("%]$", "")
        :gsub("^(|c%x%x%x%x%x%x%x%x)%[", "%1"):gsub("%](|r)$", "%1")
    end
    if player.level and profile.chatPlayerLevels ~= false then
      local color = _G.GetQuestDifficultyColor and _G.GetQuestDifficultyColor(player.level)
      shown = colorText(tostring(player.level), color, restore)..":"..shown
    end
  end
  if raidSubgroups and subgroup then shown = shown.." ["..subgroup.."]" end
  local prefix, size = "", math.floor((profile.messageFontSize or 13) + 0.5)
  if icons and profile.chatRaceIcons and player.race then
    local race = (RACE_ATLAS[player.race] or player.race:lower()).."-"..(player.sex == 3 and "female" or "male")
    prefix = atlas("raceicon128-"..race, size)
    if prefix == "" then prefix = atlas("raceicon-"..race, size) end
    if prefix == "" and player.race == "Skyborne" then prefix = texture(132845, size) end
  end
  if icons and profile.chatClassIcons and player.class then
    local classIcon = atlas("classicon-"..player.class:lower(), size)
    local coords = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[player.class]
    if classIcon == "" and coords then
      classIcon = "|TInterface\\Glues\\CharacterCreate\\UI-CharacterCreate-Classes:"..size..":"..size
        ..":0:-2:256:256:"..(coords[1] * 256)..":"..(coords[2] * 256)..":"..(coords[3] * 256)..":"..(coords[4] * 256).."|t"
    end
    prefix = prefix..classIcon
  end
  return shown, prefix ~= "" and (prefix.." ") or ""
end

local SHORT_CHANNELS = {SAY = "S", YELL = "Y", PARTY = "P", PARTY_LEADER = "PL", RAID = "R",
  RAID_LEADER = "RL", RAID_WARNING = "RW", INSTANCE_CHAT = "I", INSTANCE_CHAT_LEADER = "IL", GUILD = "G", OFFICER = "O",
  WHISPER = "W From", WHISPER_INFORM = "W To", BN_WHISPER = "W From", BN_WHISPER_INFORM = "W To"}

local function channelLabel(kind, profile, fallback)
  if profile.channelFullNames and profile.channelFullNames[kind] then return end
  local custom = profile.channelShortLabels and profile.channelShortLabels[kind]
  if plainString(custom) and #custom <= 64 and custom:find("%S") and not custom:find("[%c|%[%]]") then
    return custom
  end
  return fallback or SHORT_CHANNELS[kind]
end

local function channelText(data, shown, profile)
  local kind, number = data:match("^channel:([^:]+):?(%d*)")
  if not kind then return shown end
  kind = kind:upper()
  number = shown:match("^%[(%d+)%.") or (kind == "CHANNEL" and number ~= "" and number)
  if number then
    kind = "CHANNEL"..number
  else
    local leader = _G["CHAT_MSG_"..kind.."_LEADER"]
    if plainString(leader) and shown == "["..leader.."]" then kind = kind.."_LEADER" end
  end
  local short = channelLabel(kind, profile, number)
  return short and ("["..short.."]") or shown
end

local function linkText(data, shown, size)
  local kind, id = data:match("^(%a+):(%d+)")
  local icon
  if kind == "item" then
    local link = "|H"..data.."|h"..shown.."|h"
    local items = _G.C_Item or _G
    local getInfo = items.GetItemInfoInstant or _G.GetItemInfoInstant
    if getInfo then
      local _, _, subType, equipLocation, itemIcon, classID = getInfo(link)
      icon = itemIcon
      local classes = _G.Enum and _G.Enum.ItemClass
      local gear = classID == (classes and classes.Armor or 4) or classID == (classes and classes.Weapon or 2)
        or (classes and classID == classes.Profession)
      if gear then
        local details = {}
        if plainString(subType) and subType ~= "" then details[#details + 1] = subType end
        if classID ~= (classes and classes.Weapon or 2) and plainString(equipLocation) and _G[equipLocation] then
          details[#details + 1] = _G[equipLocation]
        end
        local getLevel = items.GetDetailedItemLevelInfo or _G.GetDetailedItemLevelInfo
        local level = getLevel and getLevel(link)
        if readable(level) and type(level) == "number" then details[#details + 1] = level end
        if #details > 0 then shown = shown:gsub("%]$", " ("..table.concat(details, " ")..")]", 1) end
      end
    end
  elseif kind == "spell" then
    if _G.C_Spell and _G.C_Spell.GetSpellInfo then
      local info = _G.C_Spell.GetSpellInfo(tonumber(id))
      icon = info and info.iconID
    elseif _G.GetSpellInfo then icon = select(3, _G.GetSpellInfo(tonumber(id))) end
  elseif kind == "achievement" and _G.GetAchievementInfo then
    icon = select(10, _G.GetAchievementInfo(tonumber(id)))
  end
  return shown, readable(icon) and (type(icon) == "number" or type(icon) == "string") and texture(icon, size) or ""
end

local function escape(text)
  return (text:gsub("(%W)", "%%%1"))
end

local function rememberRecentName(data)
  local name = data:match("^player:([^:]+)")
  if not name or name:find("|K", 1, true) then return end
  local old = recentNames[recentIndex]
  if old then
    recentNameCounts[old] = recentNameCounts[old] - 1
    if recentNameCounts[old] == 0 then recentNameCounts[old] = nil end
  end
  recentNames[recentIndex] = name
  recentNameCounts[name] = (recentNameCounts[name] or 0) + 1
  recentIndex = recentIndex % 200 + 1
end

function Formatting:CompletePlayerName(prefix)
  if not Core.db.profile.completePlayerNames or Core:IsPratModuleEnabled("PlayerNames")
    or not plainString(prefix) or prefix == "" then return end
  prefix = Utils.lower(prefix)
  local match
  for name in pairs(recentNameCounts) do
    if Utils.lower(name):sub(1, #prefix) == prefix then
      if match then return end
      match = name
    end
  end
  return match
end

local function highlightText(text, ownName, guildTags, restore)
  local function highlightWords(words)
    if not ownName then return words end
    return (words:gsub("%f[%a\128-\255][%a\128-\255]+%f[^%a\128-\255]", function (word)
      if Utils.lower(word) == ownName then return "|cff00ff00"..word.."|r"..restore end
    end))
  end
  if not guildTags then return highlightWords(text) end
  local parts, cursor = {}, 1
  while true do
    local first, last, guild = text:find("<([^<>]+)>", cursor)
    if not first then parts[#parts + 1] = highlightWords(text:sub(cursor)); break end
    parts[#parts + 1] = highlightWords(text:sub(cursor, first - 1))
    parts[#parts + 1] = "|cffffffff<|r|cff00ff00"..guild.."|r|cffffffff>|r"..restore
    cursor = last + 1
  end
  return table.concat(parts)
end

local function shortenSpeech(text, profile)
  local start, finish, linkType = text:find("|H(%a+):[^|]+|h.-|h")
  if not start or (linkType ~= "player" and linkType ~= "BNplayer") then return text end
  local before, after = text:sub(1, start - 1), text:sub(finish + 1)
  local badge = after:match("^ |A:friendslist%-recentallies%-yellow:[%d:%-]+|a") or ""
  after = after:sub(#badge + 1)
  local plainBefore = before:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
  local kinds = linkType == "BNplayer" and {"BN_WHISPER", "BN_WHISPER_INFORM"}
    or {"SAY", "YELL", "WHISPER", "WHISPER_INFORM"}
  for _, kind in ipairs(kinds) do
    local format = _G["CHAT_"..kind.."_GET"]
    local prefix, suffix
    if plainString(format) then prefix, suffix = format:match("^(.-)%%s(.-)$") end
    if prefix == plainBefore and suffix ~= "" and after:sub(1, #suffix) == suffix then
      local short = channelLabel(kind, profile)
      if not short then return text end
      local colors = before:sub(1, #before - #prefix)
      return colors.."["..short.."] "..text:sub(start, finish)..badge..": "..after:sub(#suffix + 1)
    end
  end
  return text
end

local CHANNEL_NOTICES = {"CHAT_YOU_CHANGED_NOTICE", "CHAT_YOU_JOINED_NOTICE", "CHAT_YOU_LEFT_NOTICE", "CHAT_SUSPENDED_NOTICE",
  "CHAT_YOU_CHANGED_NOTICE_BN", "CHAT_YOU_JOINED_NOTICE_BN", "CHAT_YOU_LEFT_NOTICE_BN", "CHAT_SUSPENDED_NOTICE_BN"}

local function isChannelNotice(text)
  for _, key in ipairs(CHANNEL_NOTICES) do
    local format = _G[key]
    local prefix = plainString(format) and format:match("^(.-)|H")
    if prefix and prefix ~= "" and text:find(prefix, 1, true) then return true end
  end
  return false
end

local function formatText(text)
  local profile = Core.db.profile
  local channels = profile.shortChannelNames and not Core:IsPratModuleEnabled("ChannelNames")
    and not isChannelNotice(text)
  local nativeNames = not Core:IsPratModuleEnabled("PlayerNames")
  local names = profile.formatPlayerNames and nativeNames
  local firstNames = profile.firstNamesOnly and nativeNames
  local raidSubgroups = profile.chatRaidSubgroups and nativeNames
  local icons = (profile.chatClassIcons or profile.chatRaceIcons or profile.chatLinkIcons) and not Core:IsPratModuleEnabled("LinkInfoIcons")
  local nativeHighlight = not Core:IsPratModuleEnabled("Highlight")
  local playerMentions = profile.highlightPlayerMentions and nativeHighlight
  local guildTags = profile.highlightGuildTags and nativeHighlight
  local completion = profile.completePlayerNames and nativeNames
  local altNames = profile.chatAltNamesEnabled and not Core:IsPratModuleEnabled("AltNames")
  if not (channels or names or firstNames or raidSubgroups or icons or playerMentions or guildTags or completion or altNames) then return text end
  if channels then
    text = shortenSpeech(text, profile)
    local warning = channelLabel("RAID_WARNING", profile)
    if warning and plainString(_G.CHAT_MSG_RAID_WARNING) then
      text = text:gsub("^%["..escape(_G.CHAT_MSG_RAID_WARNING).."%]", function () return "["..warning.."]" end)
    end
  end
  local ownName = playerMentions and _G.UnitName and _G.UnitName("player")
  ownName = plainString(ownName) and Utils.lower(ownName) or nil
  local parts, cursor, restore = {}, 1, ""
  while cursor <= #text do
    local pipe = text:find("|", cursor, true) or (#text + 1)
    local segment = text:sub(cursor, pipe - 1)
    if ownName or guildTags then segment = highlightText(segment, ownName, guildTags, restore) end
    parts[#parts + 1] = segment
    if pipe > #text then break end
    local code, finish = text:sub(pipe, pipe + 1)
    if code == "|H" then
      local _, linkEnd, data, shown = text:find("^|H([^|]+)|h(.-)|h", pipe)
      if linkEnd then
        local prefix = ""
        if data:match("^player:") then
          if completion and not shown:find("|K", 1, true) then rememberRecentName(data) end
          if firstNames and not shown:find("|K", 1, true) then
            shown = shown:gsub("^(%S+)%s+[^|%]]+", "%1", 1)
          end
          if names or icons or raidSubgroups then
            shown, prefix = playerText(data, shown, restore, profile, names, icons, raidSubgroups)
          end
          if altNames then shown = Core:GetModule("ChatRules"):AppendMainName(data, shown) end
        elseif channels and data:match("^channel:") then shown = channelText(data, shown, profile)
        elseif icons and profile.chatLinkIcons then shown, prefix = linkText(data, shown, profile.messageFontSize or 13) end
        parts[#parts + 1] = prefix.."|H"..data.."|h"..shown.."|h"
        finish = linkEnd
      end
    elseif code == "|T" or code == "|A" or code == "|K" then
      local closing = ({["|T"] = "|t", ["|A"] = "|a", ["|K"] = "|k"})[code]
      local _, sequenceEnd = text:find(closing, pipe + 2, true)
      finish = sequenceEnd or #text
    elseif code == "|c" and text:sub(pipe + 2, pipe + 9):match("^%x%x%x%x%x%x%x%x$") then
      finish, restore = pipe + 9, text:sub(pipe, pipe + 9)
    elseif code == "|r" then finish, restore = pipe + 1, ""
    elseif code == "||" then finish = pipe + 1 end
    if code ~= "|H" or not finish then
      finish = finish or #text
      parts[#parts + 1] = text:sub(pipe, finish)
    end
    cursor = finish + 1
  end
  return table.concat(parts)
end

function Formatting:Format(text)
  if not plainString(text) then return text end
  local ok, result = pcall(formatText, text)
  return ok and result or text
end
