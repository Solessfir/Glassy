local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceConfig = Core.Libs.AceConfig
local AceConfigDialog = Core.Libs.AceConfigDialog
local AceDBOptions = Core.Libs.AceDBOptions
local AceGUI = Core.Libs.AceGUI
local LSM = Core.Libs.LSM
local ProfileTransfer = Core:GetModule("ProfileTransfer")
local L = function(text) return Core:Localize(text) end
local MAX_ACTIVE_TAB_HIGHLIGHT = 1
local MAX_TAB_HOVER_HIGHLIGHT = 1
local MAX_TAB_MESSAGE_OFFSET = 50
local MAX_COMBAT_LOG_BAR_OFFSET = 500
local MIN_FRAME_HEIGHT = 100
local MAX_TEXT_LEFT_PADDING = 100
local MAX_EDIT_BOX_VERTICAL_PADDING = 2
local CURRENT_SETTINGS_VERSION = 3

local OpenNews = Constants.ACTIONS.OpenNews
local LockMover = Constants.ACTIONS.LockMover
local RefreshConfig = Constants.ACTIONS.RefreshConfig
local UnlockMover = Constants.ACTIONS.UnlockMover
local UpdateConfig = Constants.ACTIONS.UpdateConfig

local SAVE_FRAME_POSITION = Constants.EVENTS.SAVE_FRAME_POSITION

local importedProfile
local importText = ""
local newProfileName = ""
local showCopyableText

-- An unnamed inline group creates a borderless, full-width AceGUI row.
local function infoRow(order, args)
  return {name = "", type = "group", inline = true, order = order, args = args}
end

local function commandRow(order, command, description)
  return infoRow(order, {
    command = {name = "|cffffd100"..command.."|r", type = "description", width = 0.7, order = 1},
    description = {name = description, type = "description", width = 2.1, order = 2},
  })
end

local function isMoverUnlocked()
  return _G.GlassyMoverFrame and _G.GlassyMoverFrame:IsShown()
end

local function toggleMover()
  if isMoverUnlocked() then
    Core:Dispatch(LockMover())
  else
    Core:Dispatch(UnlockMover())
  end
end

local function previewAnimations()
  local uiManager = Core:GetModule("UIManager")
  local dock = _G.GENERAL_CHAT_DOCK
  local chatFrame = (dock and dock.selected) or _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
  local slidingMessageFrame = chatFrame and (
    uiManager.state.temporaryFrames[chatFrame:GetName()] or uiManager.state.frames[chatFrame:GetID()]
  )

  if slidingMessageFrame == nil or not slidingMessageFrame:IsShown() then
    slidingMessageFrame = nil
    for _, candidate in ipairs(uiManager.state.frames) do
      if candidate:IsShown() then
        slidingMessageFrame = candidate
        break
      end
    end
  end
  if slidingMessageFrame then
    slidingMessageFrame:PreviewAnimations()
  end
end

local ANCHORS = {
  ["TOPLEFT"] = L("Top left"),
  ["TOPRIGHT"] = L("Top right"),
  ["BOTTOMLEFT"] = L("Bottom left"),
  ["BOTTOMRIGHT"] = L("Bottom right")
}
local FLAGS = { [""] = L("None"), ["OUTLINE"] = L("Outline"), ["OUTLINE, MONOCHROME"] = L("Outline Monochrome") }
local COMBAT_LOG_BAR_POSITIONS = {
  ABOVE = L("Above tabs"),
  BELOW = L("Below tabs"),
  HIDDEN = L("Hidden"),
}
local TIMESTAMP_FORMATS = {
  ["[%H:%M]"] = "[23:59]",
  ["[%H:%M:%S]"] = "[23:59:59]",
  ["[%I:%M %p]"] = "[11:59 PM]",
  ["[%I:%M:%S %p]"] = "[11:59:59 PM]",
}
local EASING_VALUES = {
  Linear = L("Linear"),
  InCubic = L("Ease in"),
  OutCubic = L("Ease out"),
  InOutCubic = L("Ease in/out"),
  OutBack = L("Overshoot"),
  OutBounce = L("Bounce"),
  OutElastic = L("Elastic"),
}
local EASING_SORTING = {
  "Linear",
  "InCubic",
  "OutCubic",
  "InOutCubic",
  "OutBack",
  "OutBounce",
  "OutElastic",
}
local PRAT_UI_MODULES = {
  "Buttons",
  "ChatTabs",
  "CopyChat",
  "Editbox",
  "Fading",
  "Font",
  "Frames",
  "HoverTips",
  "OriginalButtons",
  "Paragraph",
  "Scroll",
  "Search",
  "SideTabs",
}

local function formatList(items)
  return "• "..table.concat(items, "\n• ")
end

local function getPratUiModuleGuidance()
  return "Glassy replaces the native-frame behavior of these modules. Keep them disabled:\n"..
    formatList(PRAT_UI_MODULES)
end

local PROFILE_OPTION_KEYS = {
  "current",
  "new",
  "reset",
  "choose",
  "copyfrom",
  "delete",
}

local function copyTable(source)
  local copy = {}
  for key, value in pairs(source) do
    copy[key] = type(value) == "table" and copyTable(value) or value
  end
  return copy
end

local function mergeTable(target, source)
  for key, value in pairs(source) do
    if type(value) == "table" and type(target[key]) == "table" then
      mergeTable(target[key], value)
    else
      target[key] = type(value) == "table" and copyTable(value) or value
    end
  end
end

local function trim(text)
  return string.match(text or "", "^%s*(.-)%s*$")
end

local function profileExists(name)
  local profiles = Core.db:GetProfiles()
  for _, profileName in ipairs(profiles) do
    if profileName == name then
      return true
    end
  end
  return false
end

local function applyImportedProfile(profile)
  Core.db:ResetProfile(nil, true)
  mergeTable(Core.db.profile, profile)
  C:RefreshConfig()
end

local function getProfileOptions()
  local shared = AceDBOptions:GetOptionsTable(Core.db)
  local args = {}
  for _, key in ipairs(PROFILE_OPTION_KEYS) do
    if shared.args[key] then
      args[key] = copyTable(shared.args[key])
    end
  end
  args.current.order = 10
  args.new.order = 20
  args.reset.order = 30
  args.choose.order = 40
  args.copyfrom.order = 50
  args.delete.order = 60
  args.currentNewSpacer = {
    name = "",
    type = "description",
    order = 15,
    width = 0.1,
  }
  args.newResetSpacer = {
    name = "",
    type = "description",
    order = 25,
    width = 0.08,
  }
  args.profileRowsSpacer = {
    name = " ",
    type = "description",
    order = 35,
    width = "full",
  }
  args.chooseCopySpacer = {
    name = "",
    type = "description",
    order = 45,
    width = 0.1,
  }
  args.copyDeleteSpacer = {
    name = "",
    type = "description",
    order = 55,
    width = 0.1,
  }
  args.transfer = {
    name = "Import and export",
    type = "group",
    inline = true,
    order = 70,
    args = {
      exportProfile = {
        name = "Export current profile",
        desc = "Create a copyable string containing only the current profile's settings.",
        type = "execute",
        order = 1,
        width = 1.4,
        func = function ()
          local encoded = ProfileTransfer:Export(Core.db.profile)
          if encoded == nil then
            C:Print(L("Could not export the current profile."))
            return
          end
          showCopyableText(L("Glassy: Export profile"), encoded)
        end,
      },
      importText = {
        name = "Profile string",
        desc = "Paste a Glassy profile export. The data is validated before it can be imported.",
        type = "input",
        order = 10,
        multiline = 6,
        width = "full",
        get = function () return importText end,
        validate = function (_, value)
          if trim(value) == "" then
            return true
          end
          return ProfileTransfer:Import(value, Core.defaults.profile) and true or L("Invalid Glassy profile string.")
        end,
        set = function (_, value)
          importText = value
          importedProfile = trim(value) ~= "" and ProfileTransfer:Import(value, Core.defaults.profile) or nil
        end,
      },
      newProfileName = {
        name = "New profile name",
        desc = "Enter a unique name for the imported profile.",
        type = "input",
        order = 20,
        width = 1.4,
        get = function () return newProfileName end,
        set = function (_, value) newProfileName = value end,
      },
      importNew = {
        name = "Import as new",
        desc = "Create and select a new profile using the imported settings.",
        type = "execute",
        order = 21,
        width = 1.1,
        disabled = function ()
          local name = trim(newProfileName)
          return importedProfile == nil or name == "" or profileExists(name)
        end,
        func = function ()
          local name = trim(newProfileName)
          if name == "" then
            C:Print(L("Enter a profile name."))
            return
          end
          if profileExists(name) then
            C:Print(L("A profile with that name already exists."))
            return
          end
          Core.db:SetProfile(name)
          applyImportedProfile(importedProfile)
          newProfileName = ""
          C:Print(string.format(L("Imported profile: %s"), name))
        end,
      },
      replaceProfile = {
        name = "Replace current",
        desc = "Replace the current profile with the imported settings.",
        type = "execute",
        order = 22,
        width = 1.2,
        disabled = function () return importedProfile == nil end,
        confirm = function ()
          return string.format(
            L("Replace profile '%s'? Its current settings will be lost."),
            Core.db:GetCurrentProfile()
          )
        end,
        func = function ()
          local name = Core.db:GetCurrentProfile()
          applyImportedProfile(importedProfile)
          C:Print(string.format(L("Imported profile: %s"), name))
        end,
      },
    },
  }

  return {
    type = shared.type,
    name = shared.name,
    desc = shared.desc,
    handler = shared.handler,
    args = args,
  }
end

local function getTimestampFrameOptions()
  local frames = {}
  for index = 1, (_G.NUM_CHAT_WINDOWS or 10) do
    local name, _, _, _, _, _, shown = _G.FCF_GetChatWindowInfo(index)
    local chatFrame = _G["ChatFrame"..index]
    if chatFrame and (shown or chatFrame.isDocked) and not chatFrame.isTemporary and name and name ~= "" then
      frames["ChatFrame"..index] = name
    end
  end
  return frames
end

local function getPratModule(moduleName)
  local pratAddon = _G.Prat and _G.Prat.Addon
  if pratAddon == nil or type(pratAddon.GetModule) ~= "function" then
    return nil
  end

  local ok, module = pcall(pratAddon.GetModule, pratAddon, moduleName, true)
  return ok and module or nil
end

local function isPratModuleEnabled(moduleName)
  local module = getPratModule(moduleName)
  return module and type(module.IsEnabled) == "function" and module:IsEnabled()
end

local function getPratStatus()
  if _G.Prat == nil then
    return "|cff808080Not detected.|r Glassy is fully functional without Prat."
  end
  return "|cff80ff80Detected:|r "..tostring(_G.Prat.Version or "Prat")
end

local function getElvUIStatus()
  local elvui = _G.ElvUI
  local engine = type(elvui) == "table" and elvui[1]
  if not engine then
    return "|cff808080Not detected: ElvUI.|r"
  end
  local version = engine.versionString or engine.version
  return "|cff80ff80Detected:|r ElvUI"..(version and " |cff8080ff"..tostring(version).."|r" or "")
end

local function getEnabledPratUiModules()
  if _G.Prat == nil then
    return "No compatibility warnings."
  end

  local enabled = {}
  for _, moduleName in ipairs(PRAT_UI_MODULES) do
    if isPratModuleEnabled(moduleName) then
      table.insert(enabled, moduleName)
    end
  end

  if #enabled == 0 then
    return "|cff80ff80No conflicting Prat UI modules are enabled.|r"
  end
  return "|cffff8080Enabled Prat UI modules that Glassy replaces:|r\n"..formatList(enabled)
end

local function getPratTimestampStatus()
  if not isPratModuleEnabled("Timestamps") then
    return "|cff80ff80Prat Timestamps is disabled.|r Glassy can add timestamps itself."
  end
  return "|cffffd100Prat Timestamps is enabled.|r Glassy does not use it for live rendering. "..
    "Disable it and use Glassy timestamps to prevent Prat from embedding timestamps in retained native history."
end

local function disableBuiltinTimestamps()
  local getCVar = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  local setCVar = _G.C_CVar and _G.C_CVar.SetCVar or _G.SetCVar
  if getCVar and setCVar and getCVar("showTimestamps") ~= "none" then
    setCVar("showTimestamps", "none")
  end
  _G.CHAT_TIMESTAMP_FORMAT = nil
end

local function clampColorChannel(value, fallback)
  return math.max(0, math.min(1, tonumber(value) or fallback))
end

local function normalizeColor(color, defaults, legacyOpacity)
  color = type(color) == "table" and color or {}
  return {
    r = clampColorChannel(color.r, defaults.r),
    g = clampColorChannel(color.g, defaults.g),
    b = clampColorChannel(color.b, defaults.b),
    a = clampColorChannel(color.a, legacyOpacity or defaults.a),
  }
end

local function normalizeBackgroundColors()
  local profile = Core.db.profile
  local defaults = Core.defaults.profile
  local chatColor = rawget(profile, "chatBackgroundColor")
  local editBoxColor = rawget(profile, "editBoxBackgroundColor")
  local legacyTabSeparator = rawget(profile, "tabMessageSeparator")
  local legacyEditBoxSeparator = rawget(profile, "editBoxMessageSeparator")

  profile.headerBackgroundColor = normalizeColor(
    rawget(profile, "headerBackgroundColor"),
    defaults.headerBackgroundColor
  )
  profile.chatBackgroundColor = normalizeColor(
    chatColor,
    defaults.chatBackgroundColor,
    chatColor == nil and tonumber(rawget(profile, "chatBackgroundOpacity")) or nil
  )
  profile.editBoxBackgroundColor = normalizeColor(
    editBoxColor,
    defaults.editBoxBackgroundColor,
    editBoxColor == nil and tonumber(rawget(profile, "editBoxBackgroundOpacity")) or nil
  )
  profile.tabMessageSeparatorColor = normalizeColor(
    rawget(profile, "tabMessageSeparatorColor"),
    defaults.tabMessageSeparatorColor,
    type(legacyTabSeparator) == "boolean" and (legacyTabSeparator and 0.65 or 0) or nil
  )
  profile.editBoxMessageSeparatorColor = normalizeColor(
    rawget(profile, "editBoxMessageSeparatorColor"),
    defaults.editBoxMessageSeparatorColor,
    type(legacyEditBoxSeparator) == "boolean" and (legacyEditBoxSeparator and 0.65 or 0) or nil
  )
  profile.unreadMessageSeparatorColor = normalizeColor(
    rawget(profile, "unreadMessageSeparatorColor"),
    defaults.unreadMessageSeparatorColor
  )
  profile.unreadMessageBackgroundColor = normalizeColor(
    rawget(profile, "unreadMessageBackgroundColor"),
    defaults.unreadMessageBackgroundColor
  )
  profile.chatBackgroundOpacity = nil
  profile.editBoxBackgroundOpacity = nil
  profile.tabMessageSeparator = nil
  profile.editBoxMessageSeparator = nil
end

local function migrateSettings()
  local profile = Core.db.profile
  local version = tonumber(rawget(profile, "settingsVersion")) or 0
  if version < 1 and rawget(profile, "tabHoverHighlightStrength") == 0.15 then
    profile.tabHoverHighlightStrength = nil
  end
  if version < 2 and rawget(profile, "tabMessageSpacing") == 5 then
    profile.tabMessageSpacing = nil
  end
  if version < 3 and rawget(profile, "editBoxVerticalPadding") == 0.35 then
    profile.editBoxVerticalPadding = nil
  end
  profile.settingsVersion = CURRENT_SETTINGS_VERSION
end

local function normalizeFrameHeight()
  local height = tonumber(Core.db.profile.frameHeight) or Core.defaults.profile.frameHeight
  Core.db.profile.frameHeight = math.max(MIN_FRAME_HEIGHT, math.floor(height))
end

local function normalizeTextLeftPadding()
  local padding = tonumber(Core.db.profile.textLeftPadding) or Core.defaults.profile.textLeftPadding
  Core.db.profile.textLeftPadding = math.max(0, math.min(MAX_TEXT_LEFT_PADDING, math.floor(padding)))
end

local function normalizeTabMessageSpacing()
  local spacing = tonumber(Core.db.profile.tabMessageSpacing) or Core.defaults.profile.tabMessageSpacing
  Core.db.profile.tabMessageSpacing = math.max(
    0,
    math.min(MAX_TAB_MESSAGE_OFFSET, math.floor(spacing))
  )
end

local function normalizeActiveTabHighlight()
  local strength = tonumber(Core.db.profile.activeTabHighlightStrength) or
    Core.defaults.profile.activeTabHighlightStrength
  Core.db.profile.activeTabHighlightStrength = math.max(0, math.min(MAX_ACTIVE_TAB_HIGHLIGHT, strength))
end

local function normalizeTabHoverHighlight()
  local strength = tonumber(Core.db.profile.tabHoverHighlightStrength) or
    Core.defaults.profile.tabHoverHighlightStrength
  Core.db.profile.tabHoverHighlightStrength = math.max(0, math.min(MAX_TAB_HOVER_HIGHLIGHT, strength))
end

local function normalizeEditBox()
  Core.db.profile.dynamicEditBox = Core.db.profile.dynamicEditBox ~= false
  local padding = tonumber(Core.db.profile.editBoxVerticalPadding) or
    Core.defaults.profile.editBoxVerticalPadding
  Core.db.profile.editBoxVerticalPadding = math.max(
    0,
    math.min(MAX_EDIT_BOX_VERTICAL_PADDING, padding)
  )
end

local function normalizeCombatLogBar()
  local profile = Core.db.profile
  local defaults = Core.defaults.profile
  profile.combatLogHidden = not not profile.combatLogHidden
  if COMBAT_LOG_BAR_POSITIONS[profile.combatLogBarPosition] == nil then
    profile.combatLogBarPosition = defaults.combatLogBarPosition
  end

  local xOffset = tonumber(profile.combatLogBarXOffset) or defaults.combatLogBarXOffset
  local yOffset = tonumber(profile.combatLogBarYOffset) or defaults.combatLogBarYOffset
  profile.combatLogBarXOffset = math.max(
    -MAX_COMBAT_LOG_BAR_OFFSET,
    math.min(MAX_COMBAT_LOG_BAR_OFFSET, math.floor(xOffset))
  )
  profile.combatLogBarYOffset = math.max(
    -MAX_COMBAT_LOG_BAR_OFFSET,
    math.min(MAX_COMBAT_LOG_BAR_OFFSET, math.floor(yOffset))
  )
end

local function normalizeTimestamps()
  local profile = Core.db.profile
  local defaults = Core.defaults.profile
  profile.timestampsEnabled = not not profile.timestampsEnabled
  profile.timestampColorEnabled = not not profile.timestampColorEnabled
  if TIMESTAMP_FORMATS[profile.timestampFormat] == nil then
    profile.timestampFormat = defaults.timestampFormat
  end
  profile.timestampColor = normalizeColor(profile.timestampColor, defaults.timestampColor)
  if type(profile.timestampFrames) ~= "table" then
    profile.timestampFrames = {}
    for frameName in pairs(getTimestampFrameOptions()) do
      profile.timestampFrames[frameName] = true
    end
  end
end

local function normalizeBackgroundFades()
  local profile = Core.db.profile
  local defaults = Core.defaults.profile
  local leftWidth = rawget(profile, "backgroundFadeLeftWidth")
  local rightWidth = rawget(profile, "backgroundFadeRightWidth")
  local legacyLeft = rawget(profile, "backgroundFadeLeft")
  local legacyRight = rawget(profile, "backgroundFadeRight")

  if leftWidth == nil and type(legacyLeft) == "boolean" then
    leftWidth = legacyLeft and 50 or 0
  end
  if rightWidth == nil and type(legacyRight) == "boolean" then
    rightWidth = legacyRight and 250 or 0
  end

  profile.backgroundFadeLeftWidth = math.max(0, tonumber(leftWidth) or defaults.backgroundFadeLeftWidth)
  profile.backgroundFadeRightWidth = math.max(0, tonumber(rightWidth) or defaults.backgroundFadeRightWidth)
  profile.backgroundFadeLeft = nil
  profile.backgroundFadeRight = nil
end

local function normalizeAnimationEasings()
  local profile = Core.db.profile
  local defaults = Core.defaults.profile
  local function normalize(easing, defaultEasing)
    if easing == "InSine" then
      return "InCubic"
    end
    return EASING_VALUES[easing] and easing or defaultEasing
  end

  profile.chatFadeEasing = normalize(profile.chatFadeEasing, defaults.chatFadeEasing)
  profile.chatSlideInEasing = normalize(profile.chatSlideInEasing, defaults.chatSlideInEasing)
  profile.editBoxEasing = normalize(profile.editBoxEasing, defaults.editBoxEasing)
  local backgroundEasing = rawget(profile, "editBoxBackgroundEasing") or profile.editBoxEasing
  profile.editBoxBackgroundEasing = normalize(backgroundEasing, defaults.editBoxBackgroundEasing)
end

function C:OnEnable()
  migrateSettings()
  normalizeBackgroundColors()
  normalizeBackgroundFades()
  normalizeFrameHeight()
  normalizeTabMessageSpacing()
  normalizeTextLeftPadding()
  normalizeActiveTabHighlight()
  normalizeTabHoverHighlight()
  normalizeEditBox()
  normalizeCombatLogBar()
  normalizeTimestamps()
  normalizeAnimationEasings()
  if Core.db.profile.timestampsEnabled then
    disableBuiltinTimestamps()
  end

  local options = {
      name = "Glassy",
      handler = C,
      type = "group",
      args = {
        general = {
          name = "General",
          type = "group",
          order = 1,
          args = {
            section2 = {
              name = "Appearance",
              type = "group",
              inline = true,
              order = 3,
              args = {
                font = {
                  name = "Font",
                  desc = "Choose the font used for chat messages, tabs, Combat Log filters, and the edit box.\nDefault: "..
                    Core.defaults.profile.font,
                  type = "select",
                  order = 3.1,
                  dialogControl = "LSM30_Font",
                  values = LSM:HashTable("font"),
                  get = function()
                    return Core.db.profile.font
                  end,
                  set = function(info, input)
                    Core.db.profile.font = input
                    Core:Dispatch(UpdateConfig("font"))
                  end,
                },
                fontFlags = {
                  name = "Font outline",
                  desc = "Choose whether Glassy text has an outline or a monochrome outline.\nDefault: None",
                  type = "select",
                  order = 3.2,
                  values = FLAGS,
                  get = function ()
                    return Core.db.profile.fontFlags
                  end,
                  set = function (_, input)
                    Core.db.profile.fontFlags = input
                    Core:Dispatch(UpdateConfig("font"))
                  end
                },
                textLeftPadding = {
                  name = "Left text padding",
                  desc = "Sets the space, in pixels, between the left edge and Glassy text. Applies to chat messages, tabs, Combat Log filters, and the edit box.\nDefault: "..
                    Core.defaults.profile.textLeftPadding.." px\nMin: 0\nMax: "..MAX_TEXT_LEFT_PADDING,
                  type = "range",
                  order = 3.3,
                  min = 0,
                  max = MAX_TEXT_LEFT_PADDING,
                  softMin = 0,
                  softMax = 50,
                  step = 1,
                  get = function ()
                    return Core.db.profile.textLeftPadding
                  end,
                  set = function (_, input)
                    Core.db.profile.textLeftPadding = input
                    Core:Dispatch(UpdateConfig("textLeftPadding"))
                  end,
                },
                activeTabHighlightStrength = {
                  name = "Active tab highlight",
                  desc = "Brightens the active chat tab. A value of 0 disables the highlight; 1 applies the strongest highlight.\nDefault: "..
                    Core.defaults.profile.activeTabHighlightStrength.."\nMin: 0\nMax: "..MAX_ACTIVE_TAB_HIGHLIGHT,
                  type = "range",
                  order = 3.4,
                  min = 0,
                  max = MAX_ACTIVE_TAB_HIGHLIGHT,
                  softMin = 0,
                  softMax = MAX_ACTIVE_TAB_HIGHLIGHT,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.activeTabHighlightStrength
                  end,
                  set = function (_, input)
                    Core.db.profile.activeTabHighlightStrength = input
                    Core:Dispatch(UpdateConfig("activeTabHighlightStrength"))
                  end,
                },
                tabHoverHighlightStrength = {
                  name = "Tab hover highlight",
                  desc = "Brightens a chat tab while the pointer is over it. A value of 0 disables the highlight; 1 applies the strongest highlight.\nDefault: "..
                    Core.defaults.profile.tabHoverHighlightStrength.."\nMin: 0\nMax: "..MAX_TAB_HOVER_HIGHLIGHT,
                  type = "range",
                  order = 3.5,
                  min = 0,
                  max = MAX_TAB_HOVER_HIGHLIGHT,
                  softMin = 0,
                  softMax = MAX_TAB_HOVER_HIGHLIGHT,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.tabHoverHighlightStrength
                  end,
                  set = function (_, input)
                    Core.db.profile.tabHoverHighlightStrength = input
                    Core:Dispatch(UpdateConfig("tabHoverHighlightStrength"))
                  end,
                },
                chatTabTooltips = {
                  name = "Chat tab tooltips",
                  desc = "Show interaction hints when hovering over chat tabs.\nDefault: off",
                  type = "toggle",
                  order = 3.6,
                  get = function ()
                    return Core.db.profile.chatTabTooltips
                  end,
                  set = function (_, input)
                    Core.db.profile.chatTabTooltips = input
                    Core:Dispatch(UpdateConfig("chatTabTooltips"))
                  end,
                },
                tabMessageSeparatorColor = {
                  name = "Separator",
                  desc = "Choose the separator color and opacity between chat tabs and messages. Set opacity to 0 to hide it.\nDefault: gold at 0% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 3.7,
                  get = function ()
                    local color = Core.db.profile.tabMessageSeparatorColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.tabMessageSeparatorColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("tabMessageSeparatorColor"))
                  end,
                },
                tabMessageSpacing = {
                  name = "Vertical offset",
                  desc = "Moves messages down from the chat tabs.\nDefault: "..
                    Core.defaults.profile.tabMessageSpacing.." px\nMin: 0\nMax: "..MAX_TAB_MESSAGE_OFFSET,
                  type = "range",
                  order = 3.75,
                  min = 0,
                  max = MAX_TAB_MESSAGE_OFFSET,
                  softMin = 0,
                  softMax = 20,
                  step = 1,
                  get = function ()
                    return Core.db.profile.tabMessageSpacing
                  end,
                  set = function (_, input)
                    Core.db.profile.tabMessageSpacing = input
                    Core:Dispatch(UpdateConfig("tabMessageSpacing"))
                  end,
                },
                headerBackgroundColor = {
                  name = "Header background",
                  desc = "Choose the color and opacity behind the chat tabs and Combat Log filter bar.\nDefault: black at 40% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 3.8,
                  get = function ()
                    local color = Core.db.profile.headerBackgroundColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.headerBackgroundColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("headerBackgroundColor"))
                  end,
                },
                backgroundFadeLeftWidth = {
                  name = "Left fade distance",
                  desc = "Controls how gradually Glassy backgrounds fade at the left edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: "..
                    Core.defaults.profile.backgroundFadeLeftWidth.." px\nMin: 0\nMax: 1000",
                  type = "range",
                  order = 3.9,
                  min = 0,
                  max = 1000,
                  softMin = 0,
                  softMax = 500,
                  step = 5,
                  get = function ()
                    return Core.db.profile.backgroundFadeLeftWidth
                  end,
                  set = function (_, input)
                    Core.db.profile.backgroundFadeLeftWidth = input
                    Core:Dispatch(UpdateConfig("backgroundFade"))
                  end,
                },
                backgroundFadeRightWidth = {
                  name = "Right fade distance",
                  desc = "Controls how gradually Glassy backgrounds fade at the right edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: "..
                    Core.defaults.profile.backgroundFadeRightWidth.." px\nMin: 0\nMax: 1000",
                  type = "range",
                  order = 4,
                  min = 0,
                  max = 1000,
                  softMin = 0,
                  softMax = 500,
                  step = 5,
                  get = function ()
                    return Core.db.profile.backgroundFadeRightWidth
                  end,
                  set = function (_, input)
                    Core.db.profile.backgroundFadeRightWidth = input
                    Core:Dispatch(UpdateConfig("backgroundFade"))
                  end,
                },
              },
            },
            section3 = {
              name = "Frame",
              type = "group",
              inline = true,
              order = 4,
              args = {
                frameWidth = {
                  name = "Width",
                  desc = "Sets the width of the chat frame in pixels.\nDefault: "..Core.defaults.profile.frameWidth..
                    "\nMin: 100\nMax: 9999",
                  type = "range",
                  order = 4.4,
                  min = 100,
                  max = 9999,
                  softMin = 300,
                  softMax = 800,
                  step = 1,
                  get = function ()
                    return Core.db.profile.frameWidth
                  end,
                  set = function (info, input)
                    Core.db.profile.frameWidth = input
                    Core:Dispatch(UpdateConfig("frameWidth"))
                  end
                },
                frameHeight = {
                  name = "Height",
                  desc = "Sets the height of the chat frame in pixels.\nDefault: "..Core.defaults.profile.frameHeight..
                    "\nMin: "..MIN_FRAME_HEIGHT.."\nMax: 9999",
                  type = "range",
                  order = 4.5,
                  min = MIN_FRAME_HEIGHT,
                  max = 9999,
                  softMin = 200,
                  softMax = 800,
                  step = 1,
                  get = function ()
                    return Core.db.profile.frameHeight
                  end,
                  set = function (info, input)
                    Core.db.profile.frameHeight = input
                    Core:Dispatch(UpdateConfig("frameHeight"))
                  end
                },
                frameXOfs = {
                  name = "Horizontal offset",
                  desc = "Moves the chat frame horizontally from its selected screen anchor. Positive values move it right; negative values move it left.\nDefault: "..
                    Core.defaults.profile.positionAnchor.xOfs.."\nMin: -9999\nMax: 9999",
                  type = "range",
                  order = 4.2,
                  min = -9999,
                  max = 9999,
                  softMin = -2000,
                  softMax = 2000,
                  step = 1,
                  get = function ()
                    return Core.db.profile.positionAnchor.xOfs
                  end,
                  set = function (_, input)
                    Core.db.profile.positionAnchor.xOfs = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
                frameYOfs = {
                  name = "Vertical offset",
                  desc = "Moves the chat frame vertically from its selected screen anchor. Positive values move it up; negative values move it down.\nDefault: "..
                    Core.defaults.profile.positionAnchor.yOfs.."\nMin: -9999\nMax: 9999",
                  type = "range",
                  order = 4.3,
                  min = -9999,
                  max = 9999,
                  softMin = -2000,
                  softMax = 2000,
                  step = 1,
                  get = function ()
                    return Core.db.profile.positionAnchor.yOfs
                  end,
                  set = function (_, input)
                    Core.db.profile.positionAnchor.yOfs = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
                frameAnchor = {
                  name = "Anchor",
                  desc = "Choose the screen corner used as the reference point for the horizontal and vertical offsets.\nDefault: "..
                    ANCHORS[Core.defaults.profile.positionAnchor.point],
                  type = "select",
                  order = 4.1,
                  values = ANCHORS,
                  get = function ()
                    return Core.db.profile.positionAnchor.point
                  end,
                  set = function (_, input)
                    Core.db.profile.positionAnchor.point = input
                    Core:Dispatch(UpdateConfig("framePosition"))
                  end
                },
                unlockFrame = {
                  name = function()
                    return isMoverUnlocked() and "Lock frame" or "Unlock frame"
                  end,
                  desc = function()
                    if isMoverUnlocked() then
                      return "Save the current position and hide the draggable Edit Mode overlay."
                    end
                    return "Show the draggable Edit Mode overlay used to reposition the Glassy chat frame."
                  end,
                  type = "execute",
                  func = toggleMover,
                  width = 1,
                  order = 4.6,
                },
              }
            },
          }
        },
        editBox = {
          name = "Edit box",
          type = "group",
          order = 2,
          args = {
            section1 = {
              name = "Appearance",
              type = "group",
              inline = true,
              order = 1,
              args = {
                editBoxFontSize = {
                  name = "Font size",
                  desc = "Sets the size of typed chat text and the chat-type label.\nDefault: "..
                    Core.defaults.profile.editBoxFontSize.."\nMin: 1\nMax: 100",
                  type = "range",
                  min = 1,
                  max = 100,
                  softMin = 6,
                  softMax = 24,
                  step = 1,
                  get = function ()
                    return Core.db.profile.editBoxFontSize
                  end,
                  set = function (info, input)
                    Core.db.profile.editBoxFontSize = input
                    Core:Dispatch(UpdateConfig("editBoxFontSize"))
                  end,
                  order = 1.1,
                },
                editBoxVerticalPadding = {
                  name = "Vertical padding",
                  desc = "Adds space above and below typed text as a fraction of the line height.\nDefault: "..
                    Core.defaults.profile.editBoxVerticalPadding.."\nMin: 0\nMax: "..MAX_EDIT_BOX_VERTICAL_PADDING,
                  type = "range",
                  min = 0,
                  max = MAX_EDIT_BOX_VERTICAL_PADDING,
                  softMax = 1,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.editBoxVerticalPadding
                  end,
                  set = function (_, input)
                    Core.db.profile.editBoxVerticalPadding = input
                    Core:Dispatch(UpdateConfig("editBoxVerticalPadding"))
                  end,
                  order = 1.2,
                },
                editBoxBackgroundColor = {
                  name = "Background",
                  desc = "Choose the color and opacity behind the chat entry field.\nDefault: black at 40% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 1.3,
                  get = function ()
                    local color = Core.db.profile.editBoxBackgroundColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.editBoxBackgroundColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("editBoxBackgroundColor"))
                  end,
                },
                editBoxMessageSeparatorColor = {
                  name = "Separator",
                  desc = "Choose the separator color and opacity between the chat entry field and messages. Set opacity to 0 to hide it.\nDefault: gold at 0% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 1.35,
                  get = function ()
                    local color = Core.db.profile.editBoxMessageSeparatorColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.editBoxMessageSeparatorColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("editBoxMessageSeparatorColor"))
                  end,
                },
                editBoxBackgroundEasing = {
                  name = "Background easing",
                  desc = "Controls how the edit-box background fades when chat opens or closes.\nDefault: "..
                    EASING_VALUES[Core.defaults.profile.editBoxBackgroundEasing],
                  type = "select",
                  order = 1.4,
                  values = EASING_VALUES,
                  sorting = EASING_SORTING,
                  get = function ()
                    return Core.db.profile.editBoxBackgroundEasing
                  end,
                  set = function (_, input)
                    Core.db.profile.editBoxBackgroundEasing = input
                    Core:Dispatch(UpdateConfig("editBoxBackgroundEasing"))
                  end,
                },
              }
            },
            section2 = {
              name = "Placement",
              type = "group",
              inline = true,
              order = 2,
              args = {
                editBoxAnchorPosition = {
                  name = "Attach",
                  desc = "Place the chat entry field above or below the main chat frame.\nDefault: Below",
                  type = "select",
                  order = 2.1,
                  values = {
                    ABOVE = L("Above chat"),
                    BELOW = L("Below chat"),
                  },
                  get = function ()
                    return Core.db.profile.editBoxAnchor.position
                  end,
                  set = function (_, input)
                    Core.db.profile.editBoxAnchor.position = input
                    if input == "ABOVE" then
                      Core.db.profile.editBoxAnchor.yOfs = 5
                    else
                      Core.db.profile.editBoxAnchor.yOfs = -5
                    end
                    Core:Dispatch(UpdateConfig("editBoxAnchor"))
                  end
                },
                editBoxAnchorYOfs = {
                  name = "Vertical offset",
                  desc = "Moves the chat entry field vertically. Positive values move it up; negative values move it down.\nDefault: 5 above or -5 below\nMin: -9999\nMax: 9999",
                  type = "range",
                  order = 2.2,
                  min = -9999,
                  max = 9999,
                  softMin = -10,
                  softMax = 10,
                  step = 1,
                  get = function ()
                    return Core.db.profile.editBoxAnchor.yOfs
                  end,
                  set = function (info, input)
                    Core.db.profile.editBoxAnchor.yOfs = input
                    Core:Dispatch(UpdateConfig("editBoxAnchor"))
                  end
                },
                placementRowBreak = {
                  name = "",
                  type = "description",
                  order = 2.25,
                  width = "full",
                },
                dynamicEditBox = {
                  name = "Dynamic message area",
                  desc = "Uses the chat entry field's space for messages while the field is closed. Opening chat moves messages up and restores the entry field. This applies when the field is attached below the chat; disable it to keep the message area static.\nDefault: Enabled",
                  type = "toggle",
                  order = 2.3,
                  width = 1.2,
                  get = function ()
                    return Core.db.profile.dynamicEditBox
                  end,
                  set = function (_, input)
                    Core.db.profile.dynamicEditBox = input
                    Core:Dispatch(UpdateConfig("dynamicEditBox"))
                  end,
                },
                editBoxEasing = {
                  name = "Movement easing",
                  desc = "Controls how messages move when the dynamic chat entry field opens or closes.\nDefault: "..
                    EASING_VALUES[Core.defaults.profile.editBoxEasing],
                  type = "select",
                  order = 2.4,
                  width = 1,
                  values = EASING_VALUES,
                  sorting = EASING_SORTING,
                  disabled = function ()
                    return not Core.db.profile.dynamicEditBox
                  end,
                  get = function ()
                    return Core.db.profile.editBoxEasing
                  end,
                  set = function (_, input)
                    Core.db.profile.editBoxEasing = input
                    Core:Dispatch(UpdateConfig("editBoxEasing"))
                  end,
                }
              },
            }
          },
        },
        shortcuts = {
          name = "Shortcuts",
          type = "group",
          order = 6.5,
          args = {
            editing = {
              name = "While typing",
              type = "group",
              inline = true,
              order = 1,
              args = {
                reference = {
                  type = "description",
                  fontSize = "medium",
                  width = "full",
                  order = 1,
                  name = "|cffffd100Left / Right|r  Move the cursor.\n\n"..
                    "|cffffd100Home / End|r  Jump to the beginning / end.\n\n"..
                    "|cffffd100Ctrl+Left / Right|r  Move by word.\n\n"..
                    "|cffffd100Ctrl+E|r  Jump to the end.\n\n"..
                    "|cffffd100Ctrl+W|r  Delete the previous word.\n\n"..
                    "|cffffd100Ctrl+U|r  Delete from the cursor to the beginning.\n\n"..
                    "|cffffd100Ctrl+K|r  Delete from the cursor to the end.\n\n"..
                    "|cffffd100Ctrl+Y|r  Insert the text last removed by Ctrl+U or Ctrl+K.\n\n"..
                    "|cffffd100Ctrl+A / C / X / V|r  Select all / copy / cut / paste.\n\n"..
                    "Ctrl+U, K and Y are unavailable during Blizzard's chat messaging lockdown.",
                },
              },
            },
            history = {
              name = "Sent-message history",
              type = "group",
              inline = true,
              order = 2,
              args = {
                reference = {
                  type = "description",
                  fontSize = "medium",
                  width = "full",
                  order = 1,
                  name = "|cffffd100Alt+Up / Down|r  Browse older / newer sent messages and commands.",
                },
              },
            },
            bindings = {
              name = "WoW keybindings while typing",
              type = "group",
              inline = true,
              order = 3,
              args = {
                reference = {
                  type = "description",
                  fontSize = "medium",
                  width = "full",
                  order = 1,
                  name = "|cffffd100Alt + key|r  Use your WoW keybinding. Release Alt to resume typing.\n\n"..
                    "|cffffd100Shift-click a quest or item|r  Insert its link while chat is active.",
                },
              },
            },
            copying = {
              name = "Copying chat",
              type = "group",
              inline = true,
              order = 4,
              args = {
                reference = {
                  type = "description",
                  fontSize = "medium",
                  width = "full",
                  order = 1,
                  name = "|cffffd100Shift-click a chat tab|r  Open that tab's chat history for copying. Press Ctrl+C to copy it to the clipboard.",
                },
              },
            },
            commands = {
              name = "Commands",
              type = "group",
              inline = true,
              order = 5,
              args = {
                commandOpen = commandRow(1, "/gl", "Open settings"),
                commandMover = commandRow(2, "/gl lock", "Toggle the Glassy frame mover"),
                commandDebug = commandRow(3, "/gl debug", "Open a copyable layout debug report"),
                commandNews = commandRow(4, "/gl news", "Open version history"),
              },
            },
          },
        },
        messages = {
          name = "Messages",
          type = "group",
          order = 3,
          args = {
            section1 = {
              name = "Appearance",
              type = "group",
              inline = true,
              order = 1,
              args = {
                messageFontSize = {
                  name = "Font size",
                  desc = "Sets the font size of chat messages.\nDefault: "..Core.defaults.profile.messageFontSize..
                    "\nMin: 1\nMax: 100",
                  type = "range",
                  min = 1,
                  max = 100,
                  softMin = 6,
                  softMax = 24,
                  step = 1,
                  get = function ()
                    return Core.db.profile.messageFontSize
                  end,
                  set = function (info, input)
                    Core.db.profile.messageFontSize = input
                    Core:Dispatch(UpdateConfig("messageFontSize"))
                  end,
                  order = 1.1,
                },
                chatBackgroundColor = {
                  name = "Background",
                  desc = "Choose the color and opacity behind chat messages and the scroll overlay.\nDefault: black at 40% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 1.2,
                  get = function ()
                    local color = Core.db.profile.chatBackgroundColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.chatBackgroundColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("chatBackgroundColor"))
                  end,
                },
                unreadMessageSeparatorColor = {
                  name = "Unread-message separator",
                  desc = "Choose the separator color and opacity below the unread-message control. Set opacity to 0 to hide it.\nDefault: gold at 65% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 1.25,
                  get = function ()
                    local color = Core.db.profile.unreadMessageSeparatorColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.unreadMessageSeparatorColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("unreadMessageSeparatorColor"))
                  end,
                },
                unreadMessageBackgroundColor = {
                  name = "Unread-message background",
                  desc = "Choose the background color and opacity behind the jump-to-latest row, with or without unread messages.\nDefault: black at 40% opacity.",
                  type = "color",
                  hasAlpha = true,
                  order = 1.26,
                  get = function ()
                    local color = Core.db.profile.unreadMessageBackgroundColor
                    return color.r, color.g, color.b, color.a
                  end,
                  set = function (_, r, g, b, a)
                    Core.db.profile.unreadMessageBackgroundColor = {r = r, g = g, b = b, a = a}
                    Core:Dispatch(UpdateConfig("unreadMessageBackgroundColor"))
                  end,
                },
                messageLeading = {
                  name = "Wrapped line spacing",
                  desc = "Extra vertical space, in pixels, between wrapped lines within the same chat message.\nDefault: "..
                    Core.defaults.profile.messageLeading.." px\nMin: 0\nMax: 10",
                  type = "range",
                  min = 0,
                  max = 10,
                  softMin = 0,
                  softMax = 5,
                  step = 1,
                  get = function ()
                    return Core.db.profile.messageLeading
                  end,
                  set = function (info, input)
                    Core.db.profile.messageLeading = input
                    Core:Dispatch(UpdateConfig("messageLeading"))
                  end,
                  order = 1.3,
                },
                messageLinePadding = {
                  name = "Message padding",
                  desc = "Adds vertical padding above and below each message as a fraction of the line height. For example, 0.25 adds one-quarter of a line on each side.\nDefault: "..
                    Core.defaults.profile.messageLinePadding.."\nMin: 0\nMax: 5",
                  type = "range",
                  min = 0,
                  max = 5,
                  softMin = 0,
                  softMax = 1,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.messageLinePadding
                  end,
                  set = function (info, input)
                    Core.db.profile.messageLinePadding = input
                    Core:Dispatch(UpdateConfig("messageLinePadding"))
                  end,
                  order = 1.4,
                },
                iconTextureYOffset = {
                  type = "range",
                  name = "Inline icon offset",
                  desc = "Adjusts the vertical alignment of icons embedded in chat text.\nDefault: "..
                    Core.defaults.profile.iconTextureYOffset.." px\nMin: 0\nMax: 12",
                  order = 1.5,
                  min = 0,
                  max = 12,
                  softMin = 0,
                  softMax = 12,
                  step = 1,
                  get = function ()
                    return Core.db.profile.iconTextureYOffset
                  end,
                  set = function (_, input)
                    Core.db.profile.iconTextureYOffset = input
                    Core:Dispatch(UpdateConfig("iconTextureYOffset"))
                  end,
                },
                emojisEnabled = {
                  name = "Emoji shortcodes",
                  desc = "Show codes such as :smile: with ElvUI's emoji textures. Chat still sends the original text.\nDefault: enabled",
                  type = "toggle",
                  order = 1.6,
                  get = function ()
                    return Core.db.profile.emojisEnabled
                  end,
                  set = function (_, input)
                    Core.db.profile.emojisEnabled = input
                    Core:Dispatch(UpdateConfig("emojiDisplay"))
                  end,
                },
              },
            },
            section2 = {
              name = "Visibility",
              type = "group",
              inline = true,
              order = 2,
              args = {
                chatHoldTime = {
                  name = "Fade out delay",
                  desc = "How many seconds Glassy waits after a message arrives before starting its fade out.\nDefault: "..
                    Core.defaults.profile.chatHoldTime.." seconds\nMin: 1\nMax: 180",
                  type = "range",
                  order = 2.1,
                  min = 1,
                  max = 180,
                  softMin = 1,
                  softMax = 20,
                  step = 1,
                  get = function ()
                    return Core.db.profile.chatHoldTime
                  end,
                  set = function (info, input)
                    Core.db.profile.chatHoldTime = input
                  end,
                },
                chatShowOnMouseOver = {
                  name = "Show on mouse over",
                  desc = "Show faded chat messages again while the pointer is over the chat frame.\nDefault: on",
                  type = "toggle",
                  order = 2.2,
                  get = function ()
                    return Core.db.profile.chatShowOnMouseOver
                  end,
                  set = function (info, input)
                    Core.db.profile.chatShowOnMouseOver = input
                  end,
                },
                chatShowWhileTyping = {
                  name = "Show while typing",
                  desc = "Reveal faded chat messages while the chat input is open.\nDefault: off",
                  type = "toggle",
                  order = 2.3,
                  get = function ()
                    return Core.db.profile.chatShowWhileTyping
                  end,
                  set = function (_, input)
                    Core.db.profile.chatShowWhileTyping = input
                    Core:Dispatch(UpdateConfig("chatShowWhileTyping"))
                  end,
                },
              },
            },
            section3 = {
              name = "Fading",
              type = "group",
              inline = true,
              order = 3,
              args = {
                fadeInDuration = {
                  name = "Fade in duration",
                  desc = "How many seconds new messages and the chat header take to become fully visible. Set to 0 to show them instantly.\nDefault: "..
                    Core.defaults.profile.chatFadeInDuration.." seconds\nMin: 0\nMax: 30",
                  type = "range",
                  order = 3.1,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 10,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.chatFadeInDuration
                  end,
                  set = function (_, input)
                    Core.db.profile.chatFadeInDuration = input
                    Core:Dispatch(UpdateConfig("chatFadeInDuration"))
                  end
                },
                fadeOutDuration = {
                  name = "Fade out duration",
                  desc = "How many seconds messages and the chat header take to disappear after the fade-out delay. Set to 0 to hide them instantly.\nDefault: "..
                    Core.defaults.profile.chatFadeOutDuration.." seconds\nMin: 0\nMax: 30",
                  type = "range",
                  order = 3.2,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 10,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.chatFadeOutDuration
                  end,
                  set = function (_, input)
                    Core.db.profile.chatFadeOutDuration = input
                    Core:Dispatch(UpdateConfig("chatFadeOutDuration"))
                  end
                },
                fadeEasing = {
                  name = "Fade easing",
                  desc = "Controls how message and chat-header opacity accelerates and decelerates while fading in and out.\nDefault: "..
                    EASING_VALUES[Core.defaults.profile.chatFadeEasing],
                  type = "select",
                  order = 3.3,
                  values = EASING_VALUES,
                  sorting = EASING_SORTING,
                  get = function ()
                    return Core.db.profile.chatFadeEasing
                  end,
                  set = function (_, input)
                    Core.db.profile.chatFadeEasing = input
                    Core:Dispatch(UpdateConfig("chatFadeEasing"))
                  end,
                },
              },
            },
            section4 = {
              name = "Movement",
              type = "group",
              inline = true,
              order = 4,
              args = {
                slideInDuration = {
                  name = "Movement duration",
                  desc = "How many seconds existing messages take to move upward when new text arrives. Set to 0 to disable movement.\nDefault: "..
                    Core.defaults.profile.chatSlideInDuration.." seconds\nMin: 0\nMax: 30",
                  type = "range",
                  order = 4.1,
                  min = 0,
                  max = 30,
                  softMin = 0,
                  softMax = 5,
                  step = 0.05,
                  get = function ()
                    return Core.db.profile.chatSlideInDuration
                  end,
                  set = function (_, input)
                    Core.db.profile.chatSlideInDuration = input
                  end
                },
                slideInEasing = {
                  name = "Movement easing",
                  desc = "Controls how messages accelerate and decelerate while sliding upward.\nDefault: "..
                    EASING_VALUES[Core.defaults.profile.chatSlideInEasing],
                  type = "select",
                  order = 4.2,
                  values = EASING_VALUES,
                  sorting = EASING_SORTING,
                  disabled = function ()
                    return Core.db.profile.chatSlideInDuration <= 0
                  end,
                  get = function ()
                    return Core.db.profile.chatSlideInEasing
                  end,
                  set = function (_, input)
                    Core.db.profile.chatSlideInEasing = input
                  end,
                },
                previewAnimations = {
                  name = "Preview animations",
                  desc = "Add a temporary preview message to the selected Glassy tab and play the current movement and fade settings. If necessary, the preview returns that tab to its newest messages.",
                  type = "execute",
                  order = 4.3,
                  func = previewAnimations,
                }
              }
            },
            section5 = {
              name = "Behavior",
              type = "group",
              inline = true,
              order = 5,
              args = {
                indentWordWrap = {
                  name = "Indent on line wrap",
                  desc = "Indent continuation lines when a chat message wraps.\nDefault: on",
                  type = "toggle",
                  order = 5.1,
                  get = function ()
                    return Core.db.profile.indentWordWrap
                  end,
                  set = function (info, input)
                    Core.db.profile.indentWordWrap = input
                    Core:Dispatch(UpdateConfig("indentWordWrap"))
                  end,
                },
                mouseOverTooltips = {
                  name = "Mouse over tooltips",
                  desc = "Show the standard game tooltip when hovering over supported links in chat.\nDefault: on",
                  type = "toggle",
                  order = 5.2,
                  get = function ()
                    return Core.db.profile.mouseOverTooltips
                  end,
                  set = function (info, input)
                    Core.db.profile.mouseOverTooltips = input
                  end,
                },
                messageBlacklistEnabled = {
                  name = "Message blacklist",
                  desc = "Hide chat messages containing any blocked phrase.\nDefault: off",
                  type = "toggle",
                  order = 5.3,
                  get = function ()
                    return Core.db.profile.messageBlacklistEnabled
                  end,
                  set = function (_, input)
                    Core.db.profile.messageBlacklistEnabled = input
                    Core:Dispatch(UpdateConfig("messageBlacklist"))
                  end,
                },
                messageBlacklist = {
                  name = "Blocked phrases",
                  desc = "Enter one plain-text phrase per line. Matching ignores letter case and repeated whitespace.",
                  type = "input",
                  multiline = 8,
                  width = "full",
                  order = 5.4,
                  disabled = function ()
                    return not Core.db.profile.messageBlacklistEnabled
                  end,
                  get = function ()
                    return Core.db.profile.messageBlacklist
                  end,
                  set = function (_, input)
                    Core.db.profile.messageBlacklist = input or ""
                    Core:Dispatch(UpdateConfig("messageBlacklist"))
                  end,
                },
              }
            },
            section6 = {
              name = "History",
              type = "group",
              inline = true,
              order = 6,
              args = {
                scrollbackLines = {
                  type = "range",
                  name = "Scrollback lines",
                  desc = "Number of recent messages retained in each chat tab for copying. Glassy keeps up to 128 rendered messages for on-screen scrolling.\nDefault: "..
                    Core.defaults.profile.scrollbackLines.."\nMin: 50\nMax: 2000",
                  order = 6.1,
                  min = 50,
                  max = 2000,
                  softMin = 128,
                  softMax = 1000,
                  step = 50,
                  get = function ()
                    return Core.db.profile.scrollbackLines
                  end,
                  set = function (_, input)
                    Core.db.profile.scrollbackLines = input
                    Core:Dispatch(UpdateConfig("scrollbackLines"))
                  end,
                },
              }
            },
          },
        },
        timestamps = {
          name = "Timestamps",
          type = "group",
          order = 4,
          args = {
            settings = {
              name = "Settings",
              type = "group",
              inline = true,
              order = 1,
              args = {
                timestampsEnabled = {
                  name = "Show timestamps",
                  desc = "Adds Glassy-owned timestamps to new and retained chat messages. Enabling this turns off WoW's built-in timestamps to prevent duplicates.\nDefault: Disabled",
                  type = "toggle",
                  order = 1.1,
                  get = function ()
                    return Core.db.profile.timestampsEnabled
                  end,
                  set = function (_, input)
                    Core.db.profile.timestampsEnabled = input
                    if input then
                      disableBuiltinTimestamps()
                    end
                    Core:Dispatch(UpdateConfig("timestampDisplay"))
                  end,
                },
                timestampFormat = {
                  name = "Format",
                  desc = "Choose the time format used before each message.\nDefault: [23:59:59]",
                  type = "select",
                  order = 1.2,
                  values = TIMESTAMP_FORMATS,
                  disabled = function ()
                    return not Core.db.profile.timestampsEnabled
                  end,
                  get = function ()
                    return Core.db.profile.timestampFormat
                  end,
                  set = function (_, input)
                    Core.db.profile.timestampFormat = input
                    Core:Dispatch(UpdateConfig("timestampDisplay"))
                  end,
                },
                timestampColorEnabled = {
                  name = "Override color",
                  desc = "Apply the selected color to timestamps. Disable this to add no timestamp color code, allowing the chat line's existing color to apply.\nDefault: Enabled",
                  type = "toggle",
                  order = 1.3,
                  disabled = function ()
                    return not Core.db.profile.timestampsEnabled
                  end,
                  get = function ()
                    return Core.db.profile.timestampColorEnabled
                  end,
                  set = function (_, input)
                    Core.db.profile.timestampColorEnabled = input
                    Core:Dispatch(UpdateConfig("timestampDisplay"))
                  end,
                },
                timestampColor = {
                  name = "Color",
                  desc = "Choose the timestamp text color used when Override color is enabled.\nDefault: gray",
                  type = "color",
                  order = 1.4,
                  disabled = function ()
                    return not Core.db.profile.timestampsEnabled or not Core.db.profile.timestampColorEnabled
                  end,
                  get = function ()
                    local color = Core.db.profile.timestampColor
                    return color.r, color.g, color.b
                  end,
                  set = function (_, r, g, b)
                    Core.db.profile.timestampColor = {r = r, g = g, b = b, a = 1}
                    Core:Dispatch(UpdateConfig("timestampDisplay"))
                  end,
                },
                timestampFrames = {
                  name = "Chat windows",
                  desc = "Choose which chat windows receive Glassy timestamps.",
                  type = "multiselect",
                  order = 1.5,
                  values = getTimestampFrameOptions,
                  disabled = function ()
                    return not Core.db.profile.timestampsEnabled
                  end,
                  get = function (_, frameName)
                    return Core.db.profile.timestampFrames[frameName]
                  end,
                  set = function (_, frameName, enabled)
                    Core.db.profile.timestampFrames[frameName] = enabled
                    Core:Dispatch(UpdateConfig("timestampDisplay"))
                  end,
                },
              },
            },
          },
        },
        combatLog = {
          name = "Combat Log",
          type = "group",
          order = 5,
          args = {
            visibility = {
              name = "Visibility",
              type = "group",
              inline = true,
              order = 1,
              args = {
                combatLogVisible = {
                  name = "Show Combat Log",
                  desc = "Show the Combat Log tab and its Glassy renderer. When hidden, combat events continue to be retained in the background so recent history returns when you show it again.\nDefault: Enabled",
                  type = "toggle",
                  order = 1,
                  get = function ()
                    return not Core.db.profile.combatLogHidden
                  end,
                  set = function (_, input)
                    Core.db.profile.combatLogHidden = not input
                    Core:Dispatch(UpdateConfig("combatLogVisibility"))
                  end,
                },
              },
            },
            layout = {
              name = "Filter bar",
              type = "group",
              inline = true,
              order = 2,
              disabled = function ()
                return Core.db.profile.combatLogHidden
              end,
              args = {
                combatLogBarPosition = {
                  name = "Position",
                  desc = "Places the Combat Log filter bar above or below the main Glassy tabs, or hides it. The bar appears only while the Combat Log tab is selected.\nDefault: Below tabs",
                  type = "select",
                  order = 1.1,
                  values = COMBAT_LOG_BAR_POSITIONS,
                  get = function ()
                    return Core.db.profile.combatLogBarPosition
                  end,
                  set = function (_, input)
                    Core.db.profile.combatLogBarPosition = input
                    Core:Dispatch(UpdateConfig("combatLogBarLayout"))
                  end,
                },
                combatLogBarXOffset = {
                  name = "Horizontal offset",
                  desc = "Moves the Combat Log filter bar horizontally from its docked position. Positive values move it right; negative values move it left.\nDefault: 0 px\nMin: -500\nMax: 500",
                  type = "range",
                  order = 1.2,
                  min = -MAX_COMBAT_LOG_BAR_OFFSET,
                  max = MAX_COMBAT_LOG_BAR_OFFSET,
                  softMin = -100,
                  softMax = 100,
                  step = 1,
                  disabled = function ()
                    return Core.db.profile.combatLogBarPosition == "HIDDEN"
                  end,
                  get = function ()
                    return Core.db.profile.combatLogBarXOffset
                  end,
                  set = function (_, input)
                    Core.db.profile.combatLogBarXOffset = input
                    Core:Dispatch(UpdateConfig("combatLogBarLayout"))
                  end,
                },
                combatLogBarYOffset = {
                  name = "Vertical offset",
                  desc = "Moves the Combat Log filter bar vertically from its docked position. Positive values move it up; negative values move it down.\nDefault: 0 px\nMin: -500\nMax: 500",
                  type = "range",
                  order = 1.3,
                  min = -MAX_COMBAT_LOG_BAR_OFFSET,
                  max = MAX_COMBAT_LOG_BAR_OFFSET,
                  softMin = -100,
                  softMax = 100,
                  step = 1,
                  disabled = function ()
                    return Core.db.profile.combatLogBarPosition == "HIDDEN"
                  end,
                  get = function ()
                    return Core.db.profile.combatLogBarYOffset
                  end,
                  set = function (_, input)
                    Core.db.profile.combatLogBarYOffset = input
                    Core:Dispatch(UpdateConfig("combatLogBarLayout"))
                  end,
                },
              },
            },
          },
        },
        compatibility = {
          name = "Compatibility",
          type = "group",
          order = 6,
          args = {
            pratStatus = {
              name = getPratStatus,
              type = "description",
              fontSize = "medium",
              order = 1,
            },
            elvuiStatus = {
              name = getElvUIStatus,
              type = "description",
              fontSize = "medium",
              order = 1.1,
            },
            pratBoundary = {
              name = "Glassy owns its renderer, tabs, edit box, scrolling, history, timestamps, copying, and tooltips. Prat remains optional and may format message content before Glassy receives it.",
              type = "description",
              order = 2,
            },
            pratSupported = {
              name = "Supported Prat features",
              type = "group",
              inline = true,
              order = 3,
              args = {
                details = {
                  name = formatList({
                    "Player and channel name formatting",
                    "Text substitutions, filters, and highlights",
                    "URL and invite links",
                    "Link icons, sounds, and popups",
                    "Channel color memory",
                  }),
                  type = "description",
                  order = 1,
                },
              },
            },
            pratUiModules = {
              name = "Prat UI modules",
              type = "group",
              inline = true,
              order = 4,
              args = {
                current = {
                  name = getEnabledPratUiModules,
                  type = "description",
                  order = 1,
                },
                details = {
                  name = getPratUiModuleGuidance,
                  type = "description",
                  order = 2,
                },
              },
            },
            pratTimestamps = {
              name = "Prat Timestamps",
              type = "group",
              inline = true,
              order = 5,
              args = {
                current = {
                  name = getPratTimestampStatus,
                  type = "description",
                  order = 1,
                },
              },
            },
            pratHistory = {
              name = "Prat History",
              type = "group",
              inline = true,
              order = 6,
              args = {
                details = {
                  name = formatList({
                    "Restored Prat history is displayed by Glassy.",
                    "Glassy's Scrollback lines setting controls the retained line limit.",
                    "Prat's Set Chat Lines value is intentionally not used.",
                  }),
                  type = "description",
                  order = 1,
                },
              },
            },
            elvuiEmojis = {
              name = "ElvUI emojis",
              type = "group",
              inline = true,
              order = 7,
              args = {
                details = {
                  name = "Uses ElvUI's emoji textures when ElvUI is available.",
                  type = "description",
                  order = 1,
                },
              },
            },
          },
        },
        profile = getProfileOptions(),
        about = {
          name = "About",
          type = "group",
          order = 8,
          args = {
            details = {
              name = "",
              type = "group",
              inline = true,
              order = 1,
              args = {
                version = {
                  name = " |cffffd100Version:|r  "..Core.Version,
                  type = "description",
                  width = "full",
                  fontSize = "medium",
                  order = 1,
                },
                whatsNew = infoRow(2, {button = {
                  name = "What’s new",
                  desc = "Open a summary of new features, improvements, and important fixes.",
                  type = "execute",
                  width = 1,
                  func = function() Core:Dispatch(OpenNews()) end,
                  order = 1,
                }}),
                reportIssue = infoRow(3, {button = {
                  name = "Report an issue",
                  type = "execute",
                  width = 1,
                  func = function() Core:GetModule("News"):ShowIssueLink() end,
                  order = 1,
                }}),
              },
            },
          },
        },
      }
  }

  options.args.profile.order = 7
  Core:LocalizeOptions(options)

  AceConfig:RegisterOptionsTable("Glassy", options)
  AceConfigDialog:SetDefaultSize("Glassy", 900, 650)

  self:RegisterChatCommand("gl", "OnSlashCommand")
  self:RegisterChatCommand("glassy", "OnSlashCommand")
  self:RegisterChatCommand("glass", "OnSlashCommand")

  Core.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
  Core.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")
  Core.db.RegisterCallback(self, "OnProfileReset", "RefreshConfig")

  Core:Subscribe(SAVE_FRAME_POSITION, function (position)
    Core.db.profile.positionAnchor = position
  end)
end

function C:OnSlashCommand(input)
  input = input or ""

  if input == "lock" then
    toggleMover()
  elseif input == "debug" then
    self:OnDebugCommand()
  elseif input == "news" then
    Core:Dispatch(OpenNews())
  else
    AceConfigDialog:Open("Glassy")
  end
end

local function debugName(region)
  if region == nil then
    return "nil"
  end

  if type(region) == "string" then
    return region
  end

  return region.GetName and (region:GetName() or tostring(region)) or tostring(region)
end

local function debugNumber(value)
  return value and string.format("%.1f", value) or "nil"
end

local function debugPoint(region)
  local point, relativeTo, relativePoint, xOffset, yOffset = region:GetPoint(1)
  return string.format(
    "%s > %s:%s (%s, %s)",
    point or "nil",
    debugName(relativeTo),
    relativePoint or "nil",
    debugNumber(xOffset),
    debugNumber(yOffset)
  )
end

local function debugGeometry(region)
  local _, centerY = region:GetCenter()
  return string.format(
    "h=%s centerY=%s bottom=%s top=%s",
    debugNumber(region:GetHeight()),
    debugNumber(centerY),
    debugNumber(region:GetBottom()),
    debugNumber(region:GetTop())
  )
end

local copyableFrame
local copyableTextBox

showCopyableText = function(title, text)
  if copyableFrame == nil then
    copyableFrame = AceGUI:Create("Frame")
    copyableFrame:SetWidth(760)
    copyableFrame:SetHeight(420)
    copyableFrame:SetStatusText(L("Press Ctrl+C to copy, then close this window."))
    copyableFrame:SetCallback("OnClose", function(widget)
      widget:Hide()
    end)
    copyableFrame:SetLayout("Fill")

    copyableTextBox = AceGUI:Create("MultiLineEditBox")
    copyableTextBox:SetLabel(L("All text is selected"))
    copyableTextBox:DisableButton(true)
    copyableFrame:AddChild(copyableTextBox)
  end

  copyableFrame:SetTitle(title)
  copyableTextBox:SetText(text)
  copyableFrame:Show()
  copyableTextBox:SetFocus()
  copyableTextBox:HighlightText()
end

local function showDebugReport(report)
  showCopyableText(L("Glassy: Debug report"), report)
end

function C:OnDebugCommand()
  local dock = _G.GeneralDockManager
  local scrollFrame = dock.scrollFrame
  local scrollChild = scrollFrame.child
  local combatLogBar = _G.CombatLogQuickButtonFrame_Custom
  local uiManager = Core:GetModule("UIManager")
  local report = {}

  report[#report + 1] = "Glassy "..Core.Version.." debug report"
  report[#report + 1] = string.format(
    "Selected: chat=%s dock=%s selectedDock=%s",
    debugName(_G.SELECTED_CHAT_FRAME),
    debugName(dock.selected),
    debugName(_G.SELECTED_DOCK_FRAME)
  )
  report[#report + 1] = "Combat Log hidden="..tostring(Core.db.profile.combatLogHidden)
  report[#report + 1] = "Dock: "..debugGeometry(dock).." point="..debugPoint(dock)
  report[#report + 1] = "Scroll: "..debugGeometry(scrollFrame).." point="..debugPoint(scrollFrame)
  report[#report + 1] = "Child: "..debugGeometry(scrollChild).." point="..debugPoint(scrollChild)
  if combatLogBar then
    report[#report + 1] = "Combat Log bar: "..debugGeometry(combatLogBar).." point="..debugPoint(combatLogBar)..
      " setting="..Core.db.profile.combatLogBarPosition.." shown="..tostring(combatLogBar:IsShown())
  end

  for order, chatFrame in ipairs(dock.DOCKED_CHAT_FRAMES) do
    local tab = _G[chatFrame:GetName().."Tab"]
    local text = tab.Text
    local _, fontSize, fontFlags = text:GetFont()
    local slidingMessageFrame = uiManager.state.frames[chatFrame:GetID()] or
      uiManager.state.temporaryFrames[chatFrame:GetName()]

    report[#report + 1] = string.format(
      "#%d %s static=%s parent=%s tabShown=%s nativeShown=%s nativeVisible=%s glassyShown=%s glassyVisible=%s",
      order,
      chatFrame:GetName(),
      tostring(not not chatFrame.isStaticDocked),
      debugName(tab:GetParent()),
      tostring(tab:IsShown()),
      tostring(chatFrame:IsShown()),
      tostring(chatFrame:IsVisible()),
      tostring(slidingMessageFrame and slidingMessageFrame:IsShown()),
      tostring(slidingMessageFrame and slidingMessageFrame:IsVisible())
    )
    report[#report + 1] = "  Tab: "..debugGeometry(tab).." point="..debugPoint(tab)
    report[#report + 1] = string.format(
      "  Text: %s stringH=%s font=%s flags=%s point=%s",
      debugGeometry(text),
      debugNumber(text:GetStringHeight()),
      debugNumber(fontSize),
      fontFlags or "",
      debugPoint(text)
    )
  end

  showDebugReport(table.concat(report, "\n"))
end

function C:RefreshConfig()
  migrateSettings()
  normalizeBackgroundColors()
  normalizeBackgroundFades()
  normalizeFrameHeight()
  normalizeTabMessageSpacing()
  normalizeTextLeftPadding()
  normalizeActiveTabHighlight()
  normalizeTabHoverHighlight()
  normalizeEditBox()
  normalizeCombatLogBar()
  normalizeTimestamps()
  normalizeAnimationEasings()
  if Core.db.profile.timestampsEnabled then
    disableBuiltinTimestamps()
  end

  -- General
  Core:Dispatch(UpdateConfig("font"))
  Core:Dispatch(UpdateConfig("frameHeight"))
  Core:Dispatch(UpdateConfig("frameWidth"))
  Core:Dispatch(UpdateConfig("framePosition"))
  Core:Dispatch(UpdateConfig("textLeftPadding"))
  Core:Dispatch(UpdateConfig("activeTabHighlightStrength"))
  Core:Dispatch(UpdateConfig("tabHoverHighlightStrength"))
  Core:Dispatch(UpdateConfig("chatTabTooltips"))
  Core:Dispatch(UpdateConfig("tabMessageSeparatorColor"))
  Core:Dispatch(UpdateConfig("tabMessageSpacing"))
  Core:Dispatch(UpdateConfig("headerBackgroundColor"))
  Core:Dispatch(UpdateConfig("backgroundFade"))
  Core:Dispatch(UpdateConfig("combatLogVisibility"))
  Core:Dispatch(UpdateConfig("combatLogBarLayout"))

  -- Edit box
  Core:Dispatch(UpdateConfig("editBoxFontSize"))
  Core:Dispatch(UpdateConfig("editBoxVerticalPadding"))
  Core:Dispatch(UpdateConfig("editBoxBackgroundColor"))
  Core:Dispatch(UpdateConfig("editBoxMessageSeparatorColor"))
  Core:Dispatch(UpdateConfig("editBoxBackgroundEasing"))
  Core:Dispatch(UpdateConfig("editBoxEasing"))
  Core:Dispatch(UpdateConfig("editBoxAnchor"))
  Core:Dispatch(UpdateConfig("dynamicEditBox"))

  -- Messages
  Core:Dispatch(UpdateConfig("messageFontSize"))
  Core:Dispatch(UpdateConfig("messageLeading"))
  Core:Dispatch(UpdateConfig("messageLinePadding"))
  Core:Dispatch(UpdateConfig("indentWordWrap"))
  Core:Dispatch(UpdateConfig("iconTextureYOffset"))
  Core:Dispatch(UpdateConfig("emojiDisplay"))
  Core:Dispatch(UpdateConfig("chatBackgroundColor"))
  Core:Dispatch(UpdateConfig("unreadMessageSeparatorColor"))
  Core:Dispatch(UpdateConfig("unreadMessageBackgroundColor"))
  Core:Dispatch(UpdateConfig("timestampDisplay"))
  Core:Dispatch(UpdateConfig("chatFadeInDuration"))
  Core:Dispatch(UpdateConfig("chatFadeOutDuration"))
  Core:Dispatch(UpdateConfig("scrollbackLines"))

  -- For things that don't update using the config frame e.g. frame position
  Core:Dispatch(RefreshConfig())
end
