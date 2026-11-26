-- Run from the repository root with Lua 5.1.
---@diagnostic disable: undefined-global
local function noop() end

local function newFrame(name, width, height)
  local frame = {
    name = name,
    width = width or 320,
    height = height or 200,
    scripts = {},
    shown = true,
  }
  function frame:GetName() return self.name end
  function frame:GetID() return self.id end
  function frame:GetWidth() return self.width end
  function frame:GetHeight() return self.height end
  function frame:GetFrameStrata() return "MEDIUM" end
  function frame:GetFrameLevel() return 1 end
  function frame:SetFrameStrata(strata) self.strata = strata end
  function frame:SetFrameLevel(level) self.level = level end
  function frame:SetPoint(...) self.point = {...} end
  function frame:SetScript(name, callback) self.scripts[name] = callback end
  function frame:IsShown() return self.shown end
  function frame:SetShown(shown) self.shown = shown end
  function frame:Hide() self.shown = false end
  return frame
end

local function newSlidingMessageFrame()
  return {
    shown = true,
    Init = function (self, chatFrame) self.chatFrame = chatFrame end,
    IsShown = function (self) return self.shown end,
    SetShown = function (self, shown) self.shown = shown end,
    ApplyPendingDynamicEditBoxLayout = noop,
    SetLayout = function (self, parent, width, height, editBox, detachedContainer, group)
      self.layout = {
        parent = parent,
        width = width,
        height = height,
        editBox = editBox,
        detachedContainer = detachedContainer,
        group = group,
      }
    end,
  }
end

local detachedDocks = {}
local function createDetachedChatDock(_, tab)
  local dock = {tab = tab}
  function dock:SetTab(nextTab) self.tab, self.tabs, self.selectedTab = nextTab, nil, nil end
  function dock:SetTabs(tabs, selected) self.tabs, self.selectedTab = tabs, selected end
  detachedDocks[#detachedDocks + 1] = dock
  return dock
end

local function createEditBox(_, nativeEditBox)
  local editBox = {nativeEditBox = nativeEditBox, dynamicMessageArea = {}}
  function editBox:SetGlassyParent(parent, detached)
    self.glassyParent = parent
    self.detached = detached
  end
  return editBox
end

local manager = {}
local configListeners = {}
local core = {
  db = {char = {}, profile = {}},
  Components = {
    CreateChatDock = noop,
    CreateChatTab = function (slidingMessageFrame)
      return {slidingMessageFrame = slidingMessageFrame, IsShown = function () return true end}
    end,
    CreateCombatLogBar = noop,
    CreateDetachedChatDock = createDetachedChatDock,
    CreateEditBox = createEditBox,
    CreateMainContainerFrame = noop,
    CreateMoverFrame = noop,
    CreateSlidingMessageFramePool = noop,
  },
  GetModule = function () return manager end,
  Subscribe = function (_, _, callback) configListeners[#configListeners + 1] = callback end,
}
local constants = {DOCK_HEIGHT = 24, ENV = "classic", EVENTS = {UPDATE_CONFIG = "config"}}
local utils = {}

C_Timer = {
  After = function (_, callback) callback() end,
  NewTicker = noop,
}
CreateFrame = function () return newFrame(nil) end
GetCVar = function () return "classic" end
SetCVar = noop
UIParent = newFrame("UIParent")

assert(loadfile("Glassy/Modules/UIManager.lua"))("Glassy", {core, constants, utils})
assert(loadfile("Glassy/Modules/SecondaryChatWindows.lua"))("Glassy", {core, constants, utils})

manager:OnInitialize()
manager.container = newFrame("GlassyFrame", 450, 230)
manager.container.hoverRegions = {}
function manager.container:AddHoverRegion(region)
  self.hoverRegions[#self.hoverRegions + 1] = region
end
manager.dock = {updates = 0}
function manager.dock:UpdateTabOrder() self.updates = self.updates + 1 end
manager.pendingFrames = {}
manager.slidingMessageFramePool = {
  released = {},
  Acquire = function () return newSlidingMessageFrame() end,
  Release = function (self, slidingMessageFrame)
    self.released[#self.released + 1] = slidingMessageFrame
  end,
}

local mainChatFrame = newFrame("ChatFrame1")
mainChatFrame.id = 1
mainChatFrame.isDocked = true
mainChatFrame.editBox = {}
ChatFrame1 = mainChatFrame

local mainWindow = manager:CreateChatWindow(mainChatFrame, false)
local mainEditBox = manager:CreateChatEditBox(mainWindow)
assert(manager:GetChatWindow(mainChatFrame) == mainWindow)
assert(manager:GetSlidingMessageFrame(mainChatFrame) == mainWindow.slidingMessageFrame)
assert(mainWindow.editBox == mainEditBox)

local detachedChatFrame = newFrame("ChatFrame4")
detachedChatFrame.id = 4
detachedChatFrame.isDocked = false
detachedChatFrame.editBox = {}
detachedChatFrame.buttonFrame = {minimizeButton = {Hide = function (self) self.hidden = true end}}

local detachedWindow = manager:CreateChatWindow(detachedChatFrame, true)
local detachedEditBox = manager:CreateChatEditBox(detachedWindow)
mainWindow.slidingMessageFrame.shown = false
assert(manager:GetVisibleSlidingMessageFrame(mainChatFrame) == detachedWindow.slidingMessageFrame)
mainWindow.slidingMessageFrame.shown = true
manager:RefreshChatFrameLayout(detachedChatFrame)

local detachedLayout = detachedWindow.detachedLayout
assert(detachedLayout and detachedLayout.container == detachedWindow.slidingMessageFrame.layout.parent)
assert(detachedWindow.slidingMessageFrame.layout.detachedContainer == detachedLayout.container)
assert(detachedEditBox.glassyParent == detachedLayout.container and detachedEditBox.detached)
assert(detachedChatFrame.buttonFrame.minimizeButton.hidden)
core.db.profile.tabBarPosition = "bottom"
for _, callback in ipairs(configListeners) do callback("tabBarPosition") end
assert(detachedLayout.container.point[1] == "BOTTOMRIGHT" and detachedLayout.container.point[5] == -24,
  "Bottom tabs must extend below native detached messages")
core.db.profile.tabBarPosition = "top"
for _, callback in ipairs(configListeners) do callback("tabBarPosition") end
assert(detachedLayout.container.point[5] == 0)

detachedLayout.container.width = 360
detachedLayout.container.height = 240
detachedLayout.container.scripts.OnSizeChanged()
assert(detachedWindow.slidingMessageFrame.layout.width == 360)
assert(detachedWindow.slidingMessageFrame.layout.height == 240)

local replacementTab = {}
detachedWindow.tab = replacementTab
manager:RefreshChatFrameLayout(detachedChatFrame)
assert(detachedLayout.dock.tab == replacementTab)

detachedChatFrame.isDocked = true
manager:RefreshChatFrameLayout(detachedChatFrame)
assert(detachedWindow.slidingMessageFrame.layout.parent == manager.container)
assert(detachedWindow.slidingMessageFrame.layout.detachedContainer == nil)
assert(mainEditBox.glassyParent == manager.container and not mainEditBox.detached)

manager.pendingFrames[detachedWindow.slidingMessageFrame] = true
local releasedSlidingMessageFrame = detachedWindow.slidingMessageFrame
manager:ReleaseChatWindow(detachedChatFrame)
assert(manager:GetChatWindow(detachedChatFrame) == nil)
assert(manager.pendingFrames[releasedSlidingMessageFrame] == nil)
assert(manager.slidingMessageFramePool.released[1] == releasedSlidingMessageFrame)
assert(not detachedLayout.container.shown)
assert(manager:GetChatWindow(mainChatFrame) == mainWindow, "Closing a temporary window removed the primary window")

detachedChatFrame.isDocked = false
local reopenedWindow = manager:CreateChatWindow(detachedChatFrame, true)
manager:CreateChatEditBox(reopenedWindow)
manager:RefreshChatFrameLayout(detachedChatFrame)
assert(reopenedWindow == detachedWindow)
assert(reopenedWindow.detachedLayout == detachedLayout, "Reopening replaced the retained detached layout")
assert(reopenedWindow.slidingMessageFrame ~= releasedSlidingMessageFrame)

local function detached(id)
  local frame = newFrame("ChatFrame"..id)
  frame.id, frame.isDocked, frame.editBox = id, false, {}
  local window = manager:CreateChatWindow(frame, false)
  manager:CreateChatEditBox(window)
  manager:RefreshChatFrameLayout(frame)
  return frame, window
end

local hostFrame, host = detached(5)
local memberFrame, member = detached(6)
local secondFrame, second = detached(7)
assert(not manager:MoveChatToSecondaryWindow(mainChatFrame, hostFrame))
assert(manager:MoveChatToSecondaryWindow(memberFrame, hostFrame))
assert(manager:MoveChatToSecondaryWindow(secondFrame, hostFrame))
local group = host.secondaryGroup
local shared = host.detachedLayout
assert(group == member.secondaryGroup and group == second.secondaryGroup)
assert(#shared.dock.tabs == 3 and shared.dock.selectedTab == host.tab)
assert(member.slidingMessageFrame.layout.parent == shared.container and member.editBox.glassyParent == shared.container)
assert(memberFrame:IsShown() and not member.detachedLayout.container:IsShown() and not member.slidingMessageFrame:IsShown())
manager:SelectSecondaryTab(memberFrame)
assert(manager:IsSecondaryTabSelected(memberFrame) and not manager:IsSecondaryTabSelected(hostFrame))
assert(member.slidingMessageFrame:IsShown() and not host.slidingMessageFrame:IsShown() and shared.container:IsShown())
host.slidingMessageFrame.glassyNativeShown = false
manager:UpdateSecondaryChatVisibility(group)
assert(not member.slidingMessageFrame:IsShown() and not shared.container:IsShown())
host.slidingMessageFrame.glassyNativeShown = true
shared.container.width = 410
shared.container.scripts.OnSizeChanged()
assert(member.slidingMessageFrame.layout.width == 410 and second.slidingMessageFrame.layout.width == 410)
local saved = core.db.char.secondaryChatGroups
assert(#saved == 1 and saved[1].selected == memberFrame:GetName() and #saved[1].members == 2)

assert(manager:MoveChatToSecondaryWindow(detachedChatFrame, hostFrame))
assert(#core.db.char.secondaryChatGroups[1].members == 2, "Temporary frame slots must never be persisted")
manager:ReleaseChatWindow(detachedChatFrame)
assert(#group.members == 3 and shared.container:IsShown(), "Closing a grouped temporary tab must leave its host visible")

assert(manager:SeparateChatTab(hostFrame))
assert(not (host.secondaryGroup or member.secondaryGroup or second.secondaryGroup))
assert(member.slidingMessageFrame.layout.parent == member.detachedLayout.container and not core.db.char.secondaryChatGroups)
core.db.char.secondaryChatGroups = saved
manager:RestoreSecondaryChatGroups()
assert(host.secondaryGroup == member.secondaryGroup and manager:IsSecondaryTabSelected(memberFrame))
memberFrame.isDocked = true
manager:RefreshChatFrameLayout(memberFrame)
assert(not member.secondaryGroup and member.slidingMessageFrame.layout.parent == manager.container)
assert(#host.secondaryGroup.members == 2 and manager:IsSecondaryTabSelected(hostFrame))
hostFrame.isDocked = true
manager:RefreshChatFrameLayout(hostFrame)
assert(not second.secondaryGroup and second.slidingMessageFrame.layout.parent == second.detachedLayout.container)

print("PASS: unified chat-window registration, detach, resize, tab replacement, redock, cleanup, and reopen")
