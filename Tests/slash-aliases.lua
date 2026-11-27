unpack = unpack or table.unpack

local aliases, listeners, output = {}, {}, {}
local refreshes = 0
local saved = {slashAliases = {}}
local profile = {slashAliasesEnabled = true}
local core = {
  db = {global = saved, profile = profile},
  Libs = {AceConfigRegistry = {NotifyChange = function (_, app)
    assert(app == "Glassy")
    refreshes = refreshes + 1
  end}},
  GetModule = function () return aliases end,
  Localize = function (_, text) return text end,
  Subscribe = function (_, event, fn) listeners[event] = fn end,
}
local reloads, invocation, locked = 0
function ReloadUI() reloads = reloads + 1 end
function IsSecureCmd(command) return command:lower() == "/target" end
C_ChatInfo = {InChatMessagingLockdown = function () return locked end}
SlashCmdList = {DEMO = function (text, editBox) invocation = {text, editBox} end}
SLASH_DEMO1 = "/demo"
hash_SlashCmdList = {["/OTHER"] = function () end}
hash_ChatTypeInfoList = {["/S"] = "SAY"}
local management = {}
function aliases:RegisterChatCommand(name, method) management[name] = method end
function aliases:IsEnabled() return true end

local utils = {notify = function (text) output[#output + 1] = text end}
assert(loadfile("Glassy/Modules/SlashAliases.lua"))("Glassy", {core, {EVENTS = {UPDATE_CONFIG = "update"}}, utils})
aliases:OnEnable()
assert(management.alias == "Set" and management.unalias == "Remove" and management.listaliases == "List")
local name, expansion = aliases:ParseDefinition("/rld = /demo fixed")
assert(name == "rld" and expansion == "/demo fixed" and next(saved.slashAliases) == nil,
  "Settings validation uses the same grammar as slash commands and does not install the alias")
assert(aliases:Set("rl /reload") == "rl")
assert(saved.slashAliases.rl == "/reload" and SLASH_GLASSYALIAS_RL1 == "/rl")
assert(output[#output] == "/rl -> /reload", "Alias feedback uses the shared Glassy notifier")
assert(refreshes == 1, "Adding an alias refreshes the settings list")
SlashCmdList.GLASSYALIAS_RL("")
assert(reloads == 1)
locked = true
SlashCmdList.GLASSYALIAS_RL("")
assert(reloads == 1)
locked = false

aliases:Set("/dd = /demo fixed")
local editBox = {}
SlashCmdList.GLASSYALIAS_DD("additional value", editBox)
assert(invocation[1] == "fixed additional value" and invocation[2] == editBox)
local previousHandler = SlashCmdList.GLASSYALIAS_DD
aliases:Set("/dd = /demo changed")
assert(SlashCmdList.GLASSYALIAS_DD == previousHandler and saved.slashAliases.dd == "/demo changed")
previousHandler("argument", editBox)
assert(invocation[1] == "changed argument", "Editing an alias updates the active registered shortcut")
aliases:Set("s /reload")
aliases:Set("other /reload")
aliases:Set("unsafe /target")
aliases:Set("looper /rl")
assert(not (saved.slashAliases.s or saved.slashAliases.other or saved.slashAliases.unsafe or saved.slashAliases.looper))

hash_SlashCmdList["/RL"] = SlashCmdList.GLASSYALIAS_RL
hash_ChatTypeInfoList["/RL"] = "GLASSYALIAS_RL"
profile.slashAliasesEnabled = false
listeners.update("slashAliasesEnabled")
assert(not hash_SlashCmdList["/RL"] and not hash_ChatTypeInfoList["/RL"] and saved.slashAliases.rl)
profile.slashAliasesEnabled = true
listeners.update("slashAliasesEnabled")
assert(SlashCmdList.GLASSYALIAS_RL)
aliases:OnDisable()
assert(not SlashCmdList.GLASSYALIAS_RL and not SLASH_GLASSYALIAS_RL1, "Disabling removes registered aliases")
aliases:OnEnable()
assert(SlashCmdList.GLASSYALIAS_RL and SLASH_GLASSYALIAS_RL1 == "/rl", "Re-enabling restores saved aliases")
aliases:List()
assert(output[#output]:find("/rl", 1, true))
aliases:Remove("/rl")
assert(not saved.slashAliases.rl and not SlashCmdList.GLASSYALIAS_RL)
assert(refreshes == 4, "Removing an alias refreshes the settings list")

print("PASS: slash aliases persist, pass arguments, respect lockdown and conflicts, and can be disabled or removed")
