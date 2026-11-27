-- Run from the repository root with Lua 5.1.
---@diagnostic disable: undefined-global
local utilities, timers, callbacks, overlaps = {}, {}, {}, {}
local channels = {1, "General - Stormwind", false, 4, "My Multi Word Channel", false}
local writes, whispers, loggingWrites = {}, {}, {}
local secret = {}
issecretvalue = function (value) return value == secret end
canaccessvalue = function (value) return value ~= secret end
C_Timer = {After = function (_, callback) timers[#timers + 1] = callback end}
local function flush()
  while #timers > 0 do table.remove(timers, 1)() end
end
CreateFrame = function ()
  return {RegisterEvent = function () end, UnregisterAllEvents = function () end,
    SetScript = function (self, _, callback) self.event = callback end}
end
GetChannelList = function () return unpack(channels) end
ChatTypeInfo = {SAY = {sticky = 1}, YELL = {sticky = 0}, CHANNEL = {sticky = 1},
  CHANNEL1 = {r = 0.9, g = 0.6, b = 0.3}, CHANNEL4 = {r = 0.1, g = 0.2, b = 0.3}}
ChangeChatColor = function (chatType, red, green, blue)
  writes[#writes + 1] = {chatType, red, green, blue}
  ChatTypeInfo[chatType] = {r = red, g = green, b = blue}
  if utilities.eventFrame then utilities.eventFrame:event("UPDATE_CHAT_COLOR", chatType, red, green, blue) end
end
SlashCmdList, hash_SlashCmdList = {}, {}
function utilities:RegisterChatCommand(command, callback)
  assert(command == "tt")
  SlashCmdList.ACECONSOLE_TT = callback
  SLASH_ACECONSOLE_TT1 = "/tt"
end
function utilities:UnregisterChatCommand(command)
  assert(command == "tt")
  SlashCmdList.ACECONSOLE_TT, SLASH_ACECONSOLE_TT1, hash_SlashCmdList["/TT"] = nil, nil, nil
end
local player, friendly, human, connected, character, realm = true, true, true, true, "Alice", "Other Realm"
UnitIsPlayer = function () return player end
UnitCanCooperate = function () return friendly end
UnitIsHumanPlayer = function () return human end
UnitIsConnected = function () return connected end
UnitName = function () return character, realm end
ChatFrameUtil = {SendTellWithMessage = function (...) whispers[#whispers + 1] = {...} end}
local chatLogging, combatLogging = false, true
LoggingChat = function (enabled)
  if enabled ~= nil then chatLogging = enabled; loggingWrites[#loggingWrites + 1] = {"chat", enabled} end
  return chatLogging
end
LoggingCombat = function (enabled)
  if enabled ~= nil then combatLogging = enabled; loggingWrites[#loggingWrites + 1] = {"combat", enabled} end
  return combatLogging
end
local function savedColors()
  return setmetatable({}, {__index = function (self, name)
    local color = {r = 0, g = 0, b = 0}
    rawset(self, name, color)
    return color
  end})
end
local profile = {stickyChatTypes = {}, rememberChannelColors = false, whisperTarget = false, channelColors = savedColors()}
local core = {db = {profile = profile}, GetModule = function () return utilities end,
  IsPratModuleEnabled = function (_, module) return overlaps[module] end,
  Subscribe = function (_, _, callback) callbacks[#callbacks + 1] = callback end,
  Dispatch = function (_, key) for _, callback in ipairs(callbacks) do callback(key) end end}
local constants = {EVENTS = {UPDATE_CONFIG = "config"}, ACTIONS = {UpdateConfig = function (key) return key end}}
assert(loadfile("Glassy/Modules/ChatUtilities.lua"))("Glassy", {core, constants})
utilities:OnEnable()
assert(#writes == 0 and #loggingWrites == 0 and not SLASH_ACECONSOLE_TT1)
assert(ChatTypeInfo.SAY.sticky == 1 and ChatTypeInfo.YELL.sticky == 0)

local options = utilities:BuildOptions().args
options.sticky.args.YELL.set(nil, "sticky")
assert(ChatTypeInfo.YELL.sticky == 1)
options.sticky.args.YELL.set(nil, "default")
assert(ChatTypeInfo.YELL.sticky == 0 and profile.stickyChatTypes.YELL == nil)
options.sticky.args.SAY.set(nil, "reset")
assert(ChatTypeInfo.SAY.sticky == 0)
ChatTypeInfo.SAY.sticky = 7
options.sticky.args.SAY.set(nil, "default")
assert(ChatTypeInfo.SAY.sticky == 7, "Releasing ownership preserves another addon's later setting")
overlaps.ChannelSticky = true
options.sticky.args.YELL.set(nil, "sticky")
assert(ChatTypeInfo.YELL.sticky == 0 and options.sticky.args.YELL.disabled())
overlaps.ChannelSticky = false
utilities:ApplySettings()
assert(ChatTypeInfo.YELL.sticky == 1)

options.rememberChannelColors.set(nil, true)
assert(rawget(profile.channelColors, "General - Stormwind").r == 0.9, "Wildcard defaults cannot invent black channel colors")
assert(rawget(profile.channelColors, "My Multi Word Channel").r == 0.1)
ChangeChatColor("CHANNEL4", 0.8, 0.4, 0.2)
assert(profile.channelColors["My Multi Word Channel"].r == 0.8)
channels = {1, "Unrelated", false, 8, "My Multi Word Channel", false}
ChatTypeInfo.CHANNEL8 = {r = 0, g = 1, b = 0}
utilities.eventFrame:event("CHANNEL_UI_UPDATE")
flush()
assert(ChatTypeInfo.CHANNEL8.r == 0.8, "Channel colors follow the exact name across number changes")
assert(profile.channelColors["Unrelated"].r == 0.9, "A different channel does not inherit a remembered name")
local remembered = profile.channelColors["My Multi Word Channel"]
utilities:RememberColor("CHANNEL8", secret, 0, 0)
assert(profile.channelColors["My Multi Word Channel"] == remembered)
overlaps.ChannelColorMemory = true
local before = #writes
utilities:ApplyChannelColors()
utilities:RememberColor("CHANNEL8", 0, 0, 0)
assert(#writes == before and profile.channelColors["My Multi Word Channel"] == remembered)
overlaps.ChannelColorMemory = false
options.rememberChannelColors.set(nil, false)
before = #writes
utilities.eventFrame:event("CHANNEL_UI_UPDATE")
flush()
assert(#writes == before)

SLASH_FOREIGN1 = "/tt"
options.whisperTarget.set(nil, true)
assert(not utilities.targetCommand and options.whisperTarget.disabled())
SLASH_FOREIGN1 = nil
utilities:ApplySettings()
assert(utilities.targetCommand and not options.whisperTarget.disabled())
local chatFrame = {}
SlashCmdList.ACECONSOLE_TT("hello", {chatFrame = chatFrame})
assert(#whispers == 1 and whispers[1][1] == "Alice-Other Realm" and whispers[1][2] == "hello" and whispers[1][3] == chatFrame)
for _, invalid in ipairs({"player", "friendly", "human", "connected", "name", "realm", "secretFlag"}) do
  player, friendly, human, connected, character, realm = true, true, true, true, "Alice", "Realm"
  if invalid == "player" then player = false elseif invalid == "friendly" then friendly = false
  elseif invalid == "human" then human = false elseif invalid == "connected" then connected = false
  elseif invalid == "name" then character = secret elseif invalid == "realm" then realm = secret else player = secret end
  utilities:WhisperTarget("draft")
  assert(#whispers == 1, "Unsafe or illegal target must not open a whisper: "..invalid)
end
player, character, realm = true, "Alice", nil
utilities:WhisperTarget("")
assert(#whispers == 2 and whispers[2][1] == "Alice")
local foreignHandler = function () end
SlashCmdList.ACECONSOLE_TT = foreignHandler
options.whisperTarget.set(nil, false)
assert(SlashCmdList.ACECONSOLE_TT == foreignHandler, "Disabling does not unregister a replacement command")
SlashCmdList.ACECONSOLE_TT, SLASH_ACECONSOLE_TT1 = nil, nil

assert(not options.logging.args.chat.get() and options.logging.args.combat.get() and #loggingWrites == 0)
options.logging.args.chat.set(nil, true)
assert(chatLogging and #loggingWrites == 1)
overlaps.ChatLog = true
options.logging.args.combat.set(nil, false)
assert(combatLogging and #loggingWrites == 1 and options.logging.args.combat.disabled())
overlaps.ChatLog = false
local oldProfile = core.db.profile
core.db.profile = {stickyChatTypes = {SAY = "sticky"}, channelColors = {}, rememberChannelColors = false, whisperTarget = false}
core:Dispatch("chatUtilities")
assert(ChatTypeInfo.SAY.sticky == 1 and ChatTypeInfo.YELL.sticky == 0, "Profile switches release previous sticky overrides")
utilities:OnDisable()
assert(ChatTypeInfo.SAY.sticky == 7 and #loggingWrites == 1 and not utilities.targetCommand)
core.db.profile = oldProfile
print("PASS: Opt-in sticky overrides, named channel colors, safe target drafts, command ownership, and explicit native logging")
