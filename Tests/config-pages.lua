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
  "commands",
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
assert(configSource:find("commands%.inline%s*=%s*true"), "Commands is not an inline About section")
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
assert(not chatPagesSource:find("hoverHighlightStrength", 1, true), "Obsolete hover brightness is still configurable")
assert(config.Pages.shortcuts().args.commands == nil, "Commands are still nested inside Shortcuts")
assert(config.Pages.commands().args.commandOpen ~= nil, "Commands section is empty")
assert(not messagePagesSource:find("combatLogHoverHighlightStrength", 1, true), "Combat Log still has a separate hover highlight")

---@diagnostic disable-next-line: undefined-global
local initFile = assert(io.open("Glassy/init.lua", "r"))
local initSource = initFile:read("*a")
initFile:close()
assert(initSource:find("tabMessageSpacing%s*=%s*2"), "Tab vertical offset default is not 2")
assert(initSource:find('editBoxAnchor%s*=%s*{%s*position%s*=%s*"BELOW",%s*yOfs%s*=%s*-2'),
  "Edit box vertical offset default is not -2")

assert(type(config.IsMoverUnlocked) == "function")
assert(type(config.ToggleMover) == "function")
assert(type(config.GetTimestampFrameOptions) == "function")
assert(type(config.DisableBuiltinTimestamps) == "function")
assert(type(config.ShowCopyableText) == "function")

local callbacks, registrations, opens, releases = {}, 0, 0, 0
local panel = {frame = {}, SetName = function () end, SetTitle = function () end,
  SetUserData = function () end,
  SetCallback = function (_, event, callback) callbacks[event] = callback end,
  ReleaseChildren = function () releases = releases + 1 end}
core.Libs.AceGUI.Create = function (_, kind)
  assert(kind == "BlizOptionsGroup")
  return panel
end
core.Libs.AceConfigDialog.BlizOptions = {}
core.Libs.AceConfigDialog.Open = function (_, app, container)
  assert(app == "Glassy" and container == panel, "Embedded settings must use the slash-command options table")
  opens = opens + 1
end
_G.Settings = {
  RegisterCanvasLayoutCategory = function (frame, name)
    assert(frame == panel.frame and name == "Glassy")
    return {name = name}
  end,
  RegisterAddOnCategory = function (category)
    assert(category.name == "Glassy")
    registrations = registrations + 1
  end,
}
config:RegisterBlizzardOptions()
config:RegisterBlizzardOptions()
assert(registrations == 1, "Settings category must only be registered once")
callbacks.OnShow()
callbacks.OnHide()
callbacks.OnShow()
assert(opens == 2 and releases == 1, "Embedded settings must reopen after releasing their controls")
assert(core.Libs.AceConfigDialog.BlizOptions.Glassy.Glassy == panel, "Profile refresh must include the embedded panel")
_G.Settings = nil
config.blizzardOptions = nil
core.Libs.AceConfigDialog.AddToBlizOptions = function (_, app, name)
  assert(app == "Glassy" and name == "Glassy")
  return panel.frame
end
config:RegisterBlizzardOptions()
assert(config.blizzardOptions == panel.frame, "Legacy clients must register through AceConfig")

print("PASS: config core and page modules load in TOC order and register every settings page")
