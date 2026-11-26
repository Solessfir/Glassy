-- Run from the repository root with Lua 5.1.
local module, enabled = {}, {}
local profile = {shortChannelNames = true, channelShortLabels = {},
  channelFullNames = {BN_WHISPER = true, BN_WHISPER_INFORM = true}, formatPlayerNames = true, highlightNames = true,
  chatClassIcons = true, chatRaceIcons = false, chatLinkIcons = true, messageFontSize = 13}
local core = {
  db = {profile = profile},
  GetModule = function () return module end,
  IsPratModuleEnabled = function (_, name) return enabled[name] end,
}
local SECRET = setmetatable({}, {__tostring = function () error("Unreadable value") end})
canaccessvalue = function (value) return value ~= SECRET end
UnitName = function (unit) if unit == "player" then return "Elowen" elseif unit == "target" then return "Mira" end end
UnitClass = function () return "Mage", "MAGE" end
UnitLevel = function (unit) return unit == "target" and 42 or 60 end
UnitRace = function () return "Undead", "Scourge" end
UnitSex = function () return 3 end
C_ChatInfo = {GetChatLineSenderGUID = function (line) return line == 7 and "Player-1" or SECRET end}
GetPlayerInfoByGUID = function () return "Mage", "MAGE", "Undead", "Scourge", 3 end
C_Texture = {GetAtlasInfo = function (name) return name:match("classicon") or name == "raceicon128-undead-female" end}
RAID_CLASS_COLORS = {MAGE = {colorStr = "ff3fc7eb"}}
GetQuestDifficultyColor = function () return {r = 1, g = 1, b = 0} end
CHAT_SAY_GET, CHAT_YELL_GET = "%s says: ", "%s yells: "
CHAT_WHISPER_GET, CHAT_WHISPER_INFORM_GET = "%s whispers: ", "To %s: "
CHAT_MSG_PARTY_LEADER, CHAT_MSG_RAID_LEADER = "Party Leader", "Raid Leader"
CHAT_MSG_INSTANCE_CHAT_LEADER, CHAT_MSG_RAID_WARNING = "Instance Leader", "Raid Warning"
CHAT_BN_WHISPER_GET, CHAT_BN_WHISPER_INFORM_GET = "%s whispers: ", "To %s: "
INVTYPE_HEAD = "Head"
Enum = {ItemClass = {Armor = 4, Weapon = 2, Profession = 19}}
C_Item = {
  GetItemInfoInstant = function (link)
    assert(link:match("^|Hitem:"), "Item APIs receive complete hyperlinks, including bonus data")
    if link:find("item:1:", 1, true) then return 1, "Armor", "Cloth", "INVTYPE_HEAD", 1234, 4 end
    return 2, "Consumable", "Potion", "", 5678, 0
  end,
  GetDetailedItemLevelInfo = function (link) assert(link:match("^|Hitem:")); return 100 end,
}
C_Spell = {GetSpellInfo = function (id) return id == 3 and {iconID = 9876} end}
GetAchievementInfo = function () return nil, nil, nil, nil, nil, nil, nil, nil, nil, 3456 end
local eventFrame = {}
function eventFrame:RegisterEvent() end
function eventFrame:SetScript(_, callback) self.callback = callback end
function eventFrame:UnregisterAllEvents() end
CreateFrame = function () return eventFrame end
assert(loadfile("Glassy/Modules/MessageFormatting.lua"))("Glassy", {core, {}, {lower = string.lower}})
module:OnEnable()

local player = "|Hplayer:Mira:7:YELL|h[Mira]|h"
local text = module:Format(player.." yells: hello")
assert(text:find("[Y] ", 1, true) == 1, "Player yell receives its short label")
assert(text:find("|A:classicon-mage:13:13:0:-2|a", 1, true), "Class icon uses sender GUID")
assert(text:find("|Hplayer:Mira:7:YELL|h|cffffff0042|r:|cff3fc7ebMira|r|h: hello", 1, true), text)
assert(module:Format("Mira says: hello") == "Mira says: hello", "NPC speech stays unchanged")

local modules = {MessageFormatting = module, ChatLinks = {}, TextProcessing = {}}
function core:GetModule(name) return modules[name] end
strfind = string.find
profile.chatInvites, profile.chatUrls = true, true
for _, name in ipairs({"ChatLinks", "TextProcessing"}) do
  assert(loadfile("Glassy/Modules/"..name..".lua"))("Glassy", {core, {}, {lower = string.lower}})
end
local raw = "|Hplayer:Mira Silvermoon:7:YELL|h[Mira Silvermoon]|h yells: invite example.com"
local displayed, original = modules.TextProcessing:ProcessText(raw)
assert(original == raw and displayed:match("^%[Y%] |A:classicon%-mage"))
assert(displayed:find("|Hglassyinvite:Mira Silvermoon|h[invite]|h", 1, true))
assert(displayed:find("|Hglassyurl:example.com|h[example.com]|h", 1, true))
local getUnitName = UnitName
UnitName = function (unit) return unit == "target" and "Mira Silvermoon" or getUnitName(unit) end
module:RefreshPlayers()
UnitName = getUnitName
profile.firstNamesOnly = true
displayed, original = modules.TextProcessing:ProcessText(raw)
assert(original == raw and displayed:find("|Hplayer:Mira Silvermoon:7:YELL|h|cffffff0042|r:|cff3fc7ebMira|r|h", 1, true),
  "Shortened names retain the original source, sender hyperlink, class color, and level")
assert(displayed:find("|Hglassyinvite:Mira Silvermoon|h[invite]|h", 1, true), "Invites retain the full sender name")
profile.firstNamesOnly = false
profile.channelShortLabels.YELL = "Shout"
displayed, original = modules.TextProcessing:ProcessText(raw)
assert(original == raw and displayed:find("[Shout] ", 1, true) == 1)
assert(displayed:find("|Hglassyinvite:Mira Silvermoon|h[invite]|h", 1, true), "Custom labels preserve downstream invites")
profile.channelShortLabels.YELL = nil

local originalUnitName, originalUnitLevel, originalSenderGUID = UnitName, UnitLevel, C_ChatInfo.GetChatLineSenderGUID
local loadedParty, partyLevel = false, 46
GetUnitName = function (unit)
  local name, surname = UnitName(unit)
  return surname and surname ~= "" and (name.." "..surname) or name
end
UnitName = function (unit)
  if unit == "party1" then return loadedParty and "Liora" or nil, loadedParty and "Silver Moon" or nil end
  if unit == "party2" then return "Liora", "Amber Dawn" end
  return originalUnitName(unit)
end
UnitLevel = function (unit)
  if unit == "party1" then return loadedParty and partyLevel or 0 end
  if unit == "party2" then return 35 end
  return originalUnitLevel(unit)
end
UnitGUID = function (unit) return unit == "party1" and "Player-Forever-1" or nil end
C_ChatInfo.GetChatLineSenderGUID = function (line)
  return line == 71 and "Player-Forever-1" or originalSenderGUID(line)
end
local partyLeader = "|Hchannel:PARTY|h[Party Leader]|h |Hplayer:Liora Silver Moon:71:PARTY|h[|cffaabbccLiora Silver Moon|r]|h: hello"
text = module:Format(partyLeader)
assert(text:find("[PL]|h |A:classicon-mage:", 1, true) and not text:find("46", 1, true),
  "A sender GUID supplies class, but cannot invent an unavailable party level")
loadedParty = true
eventFrame.callback(eventFrame, "GROUP_ROSTER_UPDATE")
text = module:Format(partyLeader)
assert(text:find("|Hplayer:Liora Silver Moon:71:PARTY|h|cffffff0046|r:|cff3fc7ebLiora Silver Moon|r|h", 1, true),
  "Forever's split first name and multi-word surname match the full party hyperlink despite display markup")
assert(module:Format("|Hplayer:Liora Silver Moon|h[Liora Silver Moon]|h"):find("0046|r:", 1, true),
  "Full party names match cached unit levels without requiring a chat-line GUID")
assert(module:Format("|Hplayer:Liora Amber Dawn|h[Liora Amber Dawn]|h"):find("0035|r:", 1, true),
  "Players sharing a first name keep their own level")
assert(not module:Format("|Hplayer:Liora|h[Liora]|h"):find("%d+|r:"),
  "Forever does not cache a surname under the ambiguous first name")
assert(module:Format("|Hplayer:Different sender alias:71:PARTY|h[Liora Silver Moon]|h"):find("0046|r:", 1, true),
  "Readable sender GUIDs match live unit metadata without guessing from visible names")
partyLevel = 47
eventFrame.callback(eventFrame, "UNIT_LEVEL", "party1")
assert(module:Format(partyLeader):find("0047|r:", 1, true), "Party level updates refresh the matching identity")
UnitName = function (unit)
  if unit == "party3" then return "Arrived", "After Loading" end
  return originalUnitName(unit)
end
UnitLevel = function (unit) return unit == "party3" and 28 or originalUnitLevel(unit) end
eventFrame.callback(eventFrame, "UNIT_NAME_UPDATE", "party3")
assert(module:Format("|Hplayer:Arrived After Loading|h[Arrived After Loading]|h"):find("0028|r:", 1, true),
  "Unit names becoming available after the roster event refresh their full identity")
GetUnitName = function (unit, showRealm)
  local name, realm = UnitName(unit)
  return showRealm and realm and realm ~= "" and (name.."-"..realm) or name
end
UnitName = function (unit) if unit == "party4" then return "Astral", "OtherRealm" end end
UnitLevel = function () return 52 end
eventFrame.callback(eventFrame, "UNIT_NAME_UPDATE", "party4")
assert(module:Format("|Hplayer:Astral-OtherRealm|h[Astral-OtherRealm]|h"):find("0052|r:", 1, true),
  "Retail realm-qualified names retain their existing level lookup")
UnitName = function () return SECRET, SECRET end
UnitLevel, UnitGUID = function () return SECRET end, function () return SECRET end
assert(pcall(eventFrame.callback, eventFrame, "UNIT_NAME_UPDATE", "party1"), "Restricted unit identities and levels stay opaque")
UnitName, UnitLevel, UnitGUID, GetUnitName = originalUnitName, originalUnitLevel, nil, nil
C_ChatInfo.GetChatLineSenderGUID = originalSenderGUID

local channel = "|Hchannel:CHANNEL:4|h[4. Looking For Group]|h "..player
assert(module:Format(channel):find("|Hchannel:CHANNEL:4|h[4]|h", 1, true))
assert(module:Format("|Hchannel:PARTY|h[Party Leader]|h hello"):find("|h[PL]|h", 1, true))
profile.formatPlayerNames, profile.chatClassIcons, profile.highlightNames = false, false, false
local headers = {
  SAY = {player.." says: hello", "[S] "..player..": hello"},
  YELL = {player.." yells: hello", "[Y] "..player..": hello"},
  WHISPER = {player.." whispers: hello", "[W From] "..player..": hello"},
  WHISPER_INFORM = {"To "..player..": hello", "[W To] "..player..": hello"},
  PARTY = {"|Hchannel:PARTY|h[Party]|h hello", "|Hchannel:PARTY|h[P]|h hello"},
  PARTY_LEADER = {"|Hchannel:PARTY|h[Party Leader]|h hello", "|Hchannel:PARTY|h[PL]|h hello"},
  RAID = {"|Hchannel:RAID|h[Raid]|h hello", "|Hchannel:RAID|h[R]|h hello"},
  RAID_LEADER = {"|Hchannel:RAID|h[Raid Leader]|h hello", "|Hchannel:RAID|h[RL]|h hello"},
  RAID_WARNING = {"[Raid Warning] "..player..": hello", "[RW] "..player..": hello"},
  INSTANCE_CHAT = {"|Hchannel:INSTANCE_CHAT|h[Instance]|h hello", "|Hchannel:INSTANCE_CHAT|h[I]|h hello"},
  INSTANCE_CHAT_LEADER = {"|Hchannel:INSTANCE_CHAT|h[Instance Leader]|h hello", "|Hchannel:INSTANCE_CHAT|h[IL]|h hello"},
  GUILD = {"|Hchannel:GUILD|h[Guild]|h hello", "|Hchannel:GUILD|h[G]|h hello"},
  OFFICER = {"|Hchannel:OFFICER|h[Officer]|h hello", "|Hchannel:OFFICER|h[O]|h hello"},
  CHANNEL1 = {"|Hchannel:channel:1|h[1. General]|h hello", "|Hchannel:channel:1|h[1]|h hello"},
  CHANNEL10 = {"|Hchannel:CHANNEL:10|h[10. Custom]|h hello", "|Hchannel:CHANNEL:10|h[10]|h hello"},
}
for kind, entry in pairs(headers) do
  assert(module:Format(entry[1]) == entry[2], "Built-in short label: "..kind)
  profile.channelShortLabels[kind] = "Custom 100%"
  local custom = entry[2]:gsub("%b[]", function () return "[Custom 100%]" end, 1)
  assert(module:Format(entry[1]) == custom, "Custom label changes only the header: "..kind)
  profile.channelFullNames[kind] = true
  assert(module:Format(entry[1]) == entry[1], "Native header: "..kind)
  profile.channelFullNames[kind] = nil
  for _, invalid in ipairs({"", "   ", "|cffff0000Bad|r", "Bad\nlabel", SECRET}) do
    profile.channelShortLabels[kind] = invalid
    assert(module:Format(entry[1]) == entry[2], "Invalid custom labels use the built-in label: "..kind)
  end
  profile.channelShortLabels[kind] = nil
end
local bnPlayer = "|HBNplayer:Friend:123:7:BN_WHISPER:0|h[|Kf1|k]|h"
for kind, native in pairs({BN_WHISPER = bnPlayer.." whispers: hello", BN_WHISPER_INFORM = "To "..bnPlayer..": hello"}) do
  assert(module:Format(native) == native, "Battle.net keeps its native header by default")
  profile.channelFullNames[kind], profile.channelShortLabels[kind] = false, "BN"
  assert(module:Format(native) == "[BN] "..bnPlayer..": hello", "Battle.net opt-in preserves protected player data")
  profile.channelFullNames[kind], profile.channelShortLabels[kind] = true, nil
end
profile.channelShortLabels.YELL = "Custom"
profile.shortChannelNames = false
assert(module:Format(player.." yells: hello") == player.." yells: hello", "The master toggle disables custom labels")
profile.shortChannelNames = true
enabled.ChannelNames = true
assert(module:Format(player.." yells: hello") == player.." yells: hello", "Prat owns custom labels too")
enabled.ChannelNames = nil
profile.channelShortLabels.YELL = nil
profile.formatPlayerNames, profile.chatClassIcons, profile.highlightNames = true, true, true

local linked = "|cff0070dd|Hitem:1:0|h[Hat]|h|r"
text = module:Format(linked)
assert(text:find("|T1234:", 1, true), text)
assert(text:find("|Hitem:1:0|h[Hat (Cloth Head 100)]|h|r", 1, true), text)
assert(not module:Format("|Hitem:2:0|h[Potion]|h"):find("Potion %("), "Consumables do not gain gear details")
assert(module:Format("|Hspell:3|h[Spell]|h"):find("|T9876:", 1, true))
assert(module:Format("|Hachievement:4|h[Achievement]|h"):find("|T3456:", 1, true))
assert(module:Format("|Hspell:999|h[Unknown]|h") == "|Hspell:999|h[Unknown]|h")

text = module:Format("|cffaabbccHi Elowen and <Guild> Elowenish|r")
assert(text:find("|cff00ff00Elowen|r|cffaabbcc", 1, true), "Highlight restores enclosing message color")
assert(text:find("|cffffffff<|r|cff00ff00Guild|r|cffffffff>|r|cffaabbcc", 1, true))
assert(text:find("Elowenish", 1, true), "Highlight matches whole names")
assert(module:Format("elowen"):find("|cff00ff00elowen|r", 1, true), "Names are highlighted without case sensitivity")
local protected = "|Hcustom:Elowen|h[Elowen <Guild>]|h |TElowen:12|t |A:Elowen:12|a |KElowen|k ||Hcustom:X"
assert(module:Format(protected) == protected, "Links and protected markup are preserved")
assert(module:Format("broken |Hitem:1:Elowen") == "broken |Hitem:1:Elowen")
assert(module:Format(SECRET) == SECRET)
assert(module:Format(nil) == nil)

profile.chatRaceIcons = true
assert(module:Format(player):find("|A:raceicon128-undead-female:", 1, true))
enabled.ChannelNames, enabled.PlayerNames, enabled.LinkInfoIcons, enabled.Highlight = true, true, true, true
assert(module:Format(channel.." Elowen <Guild> "..linked) == channel.." Elowen <Guild> "..linked,
  "Enabled Prat modules own their formatting")
enabled.ChannelNames, enabled.PlayerNames, enabled.LinkInfoIcons, enabled.Highlight = nil, nil, nil, nil
C_ChatInfo.GetChatLineSenderGUID = function () return SECRET end
assert(type(module:Format("|Hplayer:Unknown:8:YELL|h[Unknown]|h")) == "string", "Secret GUID is never parsed")
GetPlayerInfoByGUID = function () return nil, SECRET, nil, SECRET, SECRET end
C_ChatInfo.GetChatLineSenderGUID = function () return "Player-2" end
assert(type(module:Format("|Hplayer:Unknown:8:YELL|h[Unknown]|h")) == "string", "Unreadable player info is ignored")

CHAT_YOU_JOINED_NOTICE = "Joined Channel: |Hchannel:CHANNEL:%d|h[%s]|h"
local notice = "Joined Channel: |Hchannel:CHANNEL:1|h[1. General]|h"
profile.channelShortLabels.CHANNEL1 = "General"
assert(module:Format(notice) == notice, "Channel notices retain names even with custom labels")
profile.channelShortLabels.CHANNEL1 = nil
assert(module:Format("To "..player..": hello"):find("[W To] ", 1, true) == 1)
profile.shortChannelNames, profile.formatPlayerNames, profile.highlightNames = false, false, false
profile.chatClassIcons, profile.chatRaceIcons, profile.chatLinkIcons = false, false, false
profile.completePlayerNames = true
assert(module:Format(player) == player, "Completion caching does not require visible name formatting")
assert(module:CompletePlayerName("mi") == "Mira")
module:Format("|Hplayer:Mina:8|h[Mina]|h")
assert(module:CompletePlayerName("mi") == nil, "Ambiguous names keep native completion")
assert(module:CompletePlayerName("mir") == "Mira")
assert(module:CompletePlayerName(SECRET) == nil)
enabled.PlayerNames = true
assert(module:CompletePlayerName("mir") == nil, "Prat owns completion when its player module is enabled")
enabled.PlayerNames = nil
profile.completePlayerNames = false
profile.firstNamesOnly = true
local fullName = "|Hplayer:Éowyn Silver Moon-Realm:9:WHISPER|h[|cffaabbccÉowyn Silver Moon|r]|h"
assert(module:Format(fullName) == "|Hplayer:Éowyn Silver Moon-Realm:9:WHISPER|h[|cffaabbccÉowyn|r]|h",
  "First names shorten only the visible Unicode name and preserve colors, brackets, and the full whisper target")
assert(module:Format("|Hplayer:Mira:9|h[Mira]|h") == "|Hplayer:Mira:9|h[Mira]|h")
assert(module:Format("|Hplayer:Friend:9|h[|Ksecret name|k]|h") == "|Hplayer:Friend:9|h[|Ksecret name|k]|h",
  "Protected names remain opaque")
assert(module:Format("|HBNplayer:Friend:9|h[First Last]|h") == "|HBNplayer:Friend:9|h[First Last]|h")
enabled.PlayerNames = true
assert(module:Format(fullName) == fullName, "Prat PlayerNames owns visible shortening")
enabled.PlayerNames = nil
profile.firstNamesOnly = false
module:Format("|Hplayer:Uncached:9|h[Uncached]|h")
profile.completePlayerNames = true
assert(module:CompletePlayerName("Uncached") == nil, "Disabled completion does not accumulate names")
for i = 1, 200 do module:Format("|Hplayer:Recent"..i..":10|h[Recent"..i.."]|h") end
assert(module:CompletePlayerName("Mira") == nil, "The recent name cache is bounded")
assert(module:CompletePlayerName("Recent200") == "Recent200")
local unitCalls = 0
local originalUnitName = UnitName
UnitName = function (...) unitCalls = unitCalls + 1; return originalUnitName(...) end
module:RefreshPlayers()
assert(unitCalls == 0, "Roster APIs are skipped when player formatting and icons are disabled")
profile.formatPlayerNames = true
local currentTarget = "NewTarget"
UnitName = function (unit) if unit == "target" then return currentTarget end end
for i = 1, 2000 do
  currentTarget = "Seen"..i
  eventFrame.callback(eventFrame, "PLAYER_TARGET_CHANGED")
end
assert(not module:Format(player):find("42", 1, true), "Old player metadata is evicted from its bounded cache")
print("PASS: native message formatting preserves links and protected text and defers to Prat")
