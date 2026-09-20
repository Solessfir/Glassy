local _G = _G

local AceAddon = _G.LibStub("AceAddon-3.0")
local GetAddOnMetadata = (_G.C_AddOns and _G.C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata

local AddonName, AddonVars = ...
local Core = AceAddon:NewAddon(AddonName)
local Constants = {}
local Utils = {}
AddonVars[1] = Core
AddonVars[2] = Constants
AddonVars[3] = Utils
_G[AddonName] = Core

-- Core
Core.Libs = {
  AceConfig = _G.LibStub("AceConfig-3.0"),
  AceConfigDialog = _G.LibStub("AceConfigDialog-3.0"),
  AceDB = _G.LibStub("AceDB-3.0"),
  AceDBOptions = _G.LibStub("AceDBOptions-3.0"),
  AceGUI = _G.LibStub("AceGUI-3.0"),
  AceHook = _G.LibStub("AceHook-3.0"),
  LSM = _G.LibStub("LibSharedMedia-3.0"),
  LibEasing = _G.LibStub("LibEasing-1.0"),
  lodash = _G.LibStub("lodash.wow")
}
Core.Components = {}
Core.Version = GetAddOnMetadata and GetAddOnMetadata(AddonName, "Version") or "0.0.0"

-- Modules
Core:NewModule("Config", "AceConsole-3.0")
Core:NewModule("ChatCopy", "AceConsole-3.0")
Core:NewModule("Fonts")
Core:NewModule("Hyperlinks")
Core:NewModule("News")
Core:NewModule("ProfileTransfer")
Core:NewModule("TextProcessing")
Core:NewModule("UIManager", "AceHook-3.0")

-- Default settings
Core.defaults = {
  profile = {
    -- General
    font = "Friz Quadrata TT",
    tabFont = "",
    messageFont = "",
    editBoxFont = "",
    tabFontFlags = "",
    messageFontFlags = "",
    editBoxFontFlags = "",
    frameWidth = 600,
    frameHeight = 250,
    textLeftPadding = 4,
    tabFontSize = 13,
    tabTextColor = {r = 171 / 255, g = 154 / 255, b = 27 / 255, a = 1},
    tabHighlightTextColor = {r = 202 / 255, g = 182 / 255, b = 32 / 255, a = 1},
    chatTabTooltips = false,
    tabMessageSeparatorColor = {
      r = 171 / 255,
      g = 154 / 255,
      b = 27 / 255,
      a = 0,
    },
    tabMessageSpacing = 2,
    backgroundFadeLeftPercent = 0,
    backgroundFadeRightPercent = 60,
    headerBackgroundColor = {
      r = 0,
      g = 0,
      b = 0,
      a = 0.5,
    },
    positionAnchor = {
      point = "BOTTOMLEFT",
      xOfs = 0,
      yOfs = 0
    },

    -- Combat log
    combatLogHidden = false,
    combatLogBarPosition = "BELOW",
    combatLogBarXOffset = 0,
    combatLogBarYOffset = 0,
    selectedTab = "",
    tabOrder = {},

    -- Edit box
    editBoxEasing = "OutCubic",
    editBoxBackgroundEasing = "OutCubic",
    editBoxFadeInDuration = 0.2,
    editBoxFadeOutDuration = 0.2,
    editBoxFontSize = 13,
    editBoxVerticalPadding = 0.45,
    editBoxMessageSeparatorColor = {
      r = 171 / 255,
      g = 154 / 255,
      b = 27 / 255,
      a = 0,
    },
    editBoxBackgroundColor = {
      r = 0,
      g = 0,
      b = 0,
      a = 0.5,
    },
    editBoxAnchor = {
      position = "BELOW",
      yOfs = -2
    },

    -- Messages
    messageFontSize = 13,
    chatBackgroundColor = {
      r = 0,
      g = 0,
      b = 0,
      a = 0.5,
    },
    unreadMessageSeparatorColor = {
      r = 171 / 255,
      g = 154 / 255,
      b = 27 / 255,
      a = 0,
    },
    unreadMessageBackgroundColor = {
      r = 0,
      g = 0,
      b = 0,
      a = 0.5,
    },
    messageLeading = 3,
    messageLinePadding = 0.25,
    emojisEnabled = true,
    messageBlacklistEnabled = false,
    messageBlacklist = "",
    scrollbackLines = 500,
    timestampsEnabled = false,
    timestampFormat = "[%H:%M:%S]",
    timestampColorEnabled = true,
    timestampColor = {
      r = 0.6,
      g = 0.6,
      b = 0.6,
      a = 1,
    },
    timestampFrames = {
      ["*"] = true,
    },

    chatHoldTime = 10,
    chatAlwaysVisible = false,
    chatShowWhileTyping = true,
    chatFadeInDuration = 0.4,
    chatFadeOutDuration = 0.6,
    chatFadeEasing = "OutCubic",
    chatSlideInDuration = 0.3,
    chatSlideInEasing = "OutCubic",

    indentWordWrap = true,
    mouseOverTooltips = true,
    iconTextureYOffset = 4,
  }
}

function Core:OnInitialize()
  self.listeners = {}

  self.defaults.profile.font = self.Libs.LSM:GetDefault("font")
  self.db = self.Libs.AceDB:New("GlassyDB", self.defaults, true)
  self.printBuffer = {}
end

function Core:OnEnable()
  -- Other addons replace Blizzard fonts during login; resolve their final path next frame.
  _G.C_Timer.After(0, function() self:SelectDefaultFont() end)
  -- Buffer print messages until ViragDevTool loads
  for _, item in ipairs(self.printBuffer) do
    Utils.print(unpack(item))
  end
  self.printBuffer = {}
end

function Core:SelectDefaultFont()
  local path = _G.GameFontNormal and _G.GameFontNormal:GetFont() or _G.STANDARD_TEXT_FONT
  local media = self.Libs.LSM:HashTable("font")
  local selected = self.Libs.LSM:GetDefault("font")
  for _, name in ipairs(self.Libs.LSM:List("font")) do
    if path and media[name]:lower():gsub("/", "\\") == path:lower():gsub("/", "\\") then
      selected = name
      break
    end
  end

  self.db:RegisterDefaults(nil)
  if self.db.profile.font == "Glassy: Game default" then
    self.db.profile.font = nil
  end
  self.defaults.profile.font = selected
  self.db:RegisterDefaults(self.defaults)
  self:Dispatch(Constants.ACTIONS.UpdateConfig("font"))
end

function Core:Subscribe(messageType, listener)
  if self.listeners[messageType] == nil then
    self.listeners[messageType] = {}
  end

  local listeners = self.listeners[messageType]
  local index = #listeners + 1
  listeners[index] = listener

  return function ()
    self.Libs.lodash.remove(listeners, function (val) return val == listener end)
  end
end

function Core:Dispatch(messageType, payload)
  --[===[@debug@--
  Utils.print('E: '..messageType, payload)
  --@end-debug@]===]--

  local listeners = self.listeners[messageType] or {}
  for _, listener in ipairs(listeners) do
    listener(payload)
  end
end
