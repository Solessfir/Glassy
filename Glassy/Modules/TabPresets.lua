local Core = unpack(select(2, ...))
local TabPresets = Core:GetModule("TabPresets")

local PRESETS = {
  guild = {name = "Guild", groups = {"GUILD", "OFFICER", "GUILD_ACHIEVEMENT"}},
  party = {name = "Party", groups = {
    "PARTY", "PARTY_LEADER", "RAID", "RAID_LEADER", "RAID_WARNING", "INSTANCE_CHAT", "INSTANCE_CHAT_LEADER",
  }},
}

local function windowLimit()
  local constants = _G.Constants and _G.Constants.ChatFrameConstants
  return constants and constants.MaxChatWindows or _G.NUM_CHAT_WINDOWS or 10
end

local function isActive(index, frame)
  local getInfo = _G.FCF_GetChatWindowInfo or _G.GetChatWindowInfo
  local shown = getInfo and select(7, getInfo(index))
  return shown or frame and (frame.isDocked or frame:IsShown())
end

local function isBuiltin(index, frame)
  return index <= 2 or _G.IsBuiltinChatWindow and frame and _G.IsBuiltinChatWindow(frame)
end

local function hasFreeWindow()
  if _G.FCF_GetNextOpenChatWindowIndex then
    return _G.FCF_GetNextOpenChatWindowIndex() ~= nil
  end
  for index = 3, windowLimit() do
    local frame = _G["ChatFrame"..index]
    if frame and not frame.isTemporary and not isBuiltin(index, frame) and not isActive(index, frame) then
      return true
    end
  end
  return false
end

local function findDedicated(preset)
  local allowed = {}
  for _, group in ipairs(preset.groups) do allowed[group] = true end
  for index = 3, windowLimit() do
    local frame = _G["ChatFrame"..index]
    if frame and not frame.isTemporary and not isBuiltin(index, frame) and isActive(index, frame) then
      local dedicated, primary = true, false
      for _, group in pairs(frame.messageTypeList or {}) do
        if not allowed[group] then dedicated = false end
        if group == preset.groups[1] then primary = true end
      end
      if dedicated and primary and not next(frame.channelList or {}) then return frame end
    end
  end
end

function TabPresets:GetUnavailableReason(key)
  local preset = PRESETS[key]
  if not preset then return "Unknown tab preset." end
  if _G.InCombatLockdown and _G.InCombatLockdown() then return "Available after combat." end
  if not _G.FCF_OpenNewWindow or not (_G.FCF_GetChatWindowInfo or _G.GetChatWindowInfo)
    or not _G.ChatTypeGroup or not _G.ChatTypeGroup[preset.groups[1]] then
    return "Chat tab creation is unavailable on this client."
  end
  if findDedicated(preset) then return "A dedicated "..preset.name.." tab already exists." end
  if not hasFreeWindow() then return "No free chat windows. Close a custom tab first." end
end

local function restoreSelection(selected, editBox)
  if selected and selected.isDocked and _G.FCF_SelectDockFrame then
    _G.FCF_SelectDockFrame(selected)
  end
  local setLastActive = _G.ChatFrameUtil and _G.ChatFrameUtil.SetLastActiveWindow or _G.ChatEdit_SetLastActiveWindow
  if editBox and setLastActive then setLastActive(editBox) end
end

function TabPresets:Create(key)
  local reason = self:GetUnavailableReason(key)
  if reason then self.status = reason; return false, reason end
  local preset = PRESETS[key]
  local active = {}
  for index = 1, windowLimit() do
    local frame = _G["ChatFrame"..index]
    if frame and isActive(index, frame) then active[frame] = true end
  end
  local dock = _G.GENERAL_CHAT_DOCK
  local selected = dock and _G.FCFDock_GetSelectedWindow and _G.FCFDock_GetSelectedWindow(dock)
  local editBox = _G.LAST_ACTIVE_CHAT_EDIT_BOX
  local name = _G[preset.name == "Guild" and "GUILD" or "PARTY"] or preset.name
  -- Classic can overwrite its last window when full, so check capacity before calling the native API.
  local ok, frame = pcall(_G.FCF_OpenNewWindow, name, true)
  if not ok or not frame or active[frame] then
    restoreSelection(selected, editBox)
    self.status = "The game could not create the chat tab."
    return false, self.status
  end
  local addGroup = frame.AddMessageGroup or _G.ChatFrame_AddMessageGroup
  if not addGroup then
    restoreSelection(selected, editBox)
    self.status = "The game could not configure the new chat tab."
    return false, self.status
  end
  local configured = pcall(function ()
    for _, group in ipairs(preset.groups) do
      if _G.ChatTypeGroup[group] then addGroup(frame, group) end
    end
  end)
  restoreSelection(selected, editBox)
  if not configured then
    self.status = "The game could not configure the new chat tab. Check its chat settings."
    return false, self.status
  end
  self.status = preset.name.." tab created. General's filters are unchanged."
  return true, frame
end

function TabPresets:GetOptions()
  local function action(key, order)
    return {
      name = "Create "..PRESETS[key].name.." tab",
      type = "execute",
      order = order,
      desc = function () return self:GetUnavailableReason(key) or "Add a dedicated tab and keep General's filters." end,
      disabled = function () return self:GetUnavailableReason(key) ~= nil end,
      func = function ()
        self:Create(key)
        Core.Libs.AceConfigRegistry:NotifyChange("Glassy")
      end,
    }
  end
  return {
    name = "Presets",
    type = "group",
    inline = true,
    order = 4,
    args = {
      description = {type = "description", width = "full", order = 1, name = function ()
        return self.status or "Add a dedicated tab and keep General's filters."
      end},
      guild = action("guild", 2),
      party = action("party", 3),
    },
  }
end
