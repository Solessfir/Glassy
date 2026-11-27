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

local PRAT_CHAT_MODULES = {
  "ChannelNames", "Highlight", "History", "Invites", "LinkInfoIcons", "PlayerNames", "Timestamps", "UrlCopy",
  "AltNames", "ChannelColorMemory", "ChannelSticky", "ChatLog", "CustomFilters", "Mentions", "PopupMessage",
  "Sounds", "Substitutions", "TellTarget",
}

local function formatList(items)
  return "• "..table.concat(items, "\n• ")
end

local function getPratStatus()
  local prat = _G.Prat
  return "|cff80ff80Prat|r"..(prat and prat.Version and " |cff8080ff"..tostring(prat.Version).."|r" or "")
end

local function getEnabledPratModules(moduleNames, chatFeatures)
  local enabled = {}
  if _G.Prat == nil then return enabled end
  for _, name in ipairs(moduleNames) do
    if Core:IsPratModuleEnabled(name, chatFeatures and name == "History" and "scrollback" or nil) then
      enabled[#enabled + 1] = name
    end
  end
  return enabled
end

local function getPratChatModules()
  return "Prat currently supplies these features: "..table.concat(getEnabledPratModules(PRAT_CHAT_MODULES, true), ", ")..".\n\n"..
    "Disable the matching Prat modules and reload to use Glassy's settings under Messages."
end

local function getElvUIEngine()
  local elvui = _G.ElvUI
  return type(elvui) == "table" and elvui[1]
end

local function getElvUIStatus()
  local engine = getElvUIEngine()
  if not engine then return "" end
  local version = engine.versionString or engine.version
  return "|cff80ff80ElvUI|r"..(version and " |cff8080ff"..tostring(version).."|r" or "")
end

local function isAddOnLoaded(name)
  local loaded = _G.C_AddOns and _G.C_AddOns.IsAddOnLoaded or _G.IsAddOnLoaded
  return loaded and loaded(name) or false
end

local function getEllesmereStatus()
  local status = "|cff80ff80EllesmereUI|r"
  if Core:GetModule("Ellesmere"):IsActive() then return status end
  return status.."\nGlassy's skin is turned off in EllesmereUI's Third-Party Addons options."
end

local function getEnabledPratUiModules()
  return L("|cffff8080Enabled Prat UI modules that Glassy replaces:|r").."\n"..
    formatList(getEnabledPratModules(PRAT_UI_MODULES)).."\n\n"..L("Disable these Prat modules and reload.")
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
              "|cffffd100Ctrl+U / K / Y|r are unavailable during Blizzard's chat messaging lockdown.",
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
        name = "Chat actions",
        type = "group",
        inline = true,
        order = 4,
        args = {
          reference = {
            type = "description",
            fontSize = "medium",
            width = "full",
            order = 1,
            name = "|cffffd100Shift-click a chat tab|r  Open that tab's chat history for copying. Press Ctrl+C to copy it to the clipboard.\n\n"..
              "|cffffd100Alt-click a player name|r  Invite the character to your group.",
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
      commandStandalone = commandRow(1.5, "/gl standalone", "Open the standalone settings"),
      commandMover = commandRow(2, "/gl lock", "Toggle the Glassy frame mover"),
      commandDebug = commandRow(3, "/gl debug", "Open a copyable layout debug report"),
      commandNews = commandRow(4, "/gl news", "Open version history"),
      commandDemo = commandRow(5, "/gl demo", "Toggle demo mode"),
      commandAlias = commandRow(6, "/alias rld /reload", "Create a shortcut for a slash command"),
      commandUnalias = commandRow(7, "/unalias rld", "Remove a shortcut"),
      commandListAliases = commandRow(8, "/listaliases", "List saved shortcuts"),
      commandTellTarget = commandRow(9, "/tt", "Whisper your player target when enabled in Messages"),
    },
  }
end


local function getCompatibilityOptions()
  return {
    name = "Compatibility",
    type = "group",
    order = 6,
    hidden = function () return _G.Prat == nil and not getElvUIEngine() and not _G.EllesmereUI and not isAddOnLoaded("EllesmereUIChat") end,
    args = {
      pratStatus = {
        name = getPratStatus,
        hidden = function () return _G.Prat == nil end,
        type = "description",
        fontSize = "medium",
        order = 1,
      },
      elvuiStatus = {
        name = getElvUIStatus,
        hidden = function () return not getElvUIEngine() end,
        type = "description",
        fontSize = "medium",
        order = 1.1,
      },
      ellesmereStatus = {
        name = getEllesmereStatus,
        hidden = function () return not _G.EllesmereUI end,
        type = "description",
        fontSize = "medium",
        order = 1.2,
      },
      ellesmereChatStatus = {
        name = "|cffff8080EllesmereUI Chat is enabled.|r\nIt restyles the same chat frames as Glassy. Disable the EllesmereUI Chat addon, then reload.",
        hidden = function () return not isAddOnLoaded("EllesmereUIChat") end,
        type = "description",
        fontSize = "medium",
        order = 1.3,
      },
      pratSupported = {
        name = "Prat chat features",
        type = "group",
        inline = true,
        order = 3,
        hidden = function () return #getEnabledPratModules(PRAT_CHAT_MODULES, true) == 0 end,
        args = {
          details = {
            name = getPratChatModules,
            type = "description",
            order = 1,
          },
          history = {
            name = "To keep existing scrollback, turn on Save chat history in Glassy and reload once with Prat History still enabled. Then disable Prat History and reload again.",
            type = "description",
            order = 2,
            hidden = function () return _G.Prat == nil or not Core:IsPratModuleEnabled("History", "scrollback") end,
          },
        },
      },
      pratUiModules = {
        name = "Prat UI modules",
        type = "group",
        inline = true,
        order = 4,
        hidden = function () return #getEnabledPratModules(PRAT_UI_MODULES) == 0 end,
        args = {
          current = {
            name = getEnabledPratUiModules,
            nameLocalized = true,
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
  }
end


C.Pages.shortcuts = getShortcutOptions
C.Pages.commands = getCommandOptions
C.Pages.compatibility = getCompatibilityOptions
C.Pages.about = getAboutOptions
