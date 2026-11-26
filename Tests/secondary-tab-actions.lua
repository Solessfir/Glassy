-- Run from the repository root with Lua 5.1.
local function noop() end
local actions, menuHook, tabMixin = {}, nil, nil
local manager = {targets = {}}
function manager:GetSecondaryChatTargets() return self.targets end
function manager:IsSecondaryTabSelected(chat) return chat.secondarySelected end
function manager:IsSecondaryWindowHost(chat) return chat.isHost or false end
function manager:MoveChatToSecondaryWindow(chat, target) actions.move = {chat, target} end
function manager:SeparateChatTab(chat)
  actions[#actions + 1] = "separate"
  actions.separated = chat
  _G[chat:GetName().."Tab"].glassySecondaryDock = nil
end
function manager:SelectSecondaryTab(chat) actions.selected = chat end
Menu = {ModifyMenu = function (tag, callback) assert(tag == "MENU_FCF_TAB"); menuHook = callback end}
local function button(label, callback)
  local description = {label = label, callback = callback, children = {}}
  function description:CreateButton(text, handler)
    local child = button(text, handler)
    self.children[#self.children + 1] = child
    return child
  end
  return description
end
MenuUtil = {CreateButton = button, GetElementText = function (description) return description.label end}
ToggleChannelFrame = noop
CHAT_CONFIGURATION, CHAT_CHANNELS, DISPLAY = "Configuration", "Channels", "Display"
FCF_StopAlertFlash, IsShiftKeyDown = noop, function () return false end
GameTooltip = {IsOwned = function () return false end}
Mixin = function (object, mixin)
  tabMixin = mixin
  for key, value in pairs(mixin) do object[key] = value end
  object.ClearBackgroundTextures, object.UpdateTextLayout, object.UpdateVisualState = noop, noop, noop
  return object
end
local hooks = {hooks = {}}
function hooks:IsHooked(_, name) return name ~= "OnClick" end
function hooks:SecureHookScript(object, name, callback) object.posthooks[name] = callback end
local core = {
  Components = {}, Libs = {AceHook = {Embed = function () return hooks end}},
  db = {profile = {tabUnreadCount = true, textLeftPadding = 0}},
  defaults = {profile = {textLeftPadding = 0}},
  Localize = function (_, text) return text end,
  GetModule = function (_, name) assert(name == "UIManager"); return manager end,
  GetThemeColor = function () return {r = 1, g = 1, b = 1} end,
  Subscribe = noop,
}
local constants = {ACTIONS = {}, EVENTS = {}, COLORS = {}, TEXT_RIGHT_PADDING = 5}
assert(loadfile("Glassy/Components/ChatTab.lua"))("Glassy", {core, constants, {}})
local text = {ClearAllPoints = noop, SetPoint = noop, GetStringWidth = function () return 40 end}
local chat = {GetName = function () return "SecondaryTest" end}
_G.SecondaryTest = chat
local nativeClick = noop
local tab = {
  Text = text, glow = {ClearAllPoints = noop, SetPoint = noop}, posthooks = {},
  scripts = {OnClick = nativeClick,
    OnDragStart = function () actions[#actions + 1] = "native start" end,
    OnDragStop = function () actions[#actions + 1] = "native stop" end},
  GetName = function () return "SecondaryTestTab" end,
  SetHeight = noop, SetNormalFontObject = noop, SetPushedTextOffset = noop, SetAlpha = noop,
  RegisterForDrag = noop,
  SetWidth = function (self, width) self.width = width end,
  GetScript = function (self, name) return self.scripts[name] end,
  SetScript = function (self, name, callback) self.scripts[name] = callback end,
}
_G.SecondaryTestTab = tab
local mainLayouts, secondaryLayouts = 0, 0
local dock = {
  UpdateTabOrder = noop,
  ScheduleTabOrder = function () mainLayouts = mainLayouts + 1 end,
  SaveSelectedTab = function (_, frame) actions.saved = frame end,
  StartTabDrag = function (self, dragging)
    if not chat.isDocked then return false end
    self.tabDrag = {tab = dragging}
    actions[#actions + 1] = "dock start"
    return true
  end,
  StopTabDrag = function (self) self.tabDrag = nil; actions[#actions + 1] = "dock stop" end,
}
local secondary = {ScheduleTabOrder = function () secondaryLayouts = secondaryLayouts + 1 end}
core.Components.CreateChatTab({chatFrame = chat}, dock)
assert(tab.scripts.OnClick == nativeClick and tab.posthooks.OnClick, "Native selection must keep its secure script")
SELECTED_CHAT_FRAME = chat
assert(tab:IsSelected(), "Standalone windows retain native selection")
chat.secondarySelected = false
assert(not tab:IsSelected(), "Inactive group tabs override global native selection")
chat.secondarySelected = true
SELECTED_CHAT_FRAME = {}
assert(tab:IsSelected(), "The group's active tab stays selected when another window has focus")
tab.posthooks.OnClick(tab, "RightButton")
assert(not actions.selected and not actions.saved)
tab.posthooks.OnClick(tab, "LeftButton")
assert(actions.selected == chat and actions.saved == chat)

local count = {ClearAllPoints = noop, SetPoint = noop, SetTextColor = noop, GetStringWidth = function () return 6 end}
function count:SetText(value) self.value = value end
function count:SetShown(shown) self.shown = shown end
function count:IsShown() return self.shown end
tab.CreateFontString = function () return count end
tab.UpdateTextLayout = tabMixin.UpdateTextLayout
chat.secondarySelected = false
tab.glassySecondaryDock = secondary
tab:AddUnreadMessage()
assert(tab.glassyUnreadCount == 1 and count.value == "1" and secondaryLayouts == 1 and mainLayouts == 0,
  "Inactive secondary tabs count messages and schedule only their own layout")
tab:UpdateTextLayout()
assert(secondaryLayouts == 2, "Font and icon changes also schedule secondary layout")
chat.secondarySelected = true
tab:AddUnreadMessage()
assert(tab.glassyUnreadCount == 1, "Active secondary tabs do not count unread messages")
tab.glassySecondaryDock, chat.secondarySelected = nil, nil
tab:AddUnreadMessage()
assert(tab.glassyUnreadCount == 1, "Standalone detached windows do not gain unread counts")

tab.glassySecondaryDock, chat.secondarySelected = secondary, false
tab.scripts.OnDragStart(tab, "LeftButton")
assert(actions[1] == "separate" and actions[2] == "native start" and actions.separated == chat,
  "Dragging a member separates it before Blizzard starts moving its native window")
tab.scripts.OnDragStop(tab, "LeftButton")
assert(actions[3] == "native stop", "Native drag cleanup must remain installed")
actions = {}
tab.glassySecondaryDock, chat.isHost = secondary, true
tab.scripts.OnDragStart(tab, "LeftButton")
assert(actions[1] == "native start" and not actions.separated, "Dragging the host retains the group")
tab.glassySecondaryDock, chat.secondarySelected, chat.isDocked = nil, nil, true
tab.scripts.OnDragStart(tab, "LeftButton")
tab.scripts.OnDragStop(tab, "LeftButton")
assert(actions[2] == "dock start" and actions[3] == "dock stop" and not actions[4],
  "Main dock drags still use the existing reorder implementation")

local target = {GetName = function () return "TargetChat" end}
local protected = {}
canaccessvalue = function (value) return value ~= protected end
_G.TargetChatTab = {Text = {GetText = function () return protected end}}
manager.targets, chat.isDocked, chat.isHost = {target}, false, false
local function menu()
  local root = {children = {button(DISPLAY), button(CHAT_CONFIGURATION)}}
  function root:EnumerateElementDescriptions() return ipairs(self.children) end
  function root:Insert(description, index) table.insert(self.children, index or #self.children + 1, description) end
  menuHook(tab, root)
  local descriptions = {}
  for _, description in ipairs(root.children) do descriptions[description.label] = description end
  return descriptions
end
local descriptions = menu()
local move = assert(descriptions["Move to secondary window"])
assert(move.children[1].label == "TargetChat", "Protected names must fall back to native frame names")
move.children[1].callback()
assert(actions.move[1] == chat and actions.move[2] == target)
assert(not descriptions["Separate tab"], "Standalone windows do not offer separation")
chat.secondarySelected = false
descriptions = menu()
assert(descriptions["Separate tab"])
descriptions["Separate tab"].callback()
assert(actions.separated == chat)
manager.targets, chat.isHost = {}, true
descriptions = menu()
assert(descriptions["Ungroup secondary window"] and not descriptions["Move to secondary window"])
print("Secondary tab action tests passed")
