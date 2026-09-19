local Core, Constants, Utils = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local CreateChatDock = Core.Components.CreateChatDock
local CreateChatTab = Core.Components.CreateChatTab
local CreateCombatLogBar = Core.Components.CreateCombatLogBar
local CreateDetachedChatDock = Core.Components.CreateDetachedChatDock
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
    framesByName = {},
    tabs = {},
    editBoxes = {},
    detachedLayouts = {},
    temporaryFrames = {},
    temporaryTabs = {}
  }
  self.pendingFrames = {}
  self.renderScheduled = false
end

function UIManager:GetSlidingMessageFrame(chatFrame)
  return chatFrame and self.state.framesByName[chatFrame:GetName()] or nil
end

function UIManager:CreateDetachedLayout(chatFrame, slidingMessageFrame, tab)
  local frameName = chatFrame:GetName()
  local container = CreateFrame("Frame", nil, UIParent)
  container:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, Constants.DOCK_HEIGHT)
  container:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT")
  container:SetFrameStrata(chatFrame:GetFrameStrata())
  container:SetFrameLevel(chatFrame:GetFrameLevel() + 1)

  local layout = {
    chatFrame = chatFrame,
    container = container,
    dock = CreateDetachedChatDock(container, tab),
    slidingMessageFrame = slidingMessageFrame,
  }
  self.state.detachedLayouts[frameName] = layout
  self.container:AddHoverRegion(container)

  container:SetScript("OnSizeChanged", function ()
    if chatFrame.isDocked or layout.resizeScheduled then
      return
    end

    layout.resizeScheduled = true
    C_Timer.After(0, function ()
      layout.resizeScheduled = nil
      if not chatFrame.isDocked and layout.slidingMessageFrame.chatFrame == chatFrame then
        local editBox = self.state.editBoxes[chatFrame:GetName()]
        if editBox then
          editBox:SetGlassyParent(container, true)
        end
        layout.slidingMessageFrame:SetLayout(
          container,
          container:GetWidth(),
          container:GetHeight(),
          editBox or false,
          container
        )
        if self.combatLogBar and self.combatLogBar.slidingMessageFrame == layout.slidingMessageFrame then
          self.combatLogBar:UpdateLayout()
        end
      end
    end)
  end)
  return layout
end

function UIManager:RefreshChatFrameLayout(chatFrame)
  local slidingMessageFrame = self:GetSlidingMessageFrame(chatFrame)
  if slidingMessageFrame == nil then
    return
  end

  local frameName = chatFrame:GetName()
  local tab = self.state.tabs[chatFrame:GetID()] or self.state.temporaryTabs[frameName]
  local editBox = self.state.editBoxes[frameName]
  local layout = self.state.detachedLayouts[frameName]
  if chatFrame.isDocked then
    editBox = self.state.editBoxes.ChatFrame1 or editBox
    if editBox then
      editBox:SetGlassyParent(self.container, false)
    end
    slidingMessageFrame:SetLayout(self.container, nil, nil, editBox, nil)
    if self.combatLogBar and self.combatLogBar.slidingMessageFrame == slidingMessageFrame then
      self.combatLogBar:SetGlassyParent(self.container, false, self.dock)
    end
    self.dock:UpdateTabOrder()
    return
  end

  if layout == nil then
    layout = self:CreateDetachedLayout(chatFrame, slidingMessageFrame, tab)
  else
    layout.slidingMessageFrame = slidingMessageFrame
    layout.dock:SetTab(tab)
  end

  if chatFrame.buttonFrame and chatFrame.buttonFrame.minimizeButton then
    chatFrame.buttonFrame.minimizeButton:Hide()
  end

  if editBox then
    editBox:SetGlassyParent(layout.container, true)
  end

  slidingMessageFrame:SetLayout(
    layout.container,
    layout.container:GetWidth(),
    layout.container:GetHeight(),
    editBox or false,
    layout.container
  )
  if self.combatLogBar and self.combatLogBar.slidingMessageFrame == slidingMessageFrame then
    self.combatLogBar:SetGlassyParent(layout.container, true, layout.dock)
  end
  self.dock:UpdateTabOrder()
end

function UIManager:ScheduleChatFrameLayout(chatFrame)
  if chatFrame == nil or self.layoutUpdates[chatFrame] then
    return
  end

  self.layoutUpdates[chatFrame] = true
  C_Timer.After(0, function ()
    self.layoutUpdates[chatFrame] = nil
    self:RefreshChatFrameLayout(chatFrame)
  end)
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
  self.layoutUpdates = {}
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
    if chatFrame:IsShown() and chatFrame.isDocked then
      initiallyShownChatFrame = chatFrame
    end

    local smf = self.slidingMessageFramePool:Acquire()
    smf:Init(chatFrame)

    self.state.frames[i] = smf
    self.state.framesByName[chatFrame:GetName()] = smf
    self.state.tabs[i] = CreateChatTab(smf, self.dock)
  end

  for i=1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame"..i]
    if chatFrame.editBox then
      local editBox = CreateEditBox(self.container, chatFrame.editBox, false)
      self.state.editBoxes[chatFrame:GetName()] = editBox
      self.container:AddHoverRegion(editBox)
      self.container:AddHoverRegion(editBox.dynamicMessageArea)
    end
  end

  for i=1, NUM_CHAT_WINDOWS do
    self:RefreshChatFrameLayout(_G["ChatFrame"..i])
  end

  self.dock:RestoreSelectedTab(initiallyShownChatFrame)
  -- Restoring Blizzard's selected chat window can show the dock again.
  -- Start with only chat messages visible; hovering chat will reveal the tabs.
  self.dock:QuickHide()

  local function initializeCombatLogBar()
    if self.combatLogBar then
      return true
    end

    self.combatLogBar = CreateCombatLogBar(self.container, self.state.frames[2])
    if self.combatLogBar then
      self:RefreshChatFrameLayout(_G.ChatFrame2)
      self.container:AddHoverRegion(self.combatLogBar)
      self.moverFrame:AddBoundsRegion(self.combatLogBar, function ()
        return
          _G.ChatFrame2.isDocked and
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
  self.editBox = self.state.editBoxes.ChatFrame1 or CreateEditBox(self.container)
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
      self.state.framesByName[frameName] = smf
      if chatFrame.editBox then
        local editBox = CreateEditBox(self.container, chatFrame.editBox, false)
        self.state.editBoxes[frameName] = editBox
        self.container:AddHoverRegion(editBox)
        self.container:AddHoverRegion(editBox.dynamicMessageArea)
      end
      self:RefreshChatFrameLayout(chatFrame)
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
      local layout = self.state.detachedLayouts[frameName]
      if layout then
        layout.container:Hide()
      end
      self.state.framesByName[frameName] = nil
      self.state.temporaryFrames[frameName] = nil
      self.state.temporaryTabs[frameName] = nil
    end
  end, true)

  local function hookLayoutChange(functionName)
    if type(_G[functionName]) == "function" and not self:IsHooked(functionName) then
      self:SecureHook(functionName, function (chatFrame)
        self:ScheduleChatFrameLayout(chatFrame)
      end)
    end
  end
  hookLayoutChange("FCF_DockFrame")
  hookLayoutChange("FCF_UnDockFrame")
  hookLayoutChange("FCF_StopDragging")

  -- Poll hover state at a low rate. Message queues use the work-driven render frame above.
  self.mouseoverTicker = C_Timer.NewTicker(0.05, function ()
    self.container:OnFrame()
  end)
end
