local Core, Constants = unpack(select(2, ...))
local C = Core:GetModule("Config")

local L = function(text) return Core:Localize(text) end
local OpenNews = Constants.ACTIONS.OpenNews

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


local function getShortcutOptions()
  return {
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
        order = 1,
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
    },
  }
end

local function getCommandOptions()
  return {
    name = "Commands",
    type = "group",
    args = {
      commandOpen = commandRow(1, "/gl", "Open settings"),
      commandMover = commandRow(2, "/gl lock", "Toggle the Glassy frame mover"),
      commandDebug = commandRow(3, "/gl debug", "Open a copyable layout debug report"),
      commandNews = commandRow(4, "/gl news", "Open version history"),
    },
  }
end


local function getCompatibilityOptions()
  return {
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
  }
end

local function getAboutOptions()
  return {
    name = "About",
    type = "group",
    order = 8,
    args = {
      details = {
        name = "",
        type = "group",
        inline = true,
        order = 2,
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
  }
end


C.Pages.shortcuts = getShortcutOptions
C.Pages.commands = getCommandOptions
C.Pages.compatibility = getCompatibilityOptions
C.Pages.about = getAboutOptions
