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
  self.state = {windows = {}}
  self.pendingFrames = {}
  self.renderScheduled = false
end

function UIManager:GetChatWindow(chatFrame)
  local window = chatFrame and self.state.windows[chatFrame:GetName()] or nil
  return window and window.active and window or nil
end

function UIManager:GetSlidingMessageFrame(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  return window and window.slidingMessageFrame or nil
end

function UIManager:GetVisibleSlidingMessageFrame(preferredChatFrame)
  local preferred = self:GetSlidingMessageFrame(preferredChatFrame)
  if preferred and preferred:IsShown() then
    return preferred
  end

  for _, window in pairs(self.state.windows) do
    if window.active and window.slidingMessageFrame:IsShown() then
      return window.slidingMessageFrame
    end
  end
end

function UIManager:CreateChatWindow(chatFrame, temporary)
  local existing = self:GetChatWindow(chatFrame)
  if existing then
    return existing
  end

  local slidingMessageFrame = self.slidingMessageFramePool:Acquire()
  slidingMessageFrame:Init(chatFrame)
  local window = self.state.windows[chatFrame:GetName()] or {}
  window.active = true
  window.chatFrame = chatFrame
  window.slidingMessageFrame = slidingMessageFrame
  window.tab = CreateChatTab(slidingMessageFrame, self.dock)
  window.editBox = nil
  window.temporary = not not temporary
  self.state.windows[chatFrame:GetName()] = window
  return window
end

function UIManager:CreateChatEditBox(window)
  if window == nil or window.editBox or window.chatFrame.editBox == nil then
    return window and window.editBox or nil
  end

  local editBox = CreateEditBox(self.container, window.chatFrame.editBox, false)
  window.editBox = editBox
  self.container:AddHoverRegion(editBox)
  self.container:AddHoverRegion(editBox.dynamicMessageArea)
  return editBox
end

function UIManager:ReleaseChatWindow(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  if window == nil or not window.temporary then
    return false
  end

  local slidingMessageFrame = window.slidingMessageFrame
  self.pendingFrames[slidingMessageFrame] = nil
  self.slidingMessageFramePool:Release(slidingMessageFrame)
  if window.detachedLayout then
    window.detachedLayout.container:Hide()
  end
  window.active = false
  window.slidingMessageFrame = nil
  window.tab = nil
  window.editBox = nil
  return true
end

function UIManager:CreateDetachedLayout(window)
  local chatFrame = window.chatFrame
  local container = CreateFrame("Frame", nil, UIParent)
  container:SetPoint("TOPLEFT", chatFrame, "TOPLEFT", 0, Constants.DOCK_HEIGHT)
  container:SetPoint("BOTTOMRIGHT", chatFrame, "BOTTOMRIGHT")
  container:SetFrameStrata(chatFrame:GetFrameStrata())
  container:SetFrameLevel(chatFrame:GetFrameLevel() + 1)

  local layout = {
    chatFrame = chatFrame,
    container = container,
    dock = CreateDetachedChatDock(container, window.tab),
  }
  window.detachedLayout = layout
  self.container:AddHoverRegion(container)

  container:SetScript("OnSizeChanged", function ()
    if chatFrame.isDocked or layout.resizeScheduled then
      return
    end

    layout.resizeScheduled = true
    C_Timer.After(0, function ()
      layout.resizeScheduled = nil
      if (
        not chatFrame.isDocked and
        window.slidingMessageFrame and
        window.slidingMessageFrame.chatFrame == chatFrame
      ) then
        local editBox = window.editBox
        if editBox then
          editBox:SetGlassyParent(container, true)
        end
        window.slidingMessageFrame:SetLayout(
          container,
          container:GetWidth(),
          container:GetHeight(),
          editBox or false,
          container
        )
        if self.combatLogBar and self.combatLogBar.slidingMessageFrame == window.slidingMessageFrame then
          self.combatLogBar:UpdateLayout()
        end
      end
    end)
  end)
  return layout
end

function UIManager:RefreshChatFrameLayout(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  if window == nil then
    return
  end

  local slidingMessageFrame = window.slidingMessageFrame
  local editBox = window.editBox
  local layout = window.detachedLayout
  if chatFrame.isDocked then
    local mainWindow = self:GetChatWindow(_G.ChatFrame1)
    editBox = mainWindow and mainWindow.editBox or editBox
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
    layout = self:CreateDetachedLayout(window)
  else
    layout.dock:SetTab(window.tab)
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

function UIManager:CreateRootFrames()
  self.renderFrame = CreateFrame("Frame", "GlassyUpdaterFrame", UIParent)
  self.renderOnUpdate = function ()
    self:ProcessPendingFrames()
  end

  self.moverFrame = CreateMoverFrame("GlassyMoverFrame", UIParent)
  self.container = CreateMainContainerFrame("GlassyFrame", UIParent)
  self.container:SetPoint("TOPLEFT", self.moverFrame)
  self.moverFrame:AddBoundsRegion(self.container)
  self.dock = CreateChatDock(self.container)
  self.container:AddHoverRegion(self.dock.overflowButton.list)
  self.slidingMessageFramePool = CreateSlidingMessageFramePool(self.container)
end

function UIManager:InitializeChatWindows()
  local initiallyShownChatFrame

  for i=1, NUM_CHAT_WINDOWS do
    local chatFrame = _G["ChatFrame"..i]
    if chatFrame:IsShown() and chatFrame.isDocked then
      initiallyShownChatFrame = chatFrame
    end

    self:CreateChatWindow(chatFrame, false)
  end

  for i=1, NUM_CHAT_WINDOWS do
    self:CreateChatEditBox(self:GetChatWindow(_G["ChatFrame"..i]))
  end

  for i=1, NUM_CHAT_WINDOWS do
    self:RefreshChatFrameLayout(_G["ChatFrame"..i])
  end

  self.dock:RestoreSelectedTab(initiallyShownChatFrame)
  -- Restoring Blizzard's selected chat window can show the dock again. Reapply the configured persistent state without waiting for the normal hide delay.
  if Core.db.profile.chatAlwaysVisible then
    self.dock:QuickShow()
  else
    self.dock:QuickHide()
  end
end

function UIManager:TryInitializeCombatLogBar()
  if self.combatLogBar then
    return true
  end

  local slidingMessageFrame = self:GetSlidingMessageFrame(_G.ChatFrame2)
  self.combatLogBar = CreateCombatLogBar(self.container, slidingMessageFrame)
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
    slidingMessageFrame:ApplyCombatLogVisibility()
  end
  return self.combatLogBar ~= nil
end

function UIManager:InitializeCombatLog()
  if not self:TryInitializeCombatLogBar() then
    self.combatLogLoader = CreateFrame("Frame", nil, UIParent)
    self.combatLogLoader:RegisterEvent("ADDON_LOADED")
    self.combatLogLoader:SetScript("OnEvent", function (_, _, addonName)
      if addonName == "Blizzard_CombatLog" and self:TryInitializeCombatLogBar() then
        self.combatLogLoader:UnregisterAllEvents()
      end
    end)
  end
end

function UIManager:ConfigureNativeChat()
  local mainWindow = self:GetChatWindow(_G.ChatFrame1)
  self.editBox = mainWindow and mainWindow.editBox or CreateEditBox(self.container)
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
end

function UIManager:HookChatWindowLifecycle()
  self:RawHook("FCF_OpenTemporaryWindow", function (...)
    local chatFrame = self.hooks["FCF_OpenTemporaryWindow"](...)
    if chatFrame == nil then
      return nil
    end

    if self:GetChatWindow(chatFrame) == nil then
      local window = self:CreateChatWindow(chatFrame, true)
      self:CreateChatEditBox(window)
      self:RefreshChatFrameLayout(chatFrame)
    end

    return chatFrame
  end, true)

  -- Close window
  self:RawHook("FCF_Close", function (chatFrame)
    self.hooks["FCF_Close"](chatFrame)
    self:ReleaseChatWindow(chatFrame)
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
end

function UIManager:OnEnable()
  self.layoutUpdates = {}
  self:CreateRootFrames()
  self:InitializeChatWindows()
  self:InitializeCombatLog()
  self:ConfigureNativeChat()
  self:HookChatWindowLifecycle()

  -- Poll hover state at a low rate. Message queues use the work-driven render frame above.
  self.mouseoverTicker = C_Timer.NewTicker(0.05, function ()
    self.container:OnFrame()
  end)
end
