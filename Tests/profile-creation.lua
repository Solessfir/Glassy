-- Run from the repository root: lua Tests/profile-creation.lua
unpack = unpack or table.unpack
strmatch = string.match
securecallfunction = function (callback, ...) return callback(...) end
strlenutf8 = function (value)
  local _, count = value:gsub("[^\128-\191]", "")
  return count
end
CreateFrame = function () return {RegisterEvent = function () end, SetScript = function () end} end
GetRealmName = function () return "Realm" end
UnitName = function () return "Player" end
UnitNameUnmodified = UnitName
UnitClass = function () return "Rogue", "ROGUE" end
UnitRace = function () return "Human", "Human" end
UnitFactionGroup = function () return "Alliance", "Alliance" end
GetCurrentRegion = function () return 1 end
GetCurrentRegionName = function () return "US" end
GetLocale = function () return "enUS" end
GetBuildInfo = function () return "", "", "", 11509 end
assert(loadfile("libs/LibStub/LibStub.lua"))()
assert(loadfile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua"))()
assert(loadfile("libs/AceDB-3.0/AceDB-3.0.lua"))()
assert(loadfile("libs/AceDBOptions-3.0/AceDBOptions-3.0.lua"))()

local saved = {
  profiles = {
    Shared = {
      frameWidth = 900, color = {r = 0.2}, tabOrder = {"ChatFrame7", "ChatFrame2"},
      selectedTab = "ChatFrame7", timestampFrames = {ChatFrame7 = false}, settingsVersion = 9,
    },
    Other = {frameWidth = 750},
  },
  profileKeys = {["Player - Realm"] = "Shared", ["Alt - Realm"] = "Shared", ["Mage - Realm"] = "Other"},
  char = {["Player - Realm"] = {history = {"Private message"}}, ["Alt - Realm"] = {history = {"Alt message"}}},
  global = {slashAliases = {rld = "/reload"}},
}
local defaults = {profile = {
  frameWidth = 600, color = {r = 1, g = 1}, tabOrder = {}, selectedTab = "", timestampFrames = {["*"] = true},
}}
local config = {Pages = {}, refreshes = 0, messages = {}}
function config:RefreshConfig()
  self.refreshes = self.refreshes + 1
  -- Profile callbacks must never apply the source character's native tab IDs.
  assert(self.allowNativeTabIds or self.db.profile.selectedTab ~= "ChatFrame7")
end
function config:Print(message) self.messages[#self.messages + 1] = message end
local notifications = 0
local core = {
  db = LibStub("AceDB-3.0"):New(saved, defaults, true),
  defaults = defaults,
  Libs = {
    AceDBOptions = LibStub("AceDBOptions-3.0"),
    AceConfigRegistry = {NotifyChange = function (_, name)
      assert(name == "Glassy")
      notifications = notifications + 1
    end},
  },
}
config.db = core.db
function core:Localize(text) return text end
function core:GetModule(name)
  if name == "Config" then return config end
  return {}
end
core.db.RegisterCallback(config, "OnProfileChanged", "RefreshConfig")
assert(loadfile("Glassy/Modules/ConfigProfiles.lua"))("Glassy", {core})
local options = config.Pages.profile()
local new = options.args.new.args
assert(core.db:GetCurrentProfile() == "Shared", "Opening settings must not create or select a profile")
assert(new.startFrom.get() == "" and new.startFrom.values()[""] == "Defaults")
assert(new.startFrom.values().Shared == "Shared (Alt - Realm, Player - Realm)")
assert(new.startFrom.values().Other == "Other (Mage - Realm)")
assert(options.args.choose.name == "Use existing profile")
assert(options.args.choose.values().ROGUE == nil, "Shared selector must only list existing profiles")
assert(new.create.disabled())
assert(new.name.validate(nil, "  Shared ") ~= true)
assert(new.name.validate(nil, "   ") ~= true)
assert(new.name.validate(nil, string.rep("a", 51)) ~= true)
assert(new.name.validate(nil, string.rep("Я", 50)) == true, "Name limit counts Unicode characters")
saved.profileKeys["Unknown - Realm"] = "Reserved"
assert(new.name.validate(nil, "Reserved") ~= true, "An unmaterialized shared profile name is still reserved")
new.name.set(nil, " Shared ")
new.create.func()
assert(core.db:GetCurrentProfile() == "Shared" and saved.profiles.Shared.frameWidth == 900)

new.name.set(nil, " Player settings ")
new.startFrom.set(nil, "Shared")
assert(not new.create.disabled())
new.create.func()
assert(core.db:GetCurrentProfile() == "Player settings")
assert(saved.profileKeys["Player - Realm"] == "Player settings" and saved.profileKeys["Alt - Realm"] == "Shared")
assert(core.db.profile.frameWidth == 900 and core.db.profile.settingsVersion == 9)
assert(core.db.profile.color.r == 0.2 and core.db.profile.color.g == 1)
assert(core.db.profile.selectedTab == "" and next(core.db.profile.tabOrder) == nil)
assert(core.db.profile.timestampFrames.ChatFrame7 == true, "Character-specific timestamp references must use defaults")
assert(saved.profiles.Shared.selectedTab == "ChatFrame7" and saved.profiles.Shared.tabOrder[1] == "ChatFrame7")
assert(saved.profiles.Shared.timestampFrames.ChatFrame7 == false)
assert(saved.char["Player - Realm"].history[1] == "Private message" and saved.char["Alt - Realm"].history[1] == "Alt message")
assert(saved.global.slashAliases.rld == "/reload")
assert(notifications == 1 and config.refreshes == 2)
assert(new.name.get() == "" and new.startFrom.get() == "")
core.db.profile.color.r = 0.8
assert(saved.profiles.Shared.color.r == 0.2, "Copied nested settings must be independent")

new.name.set(nil, "Fresh")
new.create.func()
assert(core.db:GetCurrentProfile() == "Fresh" and core.db.profile.frameWidth == 600)
assert(core.db.profile.settingsVersion == nil and notifications == 2)
assert(core.db.profile.selectedTab == "" and next(core.db.profile.tabOrder) == nil)
new.name.set(nil, "Inactive copy")
new.startFrom.set(nil, "Player settings")
new.create.func()
assert(core.db:GetCurrentProfile() == "Inactive copy" and core.db.profile.color.r == 0.8)
core.db.profile.color.r = 0.5
assert(saved.profiles["Player settings"].color.r == 0.8, "Inactive sources must remain independent")
new.name.set(nil, "Unavailable source")
new.startFrom.set(nil, "Other")
core.db:DeleteProfile("Other")
assert(new.create.disabled())
new.create.func()
assert(core.db:GetCurrentProfile() == "Inactive copy" and saved.profiles["Unavailable source"] == nil)

local replace = options.args.manage.args.copyfrom
assert(replace.confirm(nil, "Shared"):find("All characters", 1, true))
assert(replace.confirm(nil, "Shared"):find("Inactive copy", 1, true))
assert(options.args.manage.args.reset.confirm():find("All characters", 1, true))
config.allowNativeTabIds = true
options.handler[replace.set](options.handler, {}, "Shared")
assert(core.db:GetCurrentProfile() == "Inactive copy" and core.db.profile.frameWidth == 900)
assert(core.db.profile.selectedTab == "ChatFrame7", "Confirmed replacement must retain existing AceDB copy behavior")
options.handler[options.args.choose.set](options.handler, {}, "Shared")
assert(core.db:GetCurrentProfile() == "Shared" and saved.profileKeys["Player - Realm"] == "Shared")

print("PASS: new profiles copy settings independently, default safely, retain character data, and confirm shared replacements")
