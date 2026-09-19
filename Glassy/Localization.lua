local Core = unpack(select(2, ...))

local GetLocale = _G.GetLocale

Core.Locale = type(GetLocale) == "function" and GetLocale() or "enUS"

local english = {
  GENERAL = "General",
  ABOUT = "About",
  INFO = "Info",
  VERSION = "Version:",
  WHATS_NEW = "What’s new",
  WHATS_NEW_DESC = "Open a summary of new features, improvements, and important fixes.",
  OPEN_CONFIG = "Open settings",
  TOGGLE_MOVER = "Toggle the Glassy frame mover",
  OPEN_DEBUG = "Open a copyable layout debug report",
  OPEN_NEWS_COMMAND = "Open version history",
  COMMANDS = "Commands",
  REPORT_ISSUE = "Report an issue",
  LOCK_FRAME = "Lock frame",
  UNLOCK_FRAME = "Unlock frame",
  LOCK_FRAME_DESC = "Save the current position and hide the draggable Edit Mode overlay.",
  UNLOCK_FRAME_DESC = "Show the draggable Edit Mode overlay used to reposition the Glassy chat frame.",
  APPEARANCE = "Appearance",
  FONT = "Font",
  FONT_DESC = "Choose the font used for chat messages, tabs, Combat Log filters, and the edit box.\nDefault: ",
  FONT_OUTLINE = "Font outline",
  FONT_OUTLINE_DESC = "Choose whether Glassy text has an outline or a monochrome outline.\nDefault: None",
  LEFT_TEXT_PADDING = "Left text padding",
  LEFT_TEXT_PADDING_DESC = "Sets the space, in pixels, between the left edge and Glassy text. Applies to chat messages, tabs, Combat Log filters, and the edit box.\nDefault: ",
  ACTIVE_TAB_HIGHLIGHT = "Active tab highlight",
  ACTIVE_TAB_HIGHLIGHT_DESC = "Brightens the active chat tab. A value of 0 disables the highlight; 1 applies the strongest highlight.\nDefault: ",
  TAB_HOVER_HIGHLIGHT = "Tab hover highlight",
  TAB_HOVER_HIGHLIGHT_DESC = "Brightens a chat tab while the pointer is over it. A value of 0 disables the highlight; 1 applies the strongest highlight.\nDefault: ",
  CHAT_TAB_TOOLTIPS = "Chat tab tooltips",
  CHAT_TAB_TOOLTIPS_DESC = "Show interaction hints when hovering over chat tabs.\nDefault: off",
  TAB_MESSAGE_SEPARATOR = "Separator",
  TAB_MESSAGE_SEPARATOR_DESC = "Choose the separator color and opacity between chat tabs and messages. Set opacity to 0 to hide it.\nDefault: gold at 0% opacity.",
  TAB_MESSAGE_SPACING = "Vertical offset",
  TAB_MESSAGE_SPACING_DESC = "Moves messages down from the chat tabs.\nDefault: ",
  HEADER_BACKGROUND = "Header background",
  HEADER_BACKGROUND_DESC = "Choose the color and opacity behind the chat tabs and Combat Log filter bar.\nDefault: black at 40% opacity.",
  LEFT_FADE_DISTANCE = "Left fade distance",
  LEFT_FADE_DISTANCE_DESC = "Controls how gradually Glassy backgrounds fade at the left edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: ",
  RIGHT_FADE_DISTANCE = "Right fade distance",
  RIGHT_FADE_DISTANCE_DESC = "Controls how gradually Glassy backgrounds fade at the right edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: ",
  FRAME = "Frame",
  WIDTH = "Width",
  WIDTH_DESC = "Sets the width of the chat frame in pixels.\nDefault: ",
  HEIGHT = "Height",
  HEIGHT_DESC = "Sets the height of the chat frame in pixels.\nDefault: ",
  HORIZONTAL_OFFSET = "Horizontal offset",
  FRAME_HORIZONTAL_OFFSET_DESC = "Moves the chat frame horizontally from its selected screen anchor. Positive values move it right; negative values move it left.\nDefault: ",
  COMBAT_HORIZONTAL_OFFSET_DESC = "Moves the Combat Log filter bar horizontally from its docked position. Positive values move it right; negative values move it left.\nDefault: 0 px\nMin: -500\nMax: 500",
  VERTICAL_OFFSET = "Vertical offset",
  FRAME_VERTICAL_OFFSET_DESC = "Moves the chat frame vertically from its selected screen anchor. Positive values move it up; negative values move it down.\nDefault: ",
  EDIT_VERTICAL_OFFSET_DESC = "Moves the chat entry field vertically. Positive values move it up; negative values move it down.\nDefault: 5 above or -5 below\nMin: -9999\nMax: 9999",
  COMBAT_VERTICAL_OFFSET_DESC = "Moves the Combat Log filter bar vertically from its docked position. Positive values move it up; negative values move it down.\nDefault: 0 px\nMin: -500\nMax: 500",
  ANCHOR = "Anchor",
  ANCHOR_DESC = "Choose the screen corner used as the reference point for the horizontal and vertical offsets.\nDefault: ",
  TOP_LEFT = "Top left",
  TOP_RIGHT = "Top right",
  BOTTOM_LEFT = "Bottom left",
  BOTTOM_RIGHT = "Bottom right",
  NONE = "None",
  OUTLINE = "Outline",
  OUTLINE_MONOCHROME = "Outline Monochrome",
  ABOVE_TABS = "Above tabs",
  BELOW_TABS = "Below tabs",
  HIDDEN = "Hidden",
  LINEAR = "Linear",
  EASE_IN = "Ease in",
  EASE_OUT = "Ease out",
  EASE_IN_OUT = "Ease in/out",
  OVERSHOOT = "Overshoot",
  BOUNCE = "Bounce",
  ELASTIC = "Elastic",
  EDIT_BOX = "Edit box",
  FONT_SIZE = "Font size",
  EDIT_FONT_SIZE_DESC = "Sets the size of typed chat text and the chat-type label.\nDefault: ",
  EDIT_VERTICAL_PADDING = "Vertical padding",
  EDIT_VERTICAL_PADDING_DESC = "Adds space above and below typed text as a fraction of the line height.\nDefault: ",
  MESSAGE_FONT_SIZE_DESC = "Sets the font size of chat messages.\nDefault: ",
  BACKGROUND = "Background",
  EDIT_BACKGROUND_DESC = "Choose the color and opacity behind the chat entry field.\nDefault: black at 40% opacity.",
  EDIT_BOX_MESSAGE_SEPARATOR = "Separator",
  EDIT_BOX_MESSAGE_SEPARATOR_DESC = "Choose the separator color and opacity between the chat entry field and messages. Set opacity to 0 to hide it.\nDefault: gold at 0% opacity.",
  CHAT_BACKGROUND_DESC = "Choose the color and opacity behind chat messages and the scroll overlay.\nDefault: black at 40% opacity.",
  UNREAD_MESSAGE_SEPARATOR = "Unread-message separator",
  UNREAD_MESSAGE_SEPARATOR_DESC = "Choose the separator color and opacity below the unread-message control. Set opacity to 0 to hide it.\nDefault: gold at 65% opacity.",
  UNREAD_MESSAGE_BACKGROUND = "Unread-message background",
  UNREAD_MESSAGE_BACKGROUND_DESC = "Choose the background color and opacity behind the jump-to-latest row, with or without unread messages.\nDefault: black at 40% opacity.",
  BACKGROUND_EASING = "Background easing",
  BACKGROUND_EASING_DESC = "Controls how the edit-box background fades when chat opens or closes.\nDefault: ",
  PLACEMENT = "Placement",
  ATTACH = "Attach",
  ATTACH_DESC = "Place the chat entry field above or below the main chat frame.\nDefault: Below",
  ABOVE_CHAT = "Above chat",
  BELOW_CHAT = "Below chat",
  DYNAMIC_MESSAGE_AREA = "Dynamic message area",
  DYNAMIC_MESSAGE_AREA_DESC = "Uses the chat entry field's space for messages while the field is closed. Opening chat moves messages up and restores the entry field. This applies when the field is attached below the chat; disable it to keep the message area static.\nDefault: Enabled",
  MOVEMENT_EASING = "Movement easing",
  EDIT_MOVEMENT_EASING_DESC = "Controls how messages move when the dynamic chat entry field opens or closes.\nDefault: ",
  MESSAGE_MOVEMENT_EASING_DESC = "Controls how messages accelerate and decelerate while sliding upward.\nDefault: ",
  SHORTCUTS = "Shortcuts",
  WHILE_TYPING = "While typing",
  SENT_MESSAGE_HISTORY = "Sent-message history",
  WOW_KEYBINDINGS = "WoW keybindings while typing",
  COPYING_CHAT = "Copying chat",
  MOVE_CURSOR = "Move the cursor.",
  JUMP_BEGIN_END = "Jump to the beginning / end.",
  MOVE_BY_WORD = "Move by word.",
  JUMP_END = "Jump to the end.",
  DELETE_PREVIOUS_WORD = "Delete the previous word.",
  DELETE_TO_BEGINNING = "Delete from the cursor to the beginning.",
  DELETE_TO_END = "Delete from the cursor to the end.",
  INSERT_REMOVED_TEXT = "Insert the text last removed by Ctrl+U or Ctrl+K.",
  EDIT_CLIPBOARD = "Select all / copy / cut / paste.",
  LOCKDOWN_SHORTCUTS = "Ctrl+U, K and Y are unavailable during Blizzard's chat messaging lockdown.",
  BROWSE_HISTORY = "Browse older / newer sent messages and commands.",
  USE_WOW_KEYBINDING = "Use your WoW keybinding. Release Alt to resume typing.",
  INSERT_LINK = "Insert its link while chat is active.",
  COPY_TAB = "Open that tab's chat history for copying. Press Ctrl+C to copy it to the clipboard.",
  MESSAGES = "Messages",
  WRAPPED_LINE_SPACING = "Wrapped line spacing",
  WRAPPED_LINE_SPACING_DESC = "Extra vertical space, in pixels, between wrapped lines within the same chat message.\nDefault: ",
  MESSAGE_PADDING = "Message padding",
  MESSAGE_PADDING_DESC = "Adds vertical padding above and below each message as a fraction of the line height. For example, 0.25 adds one-quarter of a line on each side.\nDefault: ",
  INLINE_ICON_OFFSET = "Inline icon offset",
  INLINE_ICON_OFFSET_DESC = "Adjusts the vertical alignment of icons embedded in chat text.\nDefault: ",
  EMOJI_SHORTCODES = "Emoji shortcodes",
  EMOJI_SHORTCODES_DESC = "Show codes such as :smile: with ElvUI's emoji textures. Chat still sends the original text.\nDefault: enabled",
  VISIBILITY = "Visibility",
  FADE_OUT_DELAY = "Fade out delay",
  FADE_OUT_DELAY_DESC = "How many seconds Glassy waits after a message arrives before starting its fade out.\nDefault: ",
  SHOW_ON_MOUSE_OVER = "Show on mouse over",
  SHOW_ON_MOUSE_OVER_DESC = "Show faded chat messages again while the pointer is over the chat frame.\nDefault: on",
  SHOW_WHILE_TYPING = "Show while typing",
  SHOW_WHILE_TYPING_DESC = "Reveal faded chat messages while the chat input is open.\nDefault: off",
  FADING = "Fading",
  FADE_IN_DURATION = "Fade in duration",
  FADE_IN_DURATION_DESC = "How many seconds new messages and the chat header take to become fully visible. Set to 0 to show them instantly.\nDefault: ",
  FADE_OUT_DURATION = "Fade out duration",
  FADE_OUT_DURATION_DESC = "How many seconds messages and the chat header take to disappear after the fade-out delay. Set to 0 to hide them instantly.\nDefault: ",
  FADE_EASING = "Fade easing",
  FADE_EASING_DESC = "Controls how message and chat-header opacity accelerates and decelerates while fading in and out.\nDefault: ",
  MOVEMENT = "Movement",
  MOVEMENT_DURATION = "Movement duration",
  MOVEMENT_DURATION_DESC = "How many seconds existing messages take to move upward when new text arrives. Set to 0 to disable movement.\nDefault: ",
  PREVIEW_ANIMATIONS = "Preview animations",
  PREVIEW_ANIMATIONS_DESC = "Add a temporary preview message to the selected Glassy tab and play the current movement and fade settings. If necessary, the preview returns that tab to its newest messages.",
  BEHAVIOR = "Behavior",
  INDENT_LINE_WRAP = "Indent on line wrap",
  INDENT_LINE_WRAP_DESC = "Indent continuation lines when a chat message wraps.\nDefault: on",
  MOUSE_OVER_TOOLTIPS = "Mouse over tooltips",
  MOUSE_OVER_TOOLTIPS_DESC = "Show the standard game tooltip when hovering over supported links in chat.\nDefault: on",
  MESSAGE_BLACKLIST = "Message blacklist",
  MESSAGE_BLACKLIST_DESC = "Hide chat messages containing any blocked phrase.\nDefault: off",
  BLOCKED_PHRASES = "Blocked phrases",
  BLOCKED_PHRASES_DESC = "Enter one plain-text phrase per line. Matching ignores letter case and repeated whitespace.",
  HISTORY = "History",
  SCROLLBACK_LINES = "Scrollback lines",
  SCROLLBACK_LINES_DESC = "Number of recent messages retained in each chat tab for copying. Glassy keeps up to 128 rendered messages for on-screen scrolling.\nDefault: ",
  TIMESTAMPS = "Timestamps",
  SETTINGS = "Settings",
  SHOW_TIMESTAMPS = "Show timestamps",
  SHOW_TIMESTAMPS_DESC = "Adds Glassy-owned timestamps to new and retained chat messages. Enabling this turns off WoW's built-in timestamps to prevent duplicates.\nDefault: Disabled",
  FORMAT = "Format",
  FORMAT_DESC = "Choose the time format used before each message.\nDefault: [23:59:59]",
  OVERRIDE_COLOR = "Override color",
  OVERRIDE_COLOR_DESC = "Apply the selected color to timestamps. Disable this to add no timestamp color code, allowing the chat line's existing color to apply.\nDefault: Enabled",
  COLOR = "Color",
  COLOR_DESC = "Choose the timestamp text color used when Override color is enabled.\nDefault: gray",
  CHAT_WINDOWS = "Chat windows",
  CHAT_WINDOWS_DESC = "Choose which chat windows receive Glassy timestamps.",
  COMBAT_LOG = "Combat Log",
  SHOW_COMBAT_LOG = "Show Combat Log",
  SHOW_COMBAT_LOG_DESC = "Show the Combat Log tab and its Glassy renderer. When hidden, combat events continue to be retained in the background so recent history returns when you show it again.\nDefault: Enabled",
  FILTER_BAR = "Filter bar",
  POSITION = "Position",
  FILTER_BAR_POSITION_DESC = "Places the Combat Log filter bar above or below the main Glassy tabs, or hides it. The bar appears only while the Combat Log tab is selected.\nDefault: Below tabs",
  COMPATIBILITY = "Compatibility",
  PRAT_BOUNDARY = "Glassy owns its renderer, tabs, edit box, scrolling, history, timestamps, copying, and tooltips. Prat remains optional and may format message content before Glassy receives it.",
  SUPPORTED_PRAT_FEATURES = "Supported Prat features",
  PRAT_UI_MODULES = "Prat UI modules",
  PRAT_TIMESTAMPS = "Prat Timestamps",
  PRAT_HISTORY = "Prat History",
  ELVUI_EMOJIS = "ElvUI emojis",
  ELVUI_EMOJIS_DESC = "Uses ElvUI's emoji textures when ElvUI is available.",
  PLAYER_CHANNEL_FORMATTING = "Player and channel name formatting",
  SUBSTITUTIONS_FILTERS = "Text substitutions, filters, and highlights",
  URL_INVITE_LINKS = "URL and invite links",
  LINK_FEATURES = "Link icons, sounds, and popups",
  CHANNEL_COLOR_MEMORY = "Channel color memory",
  PRAT_MODULE_GUIDANCE = "Glassy replaces the native-frame behavior of these modules. Keep them disabled:",
  NOT_DETECTED_PRAT = "Not detected. Glassy is fully functional without Prat.",
  NOT_DETECTED_ELVUI = "Not detected: ElvUI.",
  DETECTED = "Detected:",
  NO_COMPAT_WARNINGS = "No compatibility warnings.",
  NO_CONFLICTING_PRAT = "No conflicting Prat UI modules are enabled.",
  ENABLED_PRAT_MODULES = "Enabled Prat UI modules that Glassy replaces:",
  PRAT_TIMESTAMPS_DISABLED = "Prat Timestamps is disabled. Glassy can add timestamps itself.",
  PRAT_TIMESTAMPS_ENABLED = "Prat Timestamps is enabled. Glassy does not use it for live rendering. Disable it and use Glassy timestamps to prevent Prat from embedding timestamps in retained native history.",
  RESTORED_PRAT_HISTORY = "Restored Prat history is displayed by Glassy.",
  SCROLLBACK_CONTROLS_HISTORY = "Glassy's Scrollback lines setting controls the retained line limit.",
  PRAT_LINES_UNUSED = "Prat's Set Chat Lines value is intentionally not used.",
  CLICK_SELECT = "Click to select",
  DRAG_REORDER = "Drag to reorder",
  SHIFT_CLICK_COPY = "Shift-click to copy",
  RIGHT_CLICK_OPTIONS = "Right-click for chat options",
  JUMP_LATEST = "Jump to latest message",
  UNREAD_MESSAGES = "Unread messages",
  MOVER_DESC = "Chat frame unlocked. You can now drag the chat frame to reposition it.",
  LOCK = "Lock",
  PRESS_COPY = "Press Ctrl+C to copy, then close this window.",
  ALL_TEXT_SELECTED = "All text is selected",
  COPY_CHAT_TITLE = "Glassy: Copy chat — ",
  DEBUG_TITLE = "Glassy: Debug report",
  VERSION_HISTORY_TITLE = "Glassy: Version history",
  CHAT = "Chat",
  COPY_LIMIT = "The newest chat message exceeds Glassy's 60,000-character copy limit.",
  NOTHING_TO_COPY = "This chat tab has no messages to copy.",
}

local translations = {}
local replacements = {}
local sourceToId = {}

for id, source in pairs(english) do
  sourceToId[source] = id
end

local function rebuildReplacements()
  replacements = {}
  for id, translated in pairs(translations) do
    local source = english[id]
    if source and source ~= translated then
      replacements[#replacements + 1] = {source, translated}
    end
  end
  table.sort(replacements, function(left, right)
    return #left[1] > #right[1]
  end)
end

function Core:RegisterTranslations(locale, values)
  if locale ~= Core.Locale then
    return
  end

  for id, value in pairs(values) do
    if english[id] and type(value) == "string" and value ~= "" then
      translations[id] = value
    end
  end
  rebuildReplacements()
end

-- Locale files can provide concise labels and override only descriptions that
-- need more detail.  Every remaining description is still localized instead
-- of silently falling back to English.
function Core:RegisterCompactTranslations(locale, values, describe)
  if locale ~= Core.Locale then
    return
  end

  for id in pairs(english) do
    if values[id] == nil and string.sub(id, -5) == "_DESC" then
      local label = values[string.sub(id, 1, -6)]
      values[id] = describe(label)
    end
  end

  self:RegisterTranslations(locale, values)
end

local function replacePlain(text, source, replacement)
  local output = {}
  local start = 1
  while true do
    local first, last = string.find(text, source, start, true)
    if first == nil then
      output[#output + 1] = string.sub(text, start)
      break
    end
    output[#output + 1] = string.sub(text, start, first - 1)
    output[#output + 1] = replacement
    start = last + 1
  end
  return table.concat(output)
end

function Core:Localize(text)
  if type(text) ~= "string" or text == "" then
    return text
  end

  local exactId = sourceToId[text]
  if exactId then
    return translations[exactId] or text
  end

  local localized = text
  for _, pair in ipairs(replacements) do
    localized = replacePlain(localized, pair[1], pair[2])
  end
  return localized
end

function Core:GetLocalizationCoverage()
  local total = 0
  local translated = 0
  for id in pairs(english) do
    total = total + 1
    if translations[id] then
      translated = translated + 1
    end
  end
  return translated, total
end

function Core:LocalizeOptions(options)
  local visited = {}

  local function localizeFunction(callback)
    return function(...)
      return Core:Localize(callback(...))
    end
  end

  local function localizeNode(node)
    if type(node) ~= "table" or visited[node] then
      return
    end
    visited[node] = true

    for _, field in ipairs({"name", "desc"}) do
      local value = node[field]
      if type(value) == "string" then
        node[field] = Core:Localize(value)
      elseif type(value) == "function" then
        node[field] = localizeFunction(value)
      end
    end

    if type(node.args) == "table" then
      for _, child in pairs(node.args) do
        localizeNode(child)
      end
    end
  end

  localizeNode(options)
end
