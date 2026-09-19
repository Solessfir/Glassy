local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceConfig = Core.Libs.AceConfig
local AceConfigDialog = Core.Libs.AceConfigDialog
local AceGUI = Core.Libs.AceGUI
local L = function(text) return Core:Localize(text) end

local CURRENT_SETTINGS_VERSION = 3

local OpenNews = Constants.ACTIONS.OpenNews
local LockMover = Constants.ACTIONS.LockMover
local RefreshConfig = Constants.ACTIONS.RefreshConfig
local UnlockMover = Constants.ACTIONS.UnlockMover
local UpdateConfig = Constants.ACTIONS.UpdateConfig

local SAVE_FRAME_POSITION = Constants.EVENTS.SAVE_FRAME_POSITION

local SettingsValues = {
  maxActiveTabHighlight = 1,
  maxTabHoverHighlight = 1,
  maxTabMessageOffset = 50,
  maxCombatLogBarOffset = 500,
  minFrameHeight = 100,
  maxTextLeftPadding = 100,
  maxEditBoxVerticalPadding = 2,
  anchors = {
    TOPLEFT = L("Top left"),
    TOPRIGHT = L("Top right"),
    BOTTOMLEFT = L("Bottom left"),
    BOTTOMRIGHT = L("Bottom right"),
  },
  fontFlags = {
    [""] = L("None"),
    OUTLINE = L("Outline"),
    ["OUTLINE, MONOCHROME"] = L("Outline Monochrome"),
  },
  combatLogBarPositions = {
    ABOVE = L("Above tabs"),
    BELOW = L("Below tabs"),
    HIDDEN = L("Hidden"),
  },
  timestampFormats = {
    ["[%H:%M]"] = "[23:59]",
    ["[%H:%M:%S]"] = "[23:59:59]",
    ["[%I:%M %p]"] = "[11:59 PM]",
    ["[%I:%M:%S %p]"] = "[11:59:59 PM]",
  },
  easingValues = {
    Linear = L("Linear"),
    InCubic = L("Ease in"),
    OutCubic = L("Ease out"),
    InOutCubic = L("Ease in/out"),
    OutBack = L("Overshoot"),
    OutBounce = L("Bounce"),
    OutElastic = L("Elastic"),
  },
  easingSorting = {
    "Linear",
    "InCubic",
    "OutCubic",
    "InOutCubic",
    "OutBack",
    "OutBounce",
    "OutElastic",
  },
}

C.SettingsValues = SettingsValues
C.Pages = {}

local MAX_ACTIVE_TAB_HIGHLIGHT = SettingsValues.maxActiveTabHighlight
local MAX_TAB_HOVER_HIGHLIGHT = SettingsValues.maxTabHoverHighlight
local MAX_TAB_MESSAGE_OFFSET = SettingsValues.maxTabMessageOffset
local MAX_COMBAT_LOG_BAR_OFFSET = SettingsValues.maxCombatLogBarOffset
local MIN_FRAME_HEIGHT = SettingsValues.minFrameHeight
local MAX_TEXT_LEFT_PADDING = SettingsValues.maxTextLeftPadding
local MAX_EDIT_BOX_VERTICAL_PADDING = SettingsValues.maxEditBoxVerticalPadding
local COMBAT_LOG_BAR_POSITIONS = SettingsValues.combatLogBarPositions
local TIMESTAMP_FORMATS = SettingsValues.timestampFormats
local EASING_VALUES = SettingsValues.easingValues

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

C.IsMoverUnlocked = isMoverUnlocked
C.ToggleMover = toggleMover

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


C.GetTimestampFrameOptions = getTimestampFrameOptions

local function disableBuiltinTimestamps()
  local getCVar = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
  local setCVar = _G.C_CVar and _G.C_CVar.SetCVar or _G.SetCVar
  if getCVar and setCVar and getCVar("showTimestamps") ~= "none" then
    setCVar("showTimestamps", "none")
  end
  _G.CHAT_TIMESTAMP_FORMAT = nil
end


C.DisableBuiltinTimestamps = disableBuiltinTimestamps

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

local function normalizeSettings()
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
end


local function getOptions()
  local profile = C.Pages.profile()
  profile.order = 7
  return {
    name = "Glassy",
    handler = C,
    type = "group",
    args = {
      general = C.Pages.general(),
      editBox = C.Pages.editBox(),
      messages = C.Pages.messages(),
      timestamps = C.Pages.timestamps(),
      combatLog = C.Pages.combatLog(),
      compatibility = C.Pages.compatibility(),
      shortcuts = C.Pages.shortcuts(),
      profile = profile,
      about = C.Pages.about(),
    },
  }
end

function C:OnEnable()
  normalizeSettings()
  local options = getOptions()
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

function C:ShowCopyableText(title, text)
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
  C:ShowCopyableText(L("Glassy: Debug report"), report)
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
    local slidingMessageFrame = uiManager:GetSlidingMessageFrame(chatFrame)

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
