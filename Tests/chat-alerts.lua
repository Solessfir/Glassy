-- Run from the repository root with Lua 5.1 or LuaJIT.
local secret = setmetatable({}, {__tostring = function () error("Secret value inspected") end})
canaccessvalue = function (value) return value ~= secret end
issecretvalue = function (value) return value == secret end
UnitName = function () return "Mira" end
UnitFullName = function () return "Mira", "Home Realm" end
UnitGUID = function () return "Player-self" end
SOUNDKIT = {READY_CHECK = 8960, IG_MAINMENU_OPTION_CHECKBOX_ON = 856}
local handlers, registered, timers, played = {}, {}, {}, {}
local popups = 0
C_Timer = {After = function (_, callback) timers[#timers + 1] = callback end}
UIParent = {}
CreateFrame = function (_, _, parent)
  local frame = {shown = false}
  function frame:RegisterEvent(event) registered[event] = true end
  function frame:UnregisterAllEvents() registered = {} end
  function frame:SetScript(script, callback) handlers[script] = callback end
  function frame:SetSize() end
  function frame:SetPoint() end
  function frame:SetFrameStrata() end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:CreateTexture() return {SetAllPoints = function () end, SetColorTexture = function () end} end
  function frame:CreateFontString()
    return {SetPoint = function () end, SetWordWrap = function () end,
      SetText = function (_, text) popups = popups + 1; frame.lastText = text end}
  end
  return frame
end
PlaySoundFile = function (path, channel)
  assert(channel == "Master")
  played[#played + 1] = path
end
PlaySound = function (kit, channel) assert(channel == "Master"); played[#played + 1] = kit end
local profile, enabled, module = {}, {}, {}
local media = {Bell = "bell.ogg", Chime = "chime.ogg"}
local core = {
  db = {profile = profile},
  Libs = {LSM = {
    Fetch = function (_, kind, name) assert(kind == "sound"); return media[name] end,
    HashTable = function (_, kind) assert(kind == "sound"); return media end,
  }},
  Localize = function (_, text) return text end,
  IsPratModuleEnabled = function (_, name) return enabled[name] end,
  GetModule = function (_, name)
    if name == "TextProcessing" then return {IsMessageBlacklisted = function (_, text) return text == "blocked Mira" end} end
    assert(name == "ChatAlerts")
    return module
  end,
}
local utils = {}
assert(loadfile("Glassy/utils.lua"))("Glassy", {core, {}, utils})
assert(loadfile("Glassy/Modules/ChatAlerts.lua"))("Glassy", {core, {}, utils})
module:OnEnable()
assert(registered.CHAT_MSG_GUILD and registered.CHAT_MSG_CHANNEL and registered.CHAT_MSG_BN_WHISPER_INFORM)
local function receive(event, text, author, channel, id, guid)
  handlers.OnEvent(nil, event, text, author or "Other-Realm", "", "", "", "", 0, channel or 0, "", 0, id or 10, guid or "Player-other")
end
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == 0 and popups == 0, "All alerts are opt-in")
local originalGUID = UnitGUID
UnitGUID = function () error("Disabled alerts must not look up player state") end
receive("CHAT_MSG_GUILD", "disabled")
UnitGUID = originalGUID
profile.chatAlertOwnName, profile.chatAlertSound, profile.chatAlertPopup = true, "Bell", true
receive("CHAT_MSG_GUILD", "hello MIRA!")
assert(#played == 1 and popups == 1 and module.popup.lastText == "Other-Realm: hello MIRA!")
receive("CHAT_MSG_GUILD", "Mirabelle")
receive("CHAT_MSG_GUILD", "prefix_Mira")
receive("CHAT_MSG_GUILD", "Miraé")
assert(#played == 1 and popups == 1, "Names match whole words only")
profile.chatAlertWords = " tank ready , C++\n100%"
receive("CHAT_MSG_GUILD", "TANK READY?")
receive("CHAT_MSG_GUILD", "C++ now")
receive("CHAT_MSG_GUILD", "100% done")
assert(#played == 4 and popups == 4, "Custom phrases are case-insensitive literals")
receive("CHAT_MSG_GUILD", "|Hitem:1:Mira|h[Other item]|h")
receive("CHAT_MSG_GUILD", "|Ttexture:Mira|t")
receive("CHAT_MSG_GUILD", "|Kprivate Mira|k")
assert(#played == 4, "Link data, textures and hidden names cannot trigger alerts")
receive("CHAT_MSG_GUILD", "|Hitem:1|h[Mira's item]|h")
assert(#played == 5 and module.popup.lastText == "Other-Realm: [Mira's item]")
local before = #played
receive("CHAT_MSG_GUILD", secret)
receive("CHAT_MSG_GUILD", "Mira", secret)
receive("CHAT_MSG_GUILD", "blocked Mira")
receive("CHAT_MSG_GUILD", "Mira", "Other-Realm", 0, 10, "Player-self")
receive("CHAT_MSG_WHISPER_INFORM", "Mira")
assert(#played == before, "Secrets, blacklisted lines and outgoing mentions never alert")
local popupBefore = popups
receive("CHAT_MSG_WHISPER", "Mira")
receive("CHAT_MSG_BN_WHISPER", "Mira")
assert(#played == before and popups == popupBefore + 2, "Blizzard keeps incoming whisper sound; mention popups remain available")
profile.chatSounds = {GUILD = "Chime", CHANNEL = "Bell", CHANNEL2 = "Chime"}
profile.chatOutgoingSounds = {GUILD = "Bell", WHISPER = "Chime", CHANNEL2 = "Bell"}
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before + 1 and played[#played] == "chime.ogg", "Channel sound replaces mention sound on the same line")
receive("CHAT_MSG_GUILD", "own message", "Mira", 0, 10, "Player-self")
assert(played[#played] == "bell.ogg")
receive("CHAT_MSG_WHISPER_INFORM", "reply")
assert(played[#played] == "chime.ogg")
receive("CHAT_MSG_CHANNEL", "trade", "Other-Realm", 2)
assert(played[#played] == "chime.ogg")
receive("CHAT_MSG_CHANNEL", "general", "Other-Realm", 1)
assert(played[#played] == "bell.ogg")
profile.chatSounds.CHANNEL1 = ""
receive("CHAT_MSG_CHANNEL", "empty wildcard falls back", "Other-Realm", 1)
assert(played[#played] == "bell.ogg")
receive("CHAT_MSG_CHANNEL", "outgoing trade", "Mira-HomeRealm", 2, 10, "Player-self")
assert(played[#played] == "bell.ogg")
local outgoingSounds, savedCount = profile.chatOutgoingSounds, #played
profile.chatOutgoingSounds = nil
receive("CHAT_MSG_GUILD", "outgoing without a map", "Mira", 0, 10, "Player-self")
assert(#played == savedCount, "An absent outgoing map never inherits incoming sounds")
profile.chatOutgoingSounds = outgoingSounds
before, popupBefore = #played, popups
enabled.Sounds = true
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before and popups == popupBefore + 1, "Prat Sounds owns all sound playback")
enabled.Sounds, enabled.PopupMessage = false, true
profile.chatSounds.GUILD = nil
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before and popups == popupBefore + 1, "Prat PopupMessage owns mention popups and their sound")
enabled.PopupMessage, enabled.Mentions = false, true
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before and popups == popupBefore + 1, "Prat Mentions owns mention triggers")
enabled.Mentions = false
C_ChatInfo = {IsChatLineCensored = function (id) return id == 11 end}
receive("CHAT_MSG_GUILD", "Mira", nil, 0, 11)
C_ChatInfo.IsChatLineCensored = function () return secret end
receive("CHAT_MSG_GUILD", "Mira")
C_ChatInfo.IsChatLineCensored = function () error("unavailable") end
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before and popups == popupBefore + 1, "Censored or unreadable censorship state never triggers an alert")
C_ChatInfo = nil
receive("CHAT_MSG_GUILD", "Mira")
local lastTimer = #timers
timers[lastTimer - 1]()
assert(module.popup.shown, "An earlier popup timer cannot hide a newer message")
timers[lastTimer]()
assert(not module.popup.shown)

local options = module:BuildOptions()
local mentions, sounds = options.args.mentions.args, options.args.sounds.args
assert(mentions.sound.values().Bell == "Bell" and mentions.sound.values()[""] == "None")
assert(mentions.sound.values()["builtin:READY_CHECK"] == "Ready check")
sounds.channel.set(nil, "CHANNEL3")
sounds.incoming.set(nil, "Chime")
assert(profile.chatSounds.CHANNEL3 == "Chime" and sounds.incoming.get() == "Chime")
sounds.incoming.set(nil, "")
assert(profile.chatSounds.CHANNEL3 == nil and sounds.incoming.get() == "")
sounds.channel.set(nil, "WHISPER")
assert(sounds.incoming.disabled() and not sounds.outgoing.disabled())
enabled.PopupMessage = true
assert(mentions.popup.disabled() and mentions.sound.disabled())
enabled.PopupMessage = nil
module:OnDisable()
assert(next(registered) == nil and not module.popup.shown)
canaccessvalue, issecretvalue = nil, nil
module:OnEnable()
receive("CHAT_MSG_GUILD", "Mira")
assert(#played == before + 2, "Classic clients without secret APIs still receive alerts")
profile.chatAlertWords = "Йог, Élodie"
assert(module:Matches("йог") and module:Matches("ÉLODIE"), "Alert matching uses locale-aware case folding")
profile.chatAlertWords = "literal"
receive("CHAT_MSG_GUILD", "literal ||cffff0000red||r")
assert(module.popup.lastText == "Other-Realm: literal ||cffff0000red||r", "Typed pipe markup stays literal in the popup")
local savedMedia = media
media = {}
assert(module:PlaySound("builtin:READY_CHECK") and played[#played] == 8960,
  "Fresh installations can select Blizzard sounds without additional media addons")
media = savedMedia
print("PASS: live chat alerts, literal mentions, popups, channel directions, native whispers and Prat ownership")
