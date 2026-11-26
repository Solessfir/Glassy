-- Run from the repository root with Lua 5.1.
local module = {}
local core = {GetModule = function (_, name) assert(name == "TabPresets"); return module end}
local combat, denied, opens = false, false, 0
NUM_CHAT_WINDOWS, GUILD, PARTY = 5, "Guilde", "Groupe"
ChatTypeGroup = {}
for _, group in ipairs({"GUILD", "OFFICER", "GUILD_ACHIEVEMENT", "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER",
  "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER"}) do ChatTypeGroup[group] = {} end
InCombatLockdown = function () return combat end
local function frame(index, groups, shown)
  local object = {messageTypeList = groups or {}, channelList = {}, shown = shown, editBox = {}}
  object.editBox.chatFrame = object
  function object:IsShown() return self.shown end
  function object:AddMessageGroup(group) self.messageTypeList[#self.messageTypeList + 1] = group end
  _G["ChatFrame"..index] = object
  return object
end
local general = frame(1, {"GUILD", "PARTY", "SAY"}, true)
local log = frame(2, {}, true)
for index = 3, NUM_CHAT_WINDOWS do frame(index) end
GENERAL_CHAT_DOCK = {selected = general}
LAST_ACTIVE_CHAT_EDIT_BOX = general.editBox
FCFDock_GetSelectedWindow = function (dock) return dock.selected end
FCF_SelectDockFrame = function (selected) GENERAL_CHAT_DOCK.selected = selected end
ChatFrameUtil = {SetLastActiveWindow = function (editBox) LAST_ACTIVE_CHAT_EDIT_BOX = editBox end}
general.isDocked = true
FCF_GetChatWindowInfo = function (index) return "", nil, nil, nil, nil, nil, _G["ChatFrame"..index].shown end
FCF_OpenNewWindow = function (name, suppressDefault)
  assert(suppressDefault == true, "Native defaults must be suppressed")
  opens = opens + 1
  if denied then return end
  -- Model Classic's last-slot fallback, which would overwrite a custom tab without the preflight.
  for index = 1, NUM_CHAT_WINDOWS do
    local object = _G["ChatFrame"..index]
    if (index > 2 and not object.shown and not object.isDocked) or index == NUM_CHAT_WINDOWS then
      object.name, object.shown, object.isDocked = name, true, true
      object.messageTypeList, object.channelList = {}, {}
      GENERAL_CHAT_DOCK.selected = object
      LAST_ACTIVE_CHAT_EDIT_BOX = object.editBox
      return object, index
    end
  end
end
local nativeOpen = FCF_OpenNewWindow
assert(loadfile("Glassy/Modules/TabPresets.lua"))("Glassy", {core})
assert(opens == 0 and not module.OnEnable, "Loading the module never creates tabs or shows a prompt")
local options = module:GetOptions()
assert(options.inline and options.name == "Presets" and options.args.guild.name == "Create Guild tab")
combat = true
assert(options.args.guild.disabled() and not module:Create("guild") and opens == 0,
  "Combat must block native window changes even when called directly")
combat = false
denied = true
assert(not module:Create("guild") and module.status:find("could not create", 1, true))
assert(GENERAL_CHAT_DOCK.selected == general and LAST_ACTIVE_CHAT_EDIT_BOX == general.editBox)
denied = false
local ok, guild = module:Create("guild")
assert(ok and guild.name == "Guilde" and #guild.messageTypeList == 3)
assert(#general.messageTypeList == 3 and general.messageTypeList[1] == "GUILD" and #log.messageTypeList == 0,
  "General and Combat Log filters remain unchanged")
assert(GENERAL_CHAT_DOCK.selected == general and LAST_ACTIVE_CHAT_EDIT_BOX == general.editBox,
  "Creating a preset restores the native selected tab and edit target")
local previousOpens = opens
assert(options.args.guild.disabled() and not module:Create("guild") and opens == previousOpens,
  "A localized dedicated tab prevents duplicates")
guild.name, guild.messageTypeList = "My guild", {[2] = "GUILD"}
assert(not module:Create("guild") and opens == previousOpens, "A preexisting partial filter with holes is dedicated")
guild.messageTypeList = {"GUILD", "SAY"}
local custom = guild
ok, guild = module:Create("guild")
assert(ok and guild ~= custom and #custom.messageTypeList == 2,
  "Mixed custom tabs remain unchanged and do not replace a dedicated preset")
local channels = frame(5, {"PARTY"}, true)
channels.channelList = {"General"}
assert(options.args.party.disabled() and not module:Create("party") and opens == previousOpens + 1,
  "A full Classic client must never invoke its destructive last-slot fallback")
assert(channels.messageTypeList[1] == "PARTY" and channels.channelList[1] == "General")
channels.shown, channels.isDocked = false, false
ChatTypeGroup.GUILD_ACHIEVEMENT, ChatTypeGroup.INSTANCE_CHAT, ChatTypeGroup.INSTANCE_CHAT_LEADER = nil, nil, nil
ok, channels = module:Create("party")
assert(ok and channels.name == "Groupe" and #channels.messageTypeList == 5,
  "Only message groups supported by the client are registered")
previousOpens = opens
channels.name, channels.messageTypeList = "Grupo", {"PARTY"}
assert(not module:Create("party") and opens == previousOpens, "Arbitrarily named dedicated tabs prevent duplicates")
channels.isTemporary = true
assert(module:GetUnavailableReason("party"):find("No free", 1, true), "Temporary conversations are not dedicated presets")
channels.isTemporary, channels.shown, channels.isDocked = false, false, false
FCF_GetNextOpenChatWindowIndex = function () return nil end
assert(not module:Create("party") and opens == previousOpens, "Mainline capacity denial is respected")
FCF_GetNextOpenChatWindowIndex = function () return 5 end
FCF_OpenNewWindow = function () return custom end
assert(not module:Create("party") and #custom.messageTypeList == 2,
  "An unexpected native return never reconfigures an existing active custom tab")
FCF_OpenNewWindow = nativeOpen
FCF_OpenNewWindow = function () error("native denial") end
assert(not module:Create("party") and module.status:find("could not create", 1, true),
  "A native API error becomes an understandable status")
FCF_OpenNewWindow = nativeOpen
local previousAddGroup = channels.AddMessageGroup
channels.AddMessageGroup = nil
ChatFrame_AddMessageGroup = previousAddGroup
ok, channels = module:Create("party")
assert(ok and #channels.messageTypeList == 5, "Clients with the global message-group API are supported")
channels.shown, channels.isDocked = false, false
ChatFrame_AddMessageGroup = function () error("configuration denied") end
assert(not module:Create("party") and module.status:find("could not configure", 1, true),
  "Configuration errors leave a visible status and restore selection")
assert(GENERAL_CHAT_DOCK.selected == general and LAST_ACTIVE_CHAT_EDIT_BOX == general.editBox)
ChatFrame_AddMessageGroup = nil
ChatTypeGroup.PARTY = nil
assert(options.args.party.disabled(), "Missing required chat APIs produce a disabled action")
assert(FCF_OpenNewWindow == nativeOpen, "Native APIs are never replaced")
print("PASS: native tab presets preserve existing filters, selection, duplicates and full-window safety")
