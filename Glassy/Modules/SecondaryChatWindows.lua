local Core = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local function canGroup(window)
  if not window or not window.detachedLayout then return false end
  local frame = window.chatFrame
  return not frame.isDocked and frame ~= _G.ChatFrame1 and frame ~= _G.ChatFrame2
    and frame:IsShown() and window.tab:IsShown()
end

local function isPersistent(window)
  return not window.temporary and not window.chatFrame.isTemporary
end

function UIManager:IsSecondaryWindowHost(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  return window and window.secondaryGroup and window.secondaryGroup.host == window
end

function UIManager:IsSecondaryTabSelected(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  local group = window and window.secondaryGroup
  if group then return group.selected == window end
end

function UIManager:GetSecondaryChatTargets(chatFrame)
  local source = self:GetChatWindow(chatFrame)
  local targets = {}
  if not canGroup(source) or self:IsSecondaryWindowHost(chatFrame) then return targets end
  for _, window in pairs(self.state.windows) do
    if window.active and window ~= source and canGroup(window)
      and (not window.secondaryGroup or window.secondaryGroup.host == window)
      and (not source.secondaryGroup or source.secondaryGroup.host ~= window) then
      targets[#targets + 1] = window.chatFrame
    end
  end
  table.sort(targets, function (a, b) return a:GetID() < b:GetID() end)
  return targets
end

function UIManager:UpdateSecondaryChatVisibility(group)
  local hostFrame = group.host.slidingMessageFrame
  local shown = hostFrame.glassyNativeShown
  if shown == nil then shown = group.host.chatFrame:IsShown() end
  local container = group.host.detachedLayout.container
  for _, member in ipairs(group.members) do
    local renderer = member.slidingMessageFrame
    local selected = shown and member == group.selected and not member.chatFrame.isDocked
    if selected then renderer:ApplyPendingDynamicEditBoxLayout() end
    renderer:SetShown(selected)
  end
  container:SetShown(shown)
end

local function updateDock(group)
  local tabs = {}
  for _, member in ipairs(group.members) do tabs[#tabs + 1] = member.tab end
  group.host.detachedLayout.dock:SetTabs(tabs, group.selected.tab)
end

function UIManager:LayoutSecondaryChatGroup(group)
  local layout = group.host.detachedLayout
  for _, member in ipairs(group.members) do
    self:ApplyDetachedChatLayout(member, layout, group)
  end
  updateDock(group)
  self:UpdateSecondaryChatVisibility(group)
end

function UIManager:SelectSecondaryTab(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  local group = window and window.secondaryGroup
  if not group or group.selected == window then return end
  group.selected = window
  updateDock(group)
  self:UpdateSecondaryChatVisibility(group)
  self:SaveSecondaryChatGroups()
end

function UIManager:MoveChatToSecondaryWindow(chatFrame, targetChatFrame)
  local eligible = false
  for _, target in ipairs(self:GetSecondaryChatTargets(chatFrame)) do
    if target == targetChatFrame then eligible = true break end
  end
  if not eligible then return false end
  local window, host = self:GetChatWindow(chatFrame), self:GetChatWindow(targetChatFrame)
  self:SeparateChatTab(chatFrame)
  local group = host.secondaryGroup
  if not group then
    group = {host = host, members = {host}, selected = host}
    host.secondaryGroup = group
  end
  group.members[#group.members + 1] = window
  window.secondaryGroup = group
  -- The native windows keep independent positions for when their tabs are separated.
  window.detachedLayout.container:Hide()
  self:LayoutSecondaryChatGroup(group)
  self:SaveSecondaryChatGroups()
  return true
end

function UIManager:SeparateChatTab(chatFrame)
  local window = self:GetChatWindow(chatFrame)
  local group = window and window.secondaryGroup
  if not group then return false end
  if group.host == window or #group.members == 2 then
    group.host.detachedLayout.dock:SetTabs({})
    for _, member in ipairs(group.members) do member.secondaryGroup = nil end
    for _, member in ipairs(group.members) do self:RefreshChatFrameLayout(member.chatFrame) end
  else
    window.secondaryGroup = nil
    for index, member in ipairs(group.members) do
      if member == window then table.remove(group.members, index) break end
    end
    if group.selected == window then group.selected = group.host end
    updateDock(group)
    self:RefreshChatFrameLayout(chatFrame)
    self:UpdateSecondaryChatVisibility(group)
  end
  self:SaveSecondaryChatGroups()
  return true
end

function UIManager:SaveSecondaryChatGroups()
  if self.restoringSecondaryChatGroups then return end
  local saved = {}
  for _, host in pairs(self.state.windows) do
    local group = host.secondaryGroup
    if group and group.host == host and isPersistent(host) then
      local members = {}
      for index = 2, #group.members do
        local member = group.members[index]
        if isPersistent(member) then members[#members + 1] = member.chatFrame:GetName() end
      end
      if #members > 0 then
        saved[#saved + 1] = {host = host.chatFrame:GetName(), members = members,
          selected = isPersistent(group.selected) and group.selected.chatFrame:GetName() or nil}
      end
    end
  end
  Core.db.char.secondaryChatGroups = #saved > 0 and saved or nil
end

function UIManager:RestoreSecondaryChatGroups()
  local saved = Core.db.char.secondaryChatGroups
  if type(saved) ~= "table" then return end
  local function savedFrame(name)
    local window = type(name) == "string" and self.state.windows[name]
    return window and window.active and isPersistent(window) and window.chatFrame or nil
  end
  self.restoringSecondaryChatGroups = true
  for _, layout in ipairs(saved) do
    local host = type(layout) == "table" and savedFrame(layout.host)
    if host and type(layout.members) == "table" then
      for _, name in ipairs(layout.members) do
        local frame = savedFrame(name)
        if frame then self:MoveChatToSecondaryWindow(frame, host) end
      end
      local selected = savedFrame(layout.selected)
      local window = self:GetChatWindow(selected)
      if window and window.secondaryGroup and window.secondaryGroup.host.chatFrame == host then
        self:SelectSecondaryTab(selected)
      end
    end
  end
  self.restoringSecondaryChatGroups = nil
  self:SaveSecondaryChatGroups()
end
