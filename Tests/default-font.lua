strmatch = string.match
assert(loadfile("libs/LibStub/LibStub.lua"))()
assert(loadfile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
CreateFrame = function() return {RegisterEvent = function() end, SetScript = function() end} end
GetRealmName = function() return "Realm" end
UnitName = function() return "Player" end
UnitClass = function() return "Rogue", "ROGUE" end
UnitRace = function() return "Human", "Human" end
UnitFactionGroup = function() return "Alliance", "Alliance" end
GetCurrentRegion = function() return 1 end
GetLocale = function() return "enUS" end
assert(loadfile("libs/AceDB-3.0/AceDB-3.0.lua"))()

local addon = {NewModule = function() end}
local media = {Friz = "Fonts\\FRIZQT__.TTF", Gilroy = "Interface\\Fonts\\Gilroy.ttf"}
local libraries = {
  ["AceAddon-3.0"] = {NewAddon = function() return addon end},
  ["LibSharedMedia-3.0"] = {
    GetDefault = function() return "Friz" end,
    HashTable = function() return media end,
    List = function() return {"Friz", "Gilroy"} end,
  },
  ["AceDB-3.0"] = LibStub("AceDB-3.0"),
}
local realLibStub = LibStub
LibStub = setmetatable({}, {
  __index = realLibStub,
  __call = function(_, name) return libraries[name] or realLibStub.libs[name] or {} end,
})
local deferred
C_Timer = {After = function(_, callback) deferred = callback end}
local vars = {}
assert(loadfile("Glassy/init.lua"))("Glassy", vars)
vars[2].ACTIONS = {UpdateConfig = function(key) return "update", key end}

for _, saved in ipairs({false, "Custom font", "Glassy: Game default"}) do
  GlassyDB = {profiles = {Default = {font = saved or nil}}}
  GameFontNormal = {GetFont = function() return media.Friz end}
  addon:OnInitialize()
  addon:OnEnable()
  assert(addon.db.profile.font == (saved or "Friz"))
  GameFontNormal.GetFont = function() return "interface/fonts/GILROY.ttf" end
  deferred()
  assert(addon.defaults.profile.font == "Gilroy")
  assert(addon.db.profile.font == (saved == "Custom font" and saved or "Gilroy"))
  addon.db:ResetProfile()
  assert(addon.db.profile.font == "Gilroy", "Reset must select the detected font")
end

print("PASS: late UI font detection selects real names, migrates the alias, and preserves custom fonts")
