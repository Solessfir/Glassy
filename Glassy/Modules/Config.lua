local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local AceConfig = Core.Libs.AceConfig
local AceConfigDialog = Core.Libs.AceConfigDialog
local AceGUI = Core.Libs.AceGUI
local L = function(text) return Core:Localize(text) end

local CURRENT_SETTINGS_VERSION = 7

local OpenNews = Constants.ACTIONS.OpenNews
local LockMover = Constants.ACTIONS.LockMover
local RefreshConfig = Constants.ACTIONS.RefreshConfig
local UnlockMover = Constants.ACTIONS.UnlockMover
local UpdateConfig = Constants.ACTIONS.UpdateConfig

local SAVE_FRAME_POSITION = Constants.EVENTS.SAVE_FRAME_POSITION

local SettingsValues = {
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
    SHADOW = L("Shadow"),
    SHADOWOUTLINE = L("Shadow Outline"),
    SHADOWTHICKOUTLINE = L("Shadow Thick"),
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
  profile.messageTopShadowColor = nil
  profile.messageBottomShadowColor = nil
  profile.unreadMessageShadow = nil
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
  if version < 4 then
    profile.dynamicEditBox = nil
  end
  if version < 5 then
    profile.tabHoverHighlightStrength = nil
    profile.combatLogHoverHighlightStrength = nil
  end
  if version < 6 then
    local color = rawget(profile, "unreadMessageSeparatorColor")
    if type(color) == "table" and color.r == 0.8745 and color.g == 0.7294 and color.b == 0.4118 and color.a == 0.65 then
      color.a = 0
    end
  end
  if version < 7 then
    if rawget(profile, "tabMessageSpacing") == 0 then
      profile.tabMessageSpacing = nil
    end
    local editBoxAnchor = rawget(profile, "editBoxAnchor")
    if type(editBoxAnchor) == "table" and rawget(editBoxAnchor, "yOfs") == 0 then
      editBoxAnchor.yOfs = nil
    end
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

local function normalizeEditBox()
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
  Core:GetModule("ProfileTransfer"):NormalizeBackgroundFades(Core.db.profile, Core.defaults.profile)
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
  local tabs = C.Pages.tabs()
  local combatLog = C.Pages.combatLog()
  combatLog.inline = true
  combatLog.order = 2
  tabs.args.combatLog = combatLog
  local about = C.Pages.about()
  local shortcuts = C.Pages.shortcuts()
  shortcuts.inline = true
  shortcuts.order = 2
  about.args.shortcuts = shortcuts
  local compatibility = C.Pages.compatibility()
  compatibility.inline = true
  compatibility.order = 3
  about.args.compatibility = compatibility
  return {
    name = "Glassy",
    handler = C,
    type = "group",
    args = {
      general = C.Pages.general(),
      tabs = tabs,
      editBox = C.Pages.editBox(),
      messages = C.Pages.messages(),
      profile = profile,
      about = about,
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
  elseif input == "debug 3" then
    C_Timer.After(3, function () self:OnDebugCommand() end)
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

local function debugPoint(region, index)
  local point, relativeTo, relativePoint, xOffset, yOffset = region:GetPoint(index or 1)
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

local function appendDebugRegion(report, label, region)
  if not region then
    report[#report + 1] = label..": nil"
    return
  end
  local scale = region:GetEffectiveScale()
  -- Classic textures expose their own alpha but not a frame's effective-alpha method.
  local effectiveAlpha = region.GetEffectiveAlpha and string.format("%.4f", region:GetEffectiveAlpha()) or "unavailable"
  report[#report + 1] = string.format(
    "%s: %s shown=%s visible=%s alpha=%.4f effectiveAlpha=%s scale=%.6f top=%.6f bottom=%.6f parent=%s",
    label, debugName(region), tostring(region:IsShown()), tostring(region:IsVisible()),
    region:GetAlpha(), effectiveAlpha, scale,
    region:GetTop() or 0, region:GetBottom() or 0, debugName(region:GetParent())
  )
  for index = 1, region:GetNumPoints() do
    report[#report + 1] = "  anchor "..index..": "..debugPoint(region, index)
  end
  if region.GetDrawLayer then
    local layer, sublevel = region:GetDrawLayer()
    report[#report + 1] = "  layer="..tostring(layer).." sublevel="..tostring(sublevel)
  elseif region.GetFrameLevel then
    report[#report + 1] = "  strata="..region:GetFrameStrata().." level="..region:GetFrameLevel()
  end
end

local function appendDebugBackground(report, label, frame)
  appendDebugRegion(report, label, frame)
  if frame then
    for _, key in ipairs({"leftBg", "centerBg", "rightBg", "mask"}) do
      if frame[key] then
        appendDebugRegion(report, "  "..key, frame[key])
      end
    end
  end
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

  local messageFrame = uiManager:GetVisibleSlidingMessageFrame(_G.SELECTED_CHAT_FRAME)
  if messageFrame then
    local overlay = messageFrame.overlay
    local editBox = messageFrame.layoutEditBox
    local alert = overlay and overlay.newMessageAlertFrame
    report[#report + 1] = "Background diagnostic: "..debugName(messageFrame.chatFrame)
    report[#report + 1] = "typing="..tostring(messageFrame.state.isTyping)..
      " editBoxVisible="..tostring(messageFrame.state.editBoxVisible)..
      " entryVisible="..tostring(editBox and editBox.glassyEntryVisible)..
      " scrollAtBottom="..tostring(messageFrame.state.scrollAtBottom)
    local profile = Core.db.profile
    report[#report + 1] = "editBoxAnchor="..tostring(profile.editBoxAnchor.position)..
      " y="..tostring(profile.editBoxAnchor.yOfs)..
      " fadeLeft="..tostring(profile.backgroundFadeLeftPercent)..
      " fadeRight="..tostring(profile.backgroundFadeRightPercent)
    for _, key in ipairs({"chatBackgroundColor", "unreadMessageBackgroundColor", "editBoxBackgroundColor", "unreadMessageSeparatorColor", "editBoxMessageSeparatorColor"}) do
      local color = profile[key] or {}
      report[#report + 1] = string.format("%s rgba=%s,%s,%s,%s", key, tostring(color.r), tostring(color.g), tostring(color.b), tostring(color.a))
    end
    appendDebugBackground(report, "Overlay", overlay)
    appendDebugBackground(report, "Unread background", overlay and overlay.snapToBottomFrame)
    appendDebugBackground(report, "Unread separator", alert and alert.bottomLine)
    appendDebugBackground(report, "Edit box", editBox)
    appendDebugBackground(report, "Edit box separator", editBox and editBox.messageSeparator)
    if editBox then
      appendDebugRegion(report, "Prat backdrop", editBox.pratFrame)
    end
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
  normalizeEditBox()
  normalizeCombatLogBar()
  normalizeTimestamps()
  normalizeAnimationEasings()
  if Core.db.profile.timestampsEnabled then
    disableBuiltinTimestamps()
  end

  -- General
  Core:Dispatch(UpdateConfig("font"))
  Core:Dispatch(UpdateConfig("tabFontSize"))
  Core:Dispatch(UpdateConfig("frameHeight"))
  Core:Dispatch(UpdateConfig("frameWidth"))
  Core:Dispatch(UpdateConfig("framePosition"))
  Core:Dispatch(UpdateConfig("textLeftPadding"))
  Core:Dispatch(UpdateConfig("tabTextColor"))
  Core:Dispatch(UpdateConfig("tabHighlightTextColor"))
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
  Core:Dispatch(UpdateConfig("chatAlwaysVisible"))
  Core:Dispatch(UpdateConfig("chatFadeInDuration"))
  Core:Dispatch(UpdateConfig("chatFadeOutDuration"))
  Core:Dispatch(UpdateConfig("scrollbackLines"))

  -- For things that don't update using the config frame e.g. frame position
  Core:Dispatch(RefreshConfig())
end
