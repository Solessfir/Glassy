local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")
local L = function(text) return Core:Localize(text) end

local LSM = Core.Libs.LSM
local SettingsValues = C.SettingsValues

local MAX_TAB_MESSAGE_OFFSET = SettingsValues.maxTabMessageOffset
local MIN_FRAME_HEIGHT = SettingsValues.minFrameHeight
local MAX_TEXT_LEFT_PADDING = SettingsValues.maxTextLeftPadding
local MAX_EDIT_BOX_VERTICAL_PADDING = SettingsValues.maxEditBoxVerticalPadding

local UpdateConfig = Constants.ACTIONS.UpdateConfig

local isMoverUnlocked = C.IsMoverUnlocked
local toggleMover = C.ToggleMover

local ANCHORS = SettingsValues.anchors
local FLAGS = SettingsValues.fontFlags
local EASING_VALUES = SettingsValues.easingValues
local EASING_SORTING = SettingsValues.easingSorting

local function profileOption(key, option, updateKey)
  option.get = function () return Core.db.profile[key] end
  option.set = function (_, value)
    Core.db.profile[key] = value
    Core:Dispatch(UpdateConfig(updateKey or key))
  end
  return option
end

function C:SetCommandHistoryEnabled(enabled)
  Core.db.profile.saveCommandHistory = enabled
  if not enabled then Core.db.char.commandHistory = nil end
end

function C.CreateFontOption(setting, order)
  local inheritedFont = L("Use UI font")
  return {
    name = "Font",
    type = "select",
    order = order,
    dialogControl = "LSM30_Font",
    values = function ()
      local fonts = {}
      for name, path in pairs(LSM:HashTable("font")) do fonts[name] = path end
      fonts[inheritedFont] = LSM:Fetch("font", Core.db.profile.font)
      return fonts
    end,
    get = function ()
      local selected = Core.db.profile[setting]
      return selected and selected ~= "" and LSM:HashTable("font")[selected] and selected or inheritedFont
    end,
    set = function (_, input)
      Core.db.profile[setting] = input == inheritedFont and "" or input
      Core:Dispatch(UpdateConfig("font"))
    end,
  }
end

function C.CreateFontOutlineOption(setting, order)
  return {
    name = "Font outline",
    type = "select",
    order = order,
    values = FLAGS,
    get = function ()
      local flags = Core.db.profile[setting]
      return flags and flags ~= "INHERIT" and flags or ""
    end,
    set = function (_, input)
      Core.db.profile[setting] = input
      Core:Dispatch(UpdateConfig("font"))
    end,
  }
end

local function getGeneralOptions()
  return {
    name = "General",
    type = "group",
    order = 1,
    args = {
      section3 = {
        name = "Frame",
        type = "group",
        inline = true,
        order = 1,
        args = {
          frameWidth = {
            name = "Width",
            desc = "Sets the width of the chat frame in pixels.\nDefault: "..Core.defaults.profile.frameWidth..
              "\nMin: 100\nMax: 9999",
            type = "range",
            order = 1,
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
            order = 2,
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
          frameAnchor = {
            name = "Anchor",
            desc = "Choose the screen corner used as the reference point for the horizontal and vertical offsets.\nDefault: "..
              ANCHORS[Core.defaults.profile.positionAnchor.point],
            type = "select",
            order = 3,
            values = ANCHORS,
            get = function ()
              return Core.db.profile.positionAnchor.point
            end,
            set = function (_, input)
              Core.db.profile.positionAnchor.point = input
              Core:Dispatch(UpdateConfig("framePosition"))
            end
          },
          frameXOfs = {
            name = "Horizontal offset",
            desc = "Moves the chat frame horizontally from its selected screen anchor. Positive values move it right; negative values move it left.\nDefault: "..
              Core.defaults.profile.positionAnchor.xOfs.."\nMin: -9999\nMax: 9999",
            type = "range",
            order = 4,
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
            order = 5,
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
            order = 6,
          },
          blizzardEditMode = profileOption("blizzardEditMode", {
            name = "Blizzard Edit Mode",
            desc = "Move chat, notifications, and voice indicators and adjust chat settings in the game's Edit Mode.",
            type = "toggle",
            order = 7,
            hidden = function () return not _G.EditModeManagerFrame end,
          }),
        },
      },
      section2 = {
        name = "Shared appearance",
        type = "group",
        inline = true,
        order = 2,
        args = {
          tabHighlightTextColor = {
            name = "Hover label color",
            desc = L("Tabs")..", "..L("Combat Log")..", "..L("Unread messages")..", "..L("Jump to latest"),
            type = "color",
            hasAlpha = true,
            order = 2,
            get = function ()
              local color = Core:GetThemeColor("tabHighlightTextColor")
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.tabHighlightTextColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("tabHighlightTextColor"))
            end,
          },
          tabTextColor = {
            name = "Label color",
            desc = L("Tabs")..", "..L("Combat Log")..", "..L("Unread messages")..", "..L("Jump to latest"),
            type = "color",
            hasAlpha = true,
            order = 1,
            get = function ()
              local color = Core:GetThemeColor("tabTextColor")
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.tabTextColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("tabTextColor"))
            end,
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
          backgroundFadeLeftPercent = {
            name = "Left fade percent",
            desc = "Controls how gradually Glassy backgrounds fade at the left edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: "..
              string.format("%.2f", Core.defaults.profile.backgroundFadeLeftPercent).."%\nMin: 0%\nMax: 100%",
            type = "range",
            order = 3.9,
            min = 0,
            max = 100,
            softMin = 0,
            softMax = 100,
            step = 1,
            get = function ()
              return Core.db.profile.backgroundFadeLeftPercent
            end,
            set = function (_, input)
              Core.db.profile.backgroundFadeLeftPercent = input
              Core:Dispatch(UpdateConfig("backgroundFade"))
            end,
          },
          backgroundFadeRightPercent = {
            name = "Right fade percent",
            desc = "Controls how gradually Glassy backgrounds fade at the right edge. Shorter distances create a sharper fade; 0 disables it.\nDefault: "..
              string.format("%.2f", Core.defaults.profile.backgroundFadeRightPercent).."%\nMin: 0%\nMax: 100%",
            type = "range",
            order = 4,
            min = 0,
            max = 100,
            softMin = 0,
            softMax = 100,
            step = 1,
            get = function ()
              return Core.db.profile.backgroundFadeRightPercent
            end,
            set = function (_, input)
              Core.db.profile.backgroundFadeRightPercent = input
              Core:Dispatch(UpdateConfig("backgroundFade"))
            end,
          },
        },
      },
      notifications = {
        name = "Notifications", type = "group", inline = true, order = 3,
        args = {
          notificationStyle = profileOption("notificationStyle", {
            name = "Style Battle.net notifications", type = "toggle", order = 1,
            desc = "Use Glassy's background and font for Battle.net notifications. Turn off to restore Blizzard's appearance.",
          }),
          alertStyle = profileOption("alertStyle", {
            name = "Style game alerts", type = "toggle", order = 2,
            desc = "Use Glassy's background and font for achievement, loot, and other game alerts. Turn off to restore Blizzard's appearance.",
          }),
        },
      },
    }
  }
end

local function getTabOptions()
  local presets = Core:GetModule("TabPresets"):GetOptions()
  presets.order = 2
  local function whisperOption(key, name, desc, order, disabled)
    return {
      name = name,
      desc = desc,
      type = "toggle",
      order = order,
      disabled = disabled,
      get = function () return Core.db.profile[key] end,
      set = function (_, enabled)
        Core.db.profile[key] = enabled
        Core:Dispatch(UpdateConfig(key))
      end,
    }
  end

  local function chatButtonsDisabled()
    return not Core.db.profile.chatButtons
  end

  local function hoverColorOption(key, name, order, getColor, disabled)
    return {
      name = name,
      desc = "Set the highlight color and opacity. Uses the tab hover label color by default.",
      type = "color",
      hasAlpha = true,
      order = order,
      disabled = disabled,
      get = function ()
        local color = getColor()
        return color.r, color.g, color.b, color.a or 1
      end,
      set = function (_, r, g, b, a)
        Core.db.profile[key] = {r = r, g = g, b = b, a = a}
        Core:Dispatch(UpdateConfig(key))
      end,
    }
  end

  return {
    name = "Tabs",
    type = "group",
    order = 1.5,
    args = {
      layout = {
        name = "Layout",
        type = "group",
        inline = true,
        order = 1,
        args = {
          tabBarPosition = profileOption("tabBarPosition", {
            name = "Tab bar position", type = "select", order = 1,
            values = {top = L("Above chat"), bottom = L("Below chat")},
            sorting = {"top", "bottom"},
          }),
          tabBarAlignment = profileOption("tabBarAlignment", {
            name = "Tab alignment", type = "select", order = 2,
            values = {left = L("Left"), center = L("Center"), right = L("Right")},
            sorting = {"left", "center", "right"},
          }),
          tabMessageSpacing = {
            name = "Gap from messages",
            desc = "Adds space between the tab bar and the messages.\nDefault: "..
              Core.defaults.profile.tabMessageSpacing.." px\nMin: 0\nMax: "..MAX_TAB_MESSAGE_OFFSET,
            type = "range",
            order = 3,
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
        },
      },
      presets = presets,
      appearance = {
        name = "Appearance",
        type = "group",
        inline = true,
        order = 3,
        args = {
          tabStyle = {
            name = "Tab style",
            desc = "Choose the appearance of the chat tabs.",
            type = "select",
            order = 0.5,
            values = {
              minimal = L("Minimal"), framed = L("Framed"), solid = L("Solid"),
              underline = L("Underline"), pill = L("Pill"), glossy = L("Glossy"), classic = L("Classic"),
            },
            sorting = {"minimal", "framed", "solid", "underline", "pill", "glossy", "classic"},
            get = function () return Core.db.profile.tabStyle end,
            set = function (_, style)
              Core.db.profile.tabStyle = style
              Core:Dispatch(UpdateConfig("tabStyle"))
            end,
          },
          tabSelectionAnimation = {
            name = "Selected tab animation",
            desc = "Slide the highlight from the previous tab or grow it from the center of the newly selected tab.",
            type = "select",
            order = 0.6,
            values = {none = L("Off"), slide = L("Slide"), grow = L("Grow")},
            sorting = {"none", "slide", "grow"},
            disabled = function () return Core.db.profile.tabStyle == "classic" end,
            get = function () return Core.db.profile.tabSelectionAnimation end,
            set = function (_, animation)
              Core.db.profile.tabSelectionAnimation = animation
              Core:Dispatch(UpdateConfig("tabSelectionAnimation"))
            end,
          },
          tabAccentClassColor = profileOption("tabAccentClassColor", {
            name = "Class color accent",
            desc = "Use your character's class color for the selected tab accent.",
            type = "toggle",
            order = 0.7,
            disabled = function () return Core.db.profile.tabStyle == "classic" end,
          }, "tabHighlightTextColor"),
          tabFont = C.CreateFontOption("tabFont", 1),
          tabFontSize = {
            name = "Font size",
            type = "range",
            order = 1.005,
            min = 1,
            max = 100,
            softMin = 6,
            softMax = 24,
            step = 1,
            get = function ()
              return Core.db.profile.tabFontSize
            end,
            set = function (_, input)
              Core.db.profile.tabFontSize = input
              Core:Dispatch(UpdateConfig("tabFontSize"))
            end,
          },
          tabFontFlags = C.CreateFontOutlineOption("tabFontFlags", 1.002),
          headerBackgroundColor = {
            name = "Background",
            desc = "Choose the color and opacity behind the chat tabs and Combat Log filter bar.\nDefault: black at 50% opacity.",
            type = "color",
            hasAlpha = true,
            order = 1.4,
            get = function ()
              local color = Core.db.profile.headerBackgroundColor
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.headerBackgroundColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("headerBackgroundColor"))
            end,
          },
          tabMessageSeparatorColor = {
            name = "Separator",
            desc = "Choose the separator color and opacity between chat tabs and messages. Set opacity to 0 to hide it.\nDefault: gold at 0% opacity.",
            type = "color",
            hasAlpha = true,
            order = 1.5,
            get = function ()
              local color = Core:GetThemeColor("tabMessageSeparatorColor")
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.tabMessageSeparatorColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("tabMessageSeparatorColor"))
            end,
          },
        },
      },
      behavior = {
        name = "Tab behavior",
        type = "group",
        inline = true,
        order = 4,
        args = {
          tabUnreadCount = {
            name = "Unread count",
            desc = "Show how many messages arrived in a docked tab since you last viewed it.\nDefault: off",
            type = "toggle",
            order = 1,
            get = function ()
              return Core.db.profile.tabUnreadCount
            end,
            set = function (_, input)
              Core.db.profile.tabUnreadCount = input
              Core:Dispatch(UpdateConfig("tabUnreadCount"))
            end,
          },
          chatTabTooltips = {
            name = "Tooltips",
            desc = "Show interaction hints when hovering over chat tabs.\nDefault: off",
            type = "toggle",
            order = 2,
            get = function ()
              return Core.db.profile.chatTabTooltips
            end,
            set = function (_, input)
              Core.db.profile.chatTabTooltips = input
              Core:Dispatch(UpdateConfig("chatTabTooltips"))
            end,
          },
        },
      },
      whispers = {
        name = "Whispers",
        type = "group",
        inline = true,
        order = 5,
        args = {
          dedicatedWhisperWindows = whisperOption("dedicatedWhisperWindows", "Dedicated whisper windows",
            "Read and reply to character and Battle.net whispers in a separate inbox. Restricted messages stay in game chat. Default: off.", 1),
          whisperWindowsAutoOpen = whisperOption("whisperWindowsAutoOpen", "Open on incoming whisper",
            "Open a conversation for a new whisper without focusing the reply box. Default: off.", 2,
            function () return not Core.db.profile.dedicatedWhisperWindows end),
          whisperWindowsSound = whisperOption("whisperWindowsSound", "Whisper notification sound",
            "Play an extra notification sound for incoming dedicated whispers. Default: off.", 3,
            function () return not Core.db.profile.dedicatedWhisperWindows end),
          whisperWindowsBubbles = whisperOption("whisperWindowsBubbles", "Whisper message bubbles",
            "Show incoming and outgoing messages in separate left and right bubbles. Default: off.", 4,
            function () return not Core.db.profile.dedicatedWhisperWindows end),
          whisperInboxColor = {
            name = "Inbox button color",
            desc = "Set the whisper inbox icon and unread count color and opacity. Uses the tab label color by default.",
            type = "color",
            hasAlpha = true,
            order = 4.5,
            disabled = function () return not Core.db.profile.dedicatedWhisperWindows end,
            get = function ()
              local color = Core:GetWhisperInboxColor()
              return color.r, color.g, color.b, color.a or 1
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.whisperInboxColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("whisperInboxColor"))
            end,
          },
          whisperInboxHoverColor = hoverColorOption("whisperInboxHoverColor", "Inbox button hover color", 4.75,
            function () return Core:GetWhisperInboxColor(true) end,
            function () return not Core.db.profile.dedicatedWhisperWindows end),
          keepWhisperTabs = whisperOption("keepWhisperTabs", "Keep whisper tabs",
            "Reopen character whisper tabs with their last 100 messages after a reload or login. Applies when dedicated windows are off. Default: on.", 5,
            function () return Core.db.profile.dedicatedWhisperWindows end),
        },
      },
      chatButtons = {
        name = "Chat buttons",
        type = "group",
        inline = true,
        order = 7,
        args = {
          chatButtons = profileOption("chatButtons", {
            name = "Show chat buttons",
            desc = "Show the game's Social, Channels, Voice, and chat menu buttons alongside the tabs where the client provides them.",
            type = "toggle",
            order = 1,
          }),
          chatButtonsStyle = profileOption("chatButtonsStyle", {
            name = "Button style",
            desc = "Choose Glassy's styling or the game's artwork. Default: Glassy.",
            type = "select",
            order = 2,
            values = {blizzard = L("Blizzard"), glassy = L("Glassy")},
            sorting = {"blizzard", "glassy"},
            disabled = chatButtonsDisabled,
          }),
          chatButtonsColor = {
            name = "Button color",
            desc = "Set the Glassy buttons' color and opacity. Uses the tab label color by default.",
            type = "color",
            hasAlpha = true,
            order = 2.25,
            disabled = function ()
              return chatButtonsDisabled() or Core.db.profile.chatButtonsStyle ~= "glassy"
            end,
            get = function ()
              local color = Core:GetChatButtonColor()
              return color.r, color.g, color.b, color.a or 1
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.chatButtonsColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("chatButtonsColor"))
            end,
          },
          chatButtonsHoverColor = hoverColorOption("chatButtonsHoverColor", "Button hover color", 2.4,
            function () return Core:GetChatButtonColor(true) end,
            function () return chatButtonsDisabled() or Core.db.profile.chatButtonsStyle ~= "glassy" end),
          chatButtonsSide = profileOption("chatButtonsSide", {
            name = "Button position",
            type = "select",
            order = 3,
            values = {left = L("Left"), right = L("Right"), topleft = L("Top left"), topright = L("Top right"),
              bottomleft = L("Bottom left"), bottomright = L("Bottom right")},
            sorting = {"left", "right", "topleft", "topright", "bottomleft", "bottomright"},
            disabled = chatButtonsDisabled,
          }),
          chatButtonsOffsetX = profileOption("chatButtonsOffsetX", {
            name = "Horizontal offset", type = "range", order = 4, min = -50, max = 50, step = 1,
            disabled = chatButtonsDisabled,
          }),
          chatButtonsOffsetY = profileOption("chatButtonsOffsetY", {
            name = "Vertical offset", type = "range", order = 5, min = -50, max = 50, step = 1,
            disabled = chatButtonsDisabled,
          }),
        },
      },
    },
  }
end

local selectedAlias = ""

local function getAliasNames()
  local names = {}
  for name, expansion in pairs(Core.db.global.slashAliases) do
    if type(name) == "string" and name:match("^[%w_%-]+$") and type(expansion) == "string" then
      names[#names + 1] = name
    end
  end
  table.sort(names)
  return names
end

local function getSelectedAlias()
  local aliases = Core.db.global.slashAliases
  if type(aliases[selectedAlias]) ~= "string" then selectedAlias = "" end
  return selectedAlias
end

local function getEditBoxOptions()
  return {
    name = "Edit box",
    type = "group",
    order = 3,
    args = {
      section1 = {
        name = "Appearance",
        type = "group",
        inline = true,
        order = 1,
        args = {
          editBoxStyle = profileOption("editBoxStyle", {
            name = "Style", type = "select", order = 0.5,
            desc = "Choose a plain background, faded edges with a chat-colored line, or a rounded chat-colored border.",
            values = {solid = L("Solid"), minimal = L("Minimal"), framed = L("Framed")},
            sorting = {"solid", "minimal", "framed"},
          }),
          editBoxFont = C.CreateFontOption("editBoxFont", 1),
          editBoxFontFlags = C.CreateFontOutlineOption("editBoxFontFlags", 1.05),
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
            desc = "Choose the color and opacity behind the chat entry field.\nDefault: black at 50% opacity.",
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
              local color = Core:GetThemeColor("editBoxMessageSeparatorColor")
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.editBoxMessageSeparatorColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("editBoxMessageSeparatorColor"))
            end,
          },
        },
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
              Core.db.profile.editBoxAnchor.yOfs = Core.defaults.profile.editBoxAnchor.yOfs
              Core:Dispatch(UpdateConfig("editBoxAnchor"))
            end
          },
          editBoxAnchorYOfs = {
            name = "Vertical offset",
            desc = "Moves the chat entry field vertically. Positive values move it up; negative values move it down.\nDefault: -2\nMin: -9999\nMax: 9999",
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
        },
      },
      typing = {
        name = "Typing",
        type = "group",
        inline = true,
        order = 3,
        args = {
          completePlayerNames = profileOption("completePlayerNames", {
            name = "Complete player names with Tab",
            desc = "Complete a unique player name from recent chat.",
            type = "toggle",
            order = 1,
            disabled = function () return Core:IsPratModuleEnabled("PlayerNames") end,
          }, "messageFormatting"),
          emotePickerEnabled = profileOption("emotePickerEnabled", {
            name = "Emote picker", type = "toggle", order = 2,
            desc = "Add a button that inserts Twemoji codes in the edit box. Enable emotes under Messages first.",
            disabled = function () return not Core.db.profile.emojisEnabled end,
          }),
          saveCommandHistory = {
            name = "Save slash-command history",
            desc = function ()
              if Core:IsPratModuleEnabled("History", "savehistory") then return "Prat currently saves slash-command history." end
              return "Keep up to 32 recent slash commands for this character. Recall them with Alt+Up or Alt+Down. Turning this off clears saved commands."
            end,
            type = "toggle",
            order = 3,
            disabled = function ()
              return not _G.IsSecureCmd or Core:IsPratModuleEnabled("History", "savehistory")
            end,
            get = function () return Core.db.profile.saveCommandHistory end,
            set = function (_, enabled) C:SetCommandHistoryEnabled(enabled) end,
          },
        },
      },
      behavior = {
        name = "Behavior",
        type = "group",
        inline = true,
        order = 4,
        args = {
          slashAliasesEnabled = {
            name = "Slash aliases",
            desc = "Use shortcuts for slash commands. Turning this off keeps your saved shortcuts.",
            type = "toggle",
            order = 1,
            get = function () return Core.db.profile.slashAliasesEnabled end,
            set = function (_, enabled)
              Core.db.profile.slashAliasesEnabled = enabled
              Core:Dispatch(UpdateConfig("slashAliasesEnabled"))
            end,
          },
          savedAlias = {
            name = "Saved aliases",
            type = "select",
            style = "radio",
            order = 2,
            width = "full",
            hidden = function () return #getAliasNames() == 0 end,
            values = function ()
              local values = {[""] = L("New alias")}
              for _, name in ipairs(getAliasNames()) do
                values[name] = "/"..name.." -> "..Core.db.global.slashAliases[name]:gsub("|", "||")
              end
              return values
            end,
            sorting = function ()
              local names = getAliasNames()
              table.insert(names, 1, "")
              return names
            end,
            get = getSelectedAlias,
            set = function (_, name)
              if name ~= "" and type(Core.db.global.slashAliases[name]) ~= "string" then return end
              selectedAlias = name
              Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
            end,
          },
          aliasEmpty = {
            name = "No aliases saved.",
            type = "description",
            order = 2.1,
            width = "full",
            hidden = function () return #getAliasNames() ~= 0 end,
          },
          aliasExample = {
            name = "Format: /shortcut = /command. Example: /rld = /reload",
            type = "description",
            order = 2.5,
            width = "full",
            hidden = function () return getSelectedAlias() ~= "" end,
          },
          aliasDefinition = {
            name = "Alias definition",
            desc = "Select a saved alias to edit it, or New alias to create one. Changing the shortcut name creates a separate alias.",
            type = "input",
            order = 3,
            width = "full",
            disabled = function () return not Core.db.profile.slashAliasesEnabled end,
            get = function ()
              local name = getSelectedAlias()
              return name ~= "" and ("/"..name.." = "..Core.db.global.slashAliases[name]) or ""
            end,
            validate = function (_, input)
              local name, errorMessage = Core:GetModule("SlashAliases"):ParseDefinition(input)
              return name and true or errorMessage or false
            end,
            set = function (_, input)
              local name = Core:GetModule("SlashAliases"):Set(input)
              if not name then return end
              selectedAlias = name
              Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
            end,
          },
          removeAlias = {
            name = "Remove selected alias",
            type = "execute",
            order = 4,
            hidden = function () return getSelectedAlias() == "" end,
            disabled = function () return getSelectedAlias() == "" end,
            func = function ()
              local name = getSelectedAlias()
              if name == "" then return end
              Core:GetModule("SlashAliases"):Remove(name)
              if Core.db.global.slashAliases[name] == nil then selectedAlias = "" end
              Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
            end,
          },
        },
      },
      animation = {
        name = "Animation",
        type = "group",
        inline = true,
        order = 5,
        args = {
          editBoxFadeInDuration = {
            name = "Fade in duration",
            desc = "Controls how the edit-box background fades when chat opens or closes.\nDefault: "..
              Core.defaults.profile.editBoxFadeInDuration.." seconds\nMin: 0\nMax: 5",
            type = "range",
            order = 1,
            min = 0,
            max = 5,
            softMax = 3,
            step = 0.05,
            get = function ()
              return Core.db.profile.editBoxFadeInDuration
            end,
            set = function (_, input)
              Core.db.profile.editBoxFadeInDuration = input
              Core:Dispatch(UpdateConfig("editBoxFadeInDuration"))
            end,
          },
          editBoxFadeOutDuration = {
            name = "Fade out duration",
            desc = "Controls how the edit-box background fades when chat opens or closes.\nDefault: "..
              Core.defaults.profile.editBoxFadeOutDuration.." seconds\nMin: 0\nMax: 5",
            type = "range",
            order = 2,
            min = 0,
            max = 5,
            softMax = 3,
            step = 0.05,
            get = function ()
              return Core.db.profile.editBoxFadeOutDuration
            end,
            set = function (_, input)
              Core.db.profile.editBoxFadeOutDuration = input
              Core:Dispatch(UpdateConfig("editBoxFadeOutDuration"))
            end,
          },
          editBoxBackgroundEasing = {
            name = "Background easing",
            desc = "Controls how the edit-box background fades when chat opens or closes.\nDefault: "..
              EASING_VALUES[Core.defaults.profile.editBoxBackgroundEasing],
            type = "select",
            order = 3,
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
          editBoxEasing = {
            name = "Movement easing",
            desc = "Controls how messages move when the chat entry field opens or closes.\nDefault: "..
              EASING_VALUES[Core.defaults.profile.editBoxEasing],
            type = "select",
            order = 4,
            width = 1,
            values = EASING_VALUES,
            sorting = EASING_SORTING,
            get = function ()
              return Core.db.profile.editBoxEasing
            end,
            set = function (_, input)
              Core.db.profile.editBoxEasing = input
              Core:Dispatch(UpdateConfig("editBoxEasing"))
            end,
          },
        },
      },
    },
  }
end



C.Pages.general = getGeneralOptions
C.Pages.tabs = getTabOptions
C.Pages.editBox = getEditBoxOptions
