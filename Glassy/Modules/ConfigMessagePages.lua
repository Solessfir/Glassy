local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local L = function(text) return Core:Localize(text) end
local MAX_COMBAT_LOG_BAR_OFFSET = 500
local UpdateConfig = Constants.ACTIONS.UpdateConfig

local getTimestampFrameOptions = C.GetTimestampFrameOptions
local disableBuiltinTimestamps = C.DisableBuiltinTimestamps

local function previewAnimations()
  local uiManager = Core:GetModule("UIManager")
  local dock = _G.GENERAL_CHAT_DOCK
  local chatFrame = (dock and dock.selected) or _G.SELECTED_CHAT_FRAME or _G.ChatFrame1
  local slidingMessageFrame = uiManager:GetVisibleSlidingMessageFrame(chatFrame)
  if slidingMessageFrame then
    slidingMessageFrame:PreviewAnimations()
  end
end

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

local function getMessageOptions()
  return {
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
  }
end

local function getTimestampOptions()
  return {
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
  }
end

local function getCombatLogOptions()
  return {
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
  }
end



C.Pages.messages = getMessageOptions
C.Pages.timestamps = getTimestampOptions
C.Pages.combatLog = getCombatLogOptions
