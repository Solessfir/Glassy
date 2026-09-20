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
  "tabs",
  "editBox",
  "messages",
  "combatLog",
  "compatibility",
  "shortcuts",
  "profile",
  "about",
}) do
  assert(type(config.Pages[page]) == "function", "Missing config page: "..page)
end

---@diagnostic disable-next-line: undefined-global
local configFile = assert(io.open("Glassy/Modules/Config.lua", "r"))
local configSource = configFile:read("*a")
configFile:close()
assert(configSource:find("tabs%s*=%s*C%.Pages%.tabs%(%s*%)"), "Tabs page is not included in the main config")
assert(configSource:find("combatLog%.inline%s*=%s*true"), "Combat Log is not an inline Tabs section")
assert(configSource:find("shortcuts%.inline%s*=%s*true"), "Shortcuts is not an inline About section")
assert(configSource:find("compatibility%.inline%s*=%s*true"), "Compatibility is not an inline About section")
assert(config.Pages.timestamps == nil, "Timestamps should not be a separate config page")

---@diagnostic disable-next-line: undefined-global
local messagePagesFile = assert(io.open("Glassy/Modules/ConfigMessagePages.lua", "r"))
local messagePagesSource = messagePagesFile:read("*a")
messagePagesFile:close()
assert(messagePagesSource:find("timestampsEnabled%s*=%s*{"), "Timestamp settings are missing from Messages appearance")

---@diagnostic disable-next-line: undefined-global
local chatPagesFile = assert(io.open("Glassy/Modules/ConfigChatPages.lua", "r"))
local chatPagesSource = chatPagesFile:read("*a")
chatPagesFile:close()
assert(not chatPagesSource:find("dynamicEditBox", 1, true), "Dynamic message area is still configurable")
assert(chatPagesSource:find("hoverHighlightStrength", 1, true), "Shared hover highlight is missing from General")
assert(not messagePagesSource:find("combatLogHoverHighlightStrength", 1, true), "Combat Log still has a separate hover highlight")

assert(type(config.IsMoverUnlocked) == "function")
assert(type(config.ToggleMover) == "function")
assert(type(config.GetTimestampFrameOptions) == "function")
assert(type(config.DisableBuiltinTimestamps) == "function")
assert(type(config.ShowCopyableText) == "function")

print("PASS: config core and page modules load in TOC order and register every settings page")
