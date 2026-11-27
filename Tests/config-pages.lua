unpack = unpack or table.unpack

local config = {}
local profileTransfer = {}
local slashAliases = {}
local tabPresets, ellesmere = {}, {}
local chatFeatures = {ChatAlerts = {}, ChatRules = {}, ChatUtilities = {}}
function ellesmere:IsActive() return true end
local function action()
  return {}
end

local core = {
  Version = "1.9.14",
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
    if name == "SlashAliases" then return slashAliases end
    if name == "TabPresets" then return tabPresets end
    if name == "Ellesmere" then return ellesmere end
    if chatFeatures[name] then return chatFeatures[name] end
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
local addonVars = {core, constants, {lower = string.lower}}

for _, file in ipairs({
  "Config",
  "ConfigProfiles",
  "ConfigChatPages",
  "ConfigMessagePages",
  "ConfigSupportPages",
  "TabPresets",
  "ChatAlerts",
  "ChatRules",
  "ChatUtilities",
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

core.db = {profile = {tabStyle = "minimal", slashAliasesEnabled = true}, global = {slashAliases = {}}}
core.defaults = {profile = {
  frameWidth = 600, frameHeight = 250, positionAnchor = {point = "BOTTOMLEFT", xOfs = 0, yOfs = 0},
  textLeftPadding = 4, backgroundFadeLeftPercent = 0, backgroundFadeRightPercent = 60,
  chatButtons = false, chatButtonsStyle = "glassy", chatButtonsSide = "right",
  saveCommandHistory = false,
  tabMessageSpacing = 2, editBoxFontSize = 13, editBoxVerticalPadding = 0.45,
  editBoxFadeInDuration = 0.2, editBoxFadeOutDuration = 0.6,
  editBoxEasing = "OutCubic", editBoxBackgroundEasing = "OutCubic", editBoxAnchor = {yOfs = -2},
  messageFontSize = 13, messageLeading = 3, messageLinePadding = 0.25, iconTextureYOffset = 4,
  chatHoldTime = 10, chatFadeInDuration = 0.4, chatFadeOutDuration = 0.6, chatFadeEasing = "OutCubic",
  chatSlideInDuration = 0.3, chatSlideInEasing = "OutCubic", scrollbackLines = 500,
}}
local mediaFonts = {Friz = "Fonts\\Friz.ttf"}
core.Libs.LSM.HashTable = function () return mediaFonts end
core.Libs.LSM.Fetch = function () return mediaFonts.Friz end
core.Dispatch = function () end
local tabAppearance = config.Pages.tabs().args.appearance.args
assert(#tabAppearance.tabStyle.sorting == 7)
core.db.profile.tabFont = "Friz"
assert(tabAppearance.tabFont.get() == "Friz" and tabAppearance.tabFont.values()["Use UI font"] == mediaFonts.Friz)
assert(mediaFonts["Use UI font"] == nil, "The inherited choice must not mutate the shared media registry")
tabAppearance.tabFont.set(nil, "Use UI font")
assert(core.db.profile.tabFont == "" and tabAppearance.tabFont.get() == "Use UI font")
assert(not tabAppearance.tabSelectionAnimation.disabled())
tabAppearance.tabStyle.set(nil, "classic")
assert(tabAppearance.tabSelectionAnimation.disabled())
local detailsEmbed = config.Pages.tabs().args.integrations.args.detailsChatEmbed
detailsEmbed.set(nil, true)
assert(detailsEmbed.get() and core.db.profile.detailsChatEmbed)
detailsEmbed.set(nil, false)
assert(not detailsEmbed.get())
local whisperOptions = config.Pages.tabs().args.whispers.args
assert(whisperOptions.whisperWindowsAutoOpen.disabled() and not whisperOptions.keepWhisperTabs.disabled())
assert(whisperOptions.whisperWindowsSound.disabled() and whisperOptions.whisperWindowsBubbles.disabled())
whisperOptions.dedicatedWhisperWindows.set(nil, true)
assert(whisperOptions.dedicatedWhisperWindows.get() and not whisperOptions.whisperWindowsAutoOpen.disabled()
  and whisperOptions.keepWhisperTabs.disabled())
assert(not whisperOptions.whisperWindowsSound.disabled() and not whisperOptions.whisperWindowsBubbles.disabled())
whisperOptions.whisperWindowsAutoOpen.set(nil, true)
assert(whisperOptions.whisperWindowsAutoOpen.get())
whisperOptions.dedicatedWhisperWindows.set(nil, false)
assert(not whisperOptions.dedicatedWhisperWindows.get() and whisperOptions.whisperWindowsAutoOpen.disabled())
local aliasOption = config.Pages.editBox().args.behavior.args.slashAliasesEnabled
assert(aliasOption.get() and not config.Pages.commands().args.slashAliasesEnabled)
aliasOption.set(nil, false)
assert(not aliasOption.get())

local pratModules = {History = true, Timestamps = true, Editbox = true}
local pratScrollback = false
core.IsPratModuleEnabled = function (_, name, option)
  return pratModules[name] and (option ~= "scrollback" or pratScrollback)
end
local commandHistory = config.Pages.editBox().args.typing.args.saveCommandHistory
assert(commandHistory.disabled(), "Clients without secure command classification do not offer saved commands")
IsSecureCmd = function () return false end
assert(commandHistory.disabled(), "Prat takes precedence when its command history is active")
pratModules.History = false
core.db.char = {commandHistory = {"/reload"}}
assert(not commandHistory.disabled())
commandHistory.set(nil, true)
assert(commandHistory.get() and #core.db.char.commandHistory == 1)
commandHistory.set(nil, false)
assert(not commandHistory.get() and core.db.char.commandHistory == nil)
pratModules.History = true
local settingsRefreshes = 0
core.Libs.AceConfigRegistry = {NotifyChange = function (_, app)
  assert(app == "Glassy")
  settingsRefreshes = settingsRefreshes + 1
end}
local aliasControls = config.Pages.editBox().args.behavior.args
assert(aliasControls.aliasDefinition.disabled(), "Disabling alias execution also disables editing")
aliasOption.set(nil, true)
assert(aliasControls.savedAlias.values()[""] == "New alias" and aliasControls.removeAlias.disabled())
assert(aliasControls.savedAlias.style == "radio", "Saved aliases remain visible without opening a dropdown")
assert(aliasControls.savedAlias.hidden() and not aliasControls.aliasEmpty.hidden() and aliasControls.removeAlias.hidden(),
  "An empty list shows its empty state and editor without selection or removal controls")
function slashAliases:ParseDefinition(input)
  local name, expansion = input:match("^/([%w_%-]+) = (/.+)$")
  if name then return name, expansion end
  return nil, "Invalid alias"
end
function slashAliases:Set(input)
  local name, expansion = self:ParseDefinition(input)
  if not name or name == "fail" then return end
  core.db.global.slashAliases[name] = expansion
  return name
end
function slashAliases:Remove(name) core.db.global.slashAliases[name] = nil end
assert(aliasControls.aliasDefinition.validate(nil, "invalid") == "Invalid alias")
assert(aliasControls.aliasDefinition.validate(nil, "/rld = /reload") == true)
aliasControls.aliasDefinition.set(nil, "/rld = /reload")
assert(aliasControls.savedAlias.values().rld == "/rld -> /reload")
assert(aliasControls.savedAlias.get() == "rld", "Creating an alias selects its saved entry immediately")
assert(not aliasControls.savedAlias.hidden() and aliasControls.aliasEmpty.hidden())
assert(aliasControls.aliasDefinition.get() == "/rld = /reload" and not aliasControls.removeAlias.disabled())
aliasControls.aliasDefinition.set(nil, "/rld = /reload changed")
assert(aliasControls.savedAlias.get() == "rld" and aliasControls.savedAlias.values().rld == "/rld -> /reload changed",
  "Editing an alias updates its visible definition and retains its selection")
aliasControls.aliasDefinition.set(nil, "/rl = /reload")
assert(aliasControls.savedAlias.get() == "rl" and core.db.global.slashAliases.rld == "/reload changed",
  "Changing the shortcut name creates and selects the new alias while preserving the previous one")
local aliasOrder = aliasControls.savedAlias.sorting()
assert(aliasOrder[1] == "" and aliasOrder[2] == "rl" and aliasOrder[3] == "rld", "Alias entries use a stable name order after New alias")
aliasControls.savedAlias.set(nil, "")
assert(aliasControls.aliasDefinition.get() == "" and aliasControls.removeAlias.hidden(), "New alias clears the editor and hides removal")
aliasControls.savedAlias.set(nil, "rld")
assert(aliasControls.aliasDefinition.get() == "/rld = /reload changed")
aliasControls.aliasDefinition.set(nil, "/fail = /reload")
assert(aliasControls.savedAlias.get() == "rld" and core.db.global.slashAliases.fail == nil,
  "A failed save preserves the selected alias")
aliasControls.removeAlias.func()
assert(aliasControls.savedAlias.get() == "" and aliasControls.aliasDefinition.get() == "" and aliasControls.removeAlias.disabled())
assert(aliasControls.savedAlias.values().rl and not aliasControls.savedAlias.values().rld, "Removing an alias preserves the other entries")
aliasControls.savedAlias.set(nil, "rl")
core.db.global.slashAliases.rl = nil
assert(aliasControls.savedAlias.get() == "" and not aliasControls.aliasEmpty.hidden(), "External removal clears stale selection")
core.db.global.slashAliases.rl = "/reload"
assert(aliasControls.savedAlias.get() == "", "Recreating an externally removed alias cannot restore stale selection")
core.db.global.slashAliases.rl = nil
settingsRefreshes = 0
local profile = core.db.profile
profile.shortChannelNames, profile.channelFullNames, profile.channelShortLabels = true, {}, {}
local channels = config.Pages.messages().args.channelAbbreviations.args
channels.channelToEdit.set(nil, "CHANNEL2")
channels.channelShortLabels.set(nil, " Trade ")
assert(profile.channelShortLabels.CHANNEL2 == "Trade" and settingsRefreshes == 1)
channels.channelShortLabels.set(nil, "|cff000000Trade")
assert(channels.channelShortLabels.get() == "Trade")
channels.channelFullNames.set(nil, true)
assert(profile.channelFullNames.CHANNEL2 and channels.channelShortLabels.disabled())
channels.channelFullNames.set(nil, false)
channels.channelToEdit.set(nil, "GUILD")
assert(channels.channelShortLabels.get() == "", "Numbered aliases must not affect the guild label")
pratModules.ChannelNames = true
assert(channels.channelToEdit.disabled() and channels.channelFullNames.disabled())
pratModules.ChannelNames = nil
local compatibilityPage = config.Pages.compatibility()
local compatibility = compatibilityPage.args
assert(compatibilityPage.hidden(), "Compatibility should be hidden without detected integrations")
assert(compatibility.pratStatus.hidden() and compatibility.elvuiStatus.hidden() and compatibility.ellesmereStatus.hidden())
assert(compatibility.pratSupported.hidden() and compatibility.pratUiModules.hidden())
Prat = {Version = "3"}
assert(not compatibilityPage.hidden() and not compatibility.pratStatus.hidden())
assert(compatibility.pratStatus.name():find("Prat", 1, true) and compatibility.pratStatus.name():find("3", 1, true))
assert(not compatibility.pratSupported.hidden() and not compatibility.pratUiModules.hidden())
assert(compatibility.pratSupported.args.details.name():find("Timestamps", 1, true))
assert(not compatibility.pratSupported.args.details.name():find("History", 1, true))
assert(compatibility.pratSupported.args.history.hidden())
pratScrollback = true
assert(compatibility.pratSupported.args.details.name():find("History", 1, true))
assert(not compatibility.pratSupported.args.history.hidden())
local pratWarnings = compatibility.pratUiModules.args.current.name()
assert(pratWarnings:find("Editbox", 1, true) and pratWarnings:find("Disable these Prat modules and reload.", 1, true))
assert(not pratWarnings:find("Buttons", 1, true), "Disabled Prat UI modules should not be listed")
pratModules.Editbox, pratModules.Timestamps, pratModules.History = nil, nil, nil
assert(compatibility.pratSupported.hidden() and compatibility.pratUiModules.hidden())
assert(not compatibility.pratStatus.hidden(), "Detected Prat should remain visible without active overlaps")
Prat = nil
ElvUI = {{versionString = "15"}}
assert(not compatibilityPage.hidden() and not compatibility.elvuiStatus.hidden())
assert(compatibility.elvuiStatus.name():find("ElvUI", 1, true) and compatibility.elvuiStatus.name():find("15", 1, true))
ElvUI = nil
EllesmereUI = {}
assert(not compatibility.ellesmereStatus.hidden())
assert(compatibility.ellesmereStatus.name() == "|cff80ff80EllesmereUI|r")
function ellesmere:IsActive() return false end
assert(compatibility.ellesmereStatus.name():find("skin is turned off", 1, true))
EllesmereUI = nil
C_AddOns = {IsAddOnLoaded = function (name) return name == "EllesmereUIChat" end}
assert(not compatibilityPage.hidden() and compatibility.ellesmereStatus.hidden() and not compatibility.ellesmereChatStatus.hidden())
assert(compatibility.ellesmereChatStatus.name:find("Disable the EllesmereUI Chat addon, then reload.", 1, true))
C_AddOns = nil
assert(compatibilityPage.hidden())

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

strmatch = string.match
securecallfunction = function (callback, ...) return callback(...) end
dofile("libs/LibStub/LibStub.lua")
dofile("libs/CallbackHandler-1.0/CallbackHandler-1.0.lua")
dofile("libs/AceConfig-3.0/AceConfigRegistry-3.0/AceConfigRegistry-3.0.lua")
local registry = LibStub("AceConfigRegistry-3.0")
core.Libs.AceConfigRegistry = registry
core.Libs.AceDBOptions.GetOptionsTable = function ()
  return {type = "group", name = "Profiles", args = {
    current = {type = "description", name = "Active profile"},
    new = {validate = function () return true end},
    choose = {type = "select", name = "Existing profiles", get = function () return "Default" end},
    reset = {type = "execute", name = "Reset profile"},
    copyfrom = {type = "select", name = "Copy from", get = false},
    delete = {type = "select", name = "Delete a profile", get = false},
  }}
end
core.db.GetProfiles = function () return {"Default"} end
core.db.GetCurrentProfile = function () return "Default" end
core.db.sv = {profileKeys = {}}
setmetatable(core.db.profile, {__index = core.defaults.profile})
_G.FCF_GetChatWindowInfo = function () return "General" end
assert(loadfile("Glassy/Localization.lua"))("Glassy", addonVars)
local root = config:GetOptions()
core:LocalizeOptions(root)
registry:ValidateOptionsTable(root, "Glassy")
registry:RegisterOptionsTable("Glassy", root)
assert(root.args.general.args.section3.order < root.args.general.args.section2.order)
assert(root.args.tabs.args.layout.order < root.args.tabs.args.presets.order
  and root.args.tabs.args.presets.order < root.args.tabs.args.appearance.order)
assert(root.args.messages.args.section2.args.chatAlwaysVisible
  and root.args.messages.args.timestamps.args.timestampsEnabled and root.args.messages.args.links.args.chatInvites)
assert(root.args.messages.args.chatAlerts and root.args.messages.args.chatRules and root.args.messages.args.chatUtilities,
  "New chat features must be reachable from both settings panels")
assert(root.args.editBox.args.typing.args.completePlayerNames and root.args.editBox.args.behavior.args.slashAliasesEnabled)

local labels = {}
local function registerWidget(_, _, label)
  labels[#labels + 1] = label
  return nil, 40
end
local widgetNames = {"SectionHeader", "Toggle", "Slider", "Dropdown", "Checkbox", "ColorPicker", "Button"}
local widgets = {}
for _, name in ipairs(widgetNames) do widgets[name] = registerWidget end
_G.EllesmereUI = {Widgets = widgets, IsSearchPrebuild = function () return true end}
assert(loadfile("Glassy/Modules/EllesmereOptions.lua"))("Glassy", {core, constants, {lower = string.lower}})
local modules = ellesmere:BuildOptionModules(root)
for index, key in ipairs({"general", "tabs", "messages", "editBox", "profile", "about"}) do
  local module = modules[index]
  assert(module.key == key and module.buildPage(module.pages[1], {}, 0) > 0,
    "EllesmereUI renders every shared page in the same order")
end
local positions = {}
for index, label in ipairs(labels) do positions[label] = index end
assert(positions["Layout"] < positions["Presets"] and positions["Presets"] < positions["Create Guild tab"])
assert(positions["Timestamps"] < positions["Time format"] and positions["Use existing profile"] < positions["New profile"])
local chatButtonsOptions = root.args.tabs.args.chatButtons.args
assert(chatButtonsOptions.chatButtonsStyle.get() == "glassy" and chatButtonsOptions.chatButtonsStyle.disabled(),
  "Chat buttons default to Glassy artwork and style selection follows the visibility toggle")
chatButtonsOptions.chatButtons.set(nil, true)
assert(not chatButtonsOptions.chatButtonsStyle.disabled())
chatButtonsOptions.chatButtonsStyle.set(nil, "blizzard")
assert(profile.chatButtonsStyle == "blizzard" and chatButtonsOptions.chatButtonsStyle.get() == "blizzard")
profile.chatButtons, profile.chatButtonsSide = true, "left"
profile.saveCommandHistory = true
core.db.char.commandHistory = {"/reload"}
modules[2].onReset()
assert(profile.chatButtons == false and profile.chatButtonsStyle == "glassy" and profile.chatButtonsSide == "right",
  "Reset includes the native chat-buttons toggle, artwork style, and placement")
assert(profile.saveCommandHistory and #core.db.char.commandHistory == 1, "A Tabs reset leaves the saved command history alone")
modules[4].onReset()
assert(profile.saveCommandHistory == false and core.db.char.commandHistory == nil,
  "Resetting the Edit box page takes the same cleanup path as turning off command history")

local nativeOpens, standaloneOpens, standaloneCloses = 0, 0, 0
local acceptsNative = true
_G.EllesmereUI.OpenPlugin = function (id, key)
  assert(id == "Glassy" and key == "general")
  nativeOpens = nativeOpens + 1
  return acceptsNative
end
core.Libs.AceConfigDialog.Open = function (_, app) assert(app == "Glassy"); standaloneOpens = standaloneOpens + 1 end
core.Libs.AceConfigDialog.Close = function (_, app) assert(app == "Glassy"); standaloneCloses = standaloneCloses + 1 end
config:OnSlashCommand("")
assert(nativeOpens == 0 and standaloneOpens == 1, "An unregistered plugin uses standalone settings")
ellesmere.optionsRegistered = true
config:OnSlashCommand("")
assert(nativeOpens == 1 and standaloneOpens == 1 and standaloneCloses == 1, "Use the native EllesmereUI panel by default")
config:OnSlashCommand("standalone")
assert(nativeOpens == 1 and standaloneOpens == 2, "The explicit standalone command bypasses EllesmereUI")
acceptsNative = false
config:OnSlashCommand("")
assert(nativeOpens == 2 and standaloneOpens == 3, "A rejected open falls back to standalone settings")
_G.InCombatLockdown = function () return true end
config:OnSlashCommand("")
assert(nativeOpens == 2 and standaloneOpens == 4, "Combat skips EllesmereUI's blocked open path")
_G.InCombatLockdown = nil
_G.EllesmereUI.OpenPlugin = nil
config:OnSlashCommand("")
assert(nativeOpens == 2 and standaloneOpens == 5, "Older EllesmereUI builds retain the standalone window")

print("PASS: shared settings validate in AceConfig and all pages render in EllesmereUI order")
