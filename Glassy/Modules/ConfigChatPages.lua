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

function C.CreateFontOption(setting, order)
  return {
    name = "Font",
    type = "select",
    order = order,
    dialogControl = "LSM30_Font",
    values = LSM:HashTable("font"),
    get = function ()
      local selected = Core.db.profile[setting]
      return selected and selected ~= "" and selected or Core.db.profile.font
    end,
    set = function (_, input)
      Core.db.profile[setting] = input
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
      section2 = {
        name = "Appearance",
        type = "group",
        inline = true,
        order = 3,
        args = {
          tabHighlightTextColor = {
            name = "Hover label color",
            desc = L("Tabs")..", "..L("Combat Log")..", "..L("Unread messages")..", "..L("Jump to latest"),
            type = "color",
            hasAlpha = true,
            order = 2,
            get = function ()
              local color = Core.db.profile.tabHighlightTextColor
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
              local color = Core.db.profile.tabTextColor
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
          chatAlwaysVisible = {
            name = "Always visible",
            desc = "Keep chat messages, tabs, and headers visible instead of fading them out.\nDefault: off",
            type = "toggle",
            order = 4.1,
            get = function ()
              return Core.db.profile.chatAlwaysVisible
            end,
            set = function (_, input)
              Core.db.profile.chatAlwaysVisible = input
              Core:Dispatch(UpdateConfig("chatAlwaysVisible"))
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
  }
end

local function getTabOptions()
  return {
    name = "Tabs",
    type = "group",
    order = 1.5,
    args = {
      appearance = {
        name = "Appearance",
        type = "group",
        inline = true,
        order = 1,
        args = {
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
          tabFont = C.CreateFontOption("tabFont", 1),
          tabFontFlags = C.CreateFontOutlineOption("tabFontFlags", 1.002),
          chatTabTooltips = {
            name = "Tooltips",
            desc = "Show interaction hints when hovering over chat tabs.\nDefault: off",
            type = "toggle",
            order = 1.7,
            get = function ()
              return Core.db.profile.chatTabTooltips
            end,
            set = function (_, input)
              Core.db.profile.chatTabTooltips = input
              Core:Dispatch(UpdateConfig("chatTabTooltips"))
            end,
          },
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
            desc = "Adds space below the chat tabs while keeping the bottom of the message area fixed.\nDefault: "..
              Core.defaults.profile.tabMessageSpacing.." px\nMin: 0\nMax: "..MAX_TAB_MESSAGE_OFFSET,
            type = "range",
            order = 1.6,
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
    },
  }
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
              local color = Core.db.profile.editBoxMessageSeparatorColor
              return color.r, color.g, color.b, color.a
            end,
            set = function (_, r, g, b, a)
              Core.db.profile.editBoxMessageSeparatorColor = {r = r, g = g, b = b, a = a}
              Core:Dispatch(UpdateConfig("editBoxMessageSeparatorColor"))
            end,
          },
          editBoxFadeInDuration = {
            name = "Fade in duration",
            desc = "Controls how the edit-box background fades when chat opens or closes.\nDefault: "..
              Core.defaults.profile.editBoxFadeInDuration.." seconds\nMin: 0\nMax: 5",
            type = "range",
            order = 1.26,
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
            order = 1.27,
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
            order = 1.25,
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
          editBoxEasing = {
            name = "Movement easing",
            desc = "Controls how messages move when the chat entry field opens or closes.\nDefault: "..
              EASING_VALUES[Core.defaults.profile.editBoxEasing],
            type = "select",
            order = 2.3,
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
          }
        },
      }
    },
  }
end



C.Pages.general = getGeneralOptions
C.Pages.tabs = getTabOptions
C.Pages.editBox = getEditBoxOptions
