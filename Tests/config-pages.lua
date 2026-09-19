unpack = unpack or table.unpack

local config = {}
local profileTransfer = {}
local function action()
  return {}
end

local core = {
  Libs = {
    AceConfig = {},
    AceConfigDialog = {},
    AceDBOptions = {},
    AceGUI = {},
    LSM = {},
  },
  GetModule = function (_, name)
    if name == "Config" then
      return config
    end
    if name == "ProfileTransfer" then
      return profileTransfer
    end
    return {}
  end,
  Localize = function (_, text) return text end,
}
local constants = {
  ACTIONS = {
    LockMover = action,
    OpenNews = action,
    RefreshConfig = action,
    UnlockMover = action,
    UpdateConfig = action,
  },
  EVENTS = {SAVE_FRAME_POSITION = "save-frame-position"},
}
local addonVars = {core, constants}

for _, file in ipairs({
  "Config",
  "ConfigProfiles",
  "ConfigChatPages",
  "ConfigMessagePages",
  "ConfigSupportPages",
}) do
  assert(loadfile("Glassy/Modules/"..file..".lua"))("Glassy", addonVars)
end

for _, page in ipairs({
  "general",
  "editBox",
  "messages",
  "timestamps",
  "combatLog",
  "compatibility",
  "shortcuts",
  "profile",
  "about",
}) do
  assert(type(config.Pages[page]) == "function", "Missing config page: "..page)
end

assert(type(config.IsMoverUnlocked) == "function")
assert(type(config.ToggleMover) == "function")
assert(type(config.GetTimestampFrameOptions) == "function")
assert(type(config.DisableBuiltinTimestamps) == "function")
assert(type(config.ShowCopyableText) == "function")

print("PASS: config core and page modules load in TOC order and register every settings page")
