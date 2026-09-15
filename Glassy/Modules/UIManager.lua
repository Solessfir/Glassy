local Core, Constants, Utils = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local CreateChatDock = Core.Components.CreateChatDock
local CreateChatTab = Core.Components.CreateChatTab
local CreateCombatLogBar = Core.Components.CreateCombatLogBar
local CreateEditBox = Core.Components.CreateEditBox
local CreateMainContainerFrame = Core.Components.CreateMainContainerFrame
local CreateMoverFrame = Core.Components.CreateMoverFrame
local CreateSlidingMessageFramePool = Core.Components.CreateSlidingMessageFramePool

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local BNToastFrame = BNToastFrame
local ChatAlertFrame = ChatAlertFrame
local ChatFrameChannelButton = ChatFrameChannelButton
local ChatFrameMenuButton = ChatFrameMenuButton
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local GetCVar = C_CVar and C_CVar.GetCVar or GetCVar
local NUM_CHAT_WINDOWS = NUM_CHAT_WINDOWS
local QuickJoinToastButton = QuickJoinToastButton
local SetCVar = C_CVar and C_CVar.SetCVar or SetCVar
local UIParent = UIParent
-- luacheck: pop

----
-- UIManager Module
function UIManager:OnInitialize()
  self.state = {
    frames = {},
    tabs = {},
    temporaryFrames = {},
    temporaryTabs = {}
  }
  self.pendingFrames = {}
  self.renderScheduled = false
end

function UIManager:QueueFrameForUpdate(slidingMessageFrame)
  if slidingMessageFrame == nil or self.renderFrame == nil then
    return
  end

  self.pendingFrames[slidingMessageFrame] = true
  if not self.renderScheduled then
    self.renderScheduled = true
    self.renderFrame:SetScript("OnUpdate", self.renderOnUpdate)
  end
end

function UIManager:ProcessPendingFrames()
  self.renderScheduled = false
  self.renderFrame:SetScript("OnUpdate", nil)

  local pendingFrames = self.pendingFrames
  self.pendingFrames = {}
  for slidingMessageFrame in pairs(pendingFrames) do
    if slidingMessageFrame.chatFrame then
      slidingMessageFrame:OnFrame()
    end
  end

  if next(self.pendingFrames) and not self.renderScheduled then
    self.renderScheduled = true
    self.renderFrame:SetScript("OnUpdate", self.renderOnUpdate)
  end
end

function UIManager:OnEnable()
  self.renderFrame = CreateFrame("Frame", "GlassyUpdaterFrame", UIParent)
  self.renderOnUpdate = function ()
    self:ProcessPendingFrames()
  end

  -- Mover
  self.moverFrame = CreateMoverFrame("GlassyMoverFrame", UIParent)

  -- Main Container
  self.container = CreateMainContainerFrame("GlassyFrame", UIParent)
  self.container:SetPoint("TOPLEFT", self.moverFrame)
  self.moverFrame:AddBoundsRegion(self.container)

  -- Chat dock
  self.dock = CreateChatDock(self.container)
  self.container:AddHoverRegion(self.dock.overflowButton.list)

  -- SlidingMessageFrames
  self.slidingMessageFramePool = CreateSlidingMessageFramePool(self.container)
  local initiallyShownChatFrame

  for i=1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame"..i]
    if chatFrame:IsShown() then
      initiallyShownChatFrame = chatFrame
    end

    local smf = self.slidingMessageFramePool:Acquire()
    smf:Init(chatFrame)

    self.state.frames[i] = smf
    self.state.tabs[i] = CreateChatTab(smf, self.dock)
  end

  self.dock:RestoreSelectedTab(initiallyShownChatFrame)

  local function initializeCombatLogBar()
    if self.combatLogBar then
      return true
    end

    self.combatLogBar = CreateCombatLogBar(self.container, self.state.frames[2])
    if self.combatLogBar then
      self.container:AddHoverRegion(self.combatLogBar)
      self.moverFrame:AddBoundsRegion(self.combatLogBar, function ()
        return
          not Core.db.profile.combatLogHidden and
          Core.db.profile.combatLogBarPosition ~= "HIDDEN"
      end)
    end
    if self.combatLogBar and Core.db.profile.combatLogHidden then
      self.state.frames[2]:ApplyCombatLogVisibility()
    end
    return self.combatLogBar ~= nil
  end

  if not initializeCombatLogBar() then
    self.combatLogLoader = CreateFrame("Frame", nil, UIParent)
    self.combatLogLoader:RegisterEvent("ADDON_LOADED")
    self.combatLogLoader:SetScript("OnEvent", function (_, _, addonName)
      if addonName == "Blizzard_CombatLog" and initializeCombatLogBar() then
        self.combatLogLoader:UnregisterAllEvents()
      end
    end)
  end

  -- Edit box
  self.editBox = CreateEditBox(self.container)
  self.container:AddHoverRegion(self.editBox)
  self.container:AddHoverRegion(self.editBox.dynamicMessageArea)
  self.moverFrame:AddBoundsRegion(self.editBox)
  self.moverFrame:SetLayoutRegions(self.container, self.editBox)

  -- Fix Battle.net Toast frame position
  if ChatAlertFrame then
    ChatAlertFrame:ClearAllPoints()
    ChatAlertFrame:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 15, 10)
    if BNToastFrame then
      BNToastFrame:ClearAllPoints()
      BNToastFrame:SetPoint("BOTTOMLEFT", ChatAlertFrame, "BOTTOMLEFT", 0, 0)
    end
  end

  -- Hide other chat elements
  if Constants.ENV == "retail" and QuickJoinToastButton then
    QuickJoinToastButton:Hide()
  end

  if ChatFrameChannelButton then ChatFrameChannelButton:Hide() end
  if ChatFrameMenuButton then ChatFrameMenuButton:Hide() end

  -- New version alert
  --@non-debug@
  if Core.db.global.version == nil or Utils.versionGreaterThan(Core.Version, Core.db.global.version) then
    Utils.notify('Glassy has just been updated. |cFFFFFF00|Hgarrmission:Glassy:opennews|h[See what’s new]|h|r')
    Core.db.global.version = Core.Version
  end
  --@end-non-debug@--

  -- Force classic chat style
  if GetCVar("chatStyle") ~= "classic" then
    SetCVar("chatStyle", "classic")
    Utils.notify('Chat Style set to "Classic Style"')

    -- Resets the background that IM style causes
    self.editBox:SetFocus()
    self.editBox:ClearFocus()
  end

  -- Handle temporary chat frames (whisper popout, pet battle)
  self:RawHook("FCF_OpenTemporaryWindow", function (...)
    local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
    if chatFrame == nil then
      return nil
    end

    local frameName = chatFrame:GetName()
    if self.state.temporaryFrames[frameName] == nil then
      local smf = self.slidingMessageFramePool:Acquire()
      smf:Init(chatFrame)

      self.state.temporaryFrames[frameName] = smf
      self.state.temporaryTabs[frameName] = CreateChatTab(smf, self.dock)
    end

    return chatFrame
  end, true)

  -- Close window
  self:RawHook("FCF_Close", function (chatFrame)
    self.hooks["FCF_Close"](chatFrame)

    local frameName = chatFrame:GetName()
    local smf = self.state.temporaryFrames[frameName]
    if smf ~= nil then
      self.pendingFrames[smf] = nil
      self.slidingMessageFramePool:Release(smf)
      self.state.temporaryFrames[frameName] = nil
      self.state.temporaryTabs[frameName] = nil
    end
  end, true)

  -- Poll hover state at a low rate. Message queues use the work-driven render frame above.
  self.mouseoverTicker = C_Timer.NewTicker(0.05, function ()
    self.container:OnFrame()
  end)
end
