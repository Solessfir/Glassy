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
  function frame:Hide() self.shown = false end
  return frame
end

local function newSlidingMessageFrame()
  return {
    shown = true,
    Init = function (self, chatFrame) self.chatFrame = chatFrame end,
    IsShown = function (self) return self.shown end,
    SetLayout = function (self, parent, width, height, editBox, detachedContainer)
      self.layout = {
        parent = parent,
        width = width,
        height = height,
        editBox = editBox,
        detachedContainer = detachedContainer,
      }
    end,
  }
end

local detachedDocks = {}
local function createDetachedChatDock(_, tab)
  local dock = {tab = tab}
  function dock:SetTab(nextTab) self.tab = nextTab end
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
local core = {
  Components = {
    CreateChatDock = noop,
    CreateChatTab = function (slidingMessageFrame) return {slidingMessageFrame = slidingMessageFrame} end,
    CreateCombatLogBar = noop,
    CreateDetachedChatDock = createDetachedChatDock,
    CreateEditBox = createEditBox,
    CreateMainContainerFrame = noop,
    CreateMoverFrame = noop,
    CreateSlidingMessageFramePool = noop,
  },
  GetModule = function () return manager end,
}
local constants = {DOCK_HEIGHT = 24, ENV = "classic"}
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

print("PASS: unified chat-window registration, detach, resize, tab replacement, redock, cleanup, and reopen")
