local Core, Constants = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

local function canMove(frame)
  return not (_G.InCombatLockdown and _G.InCombatLockdown() and frame.IsProtected and frame:IsProtected())
end

local function publicNumber(value)
  return not (_G.issecretvalue and _G.issecretvalue(value)) and type(value) == "number"
end

local ANCHORS = {TOPLEFT = true, TOP = true, TOPRIGHT = true, LEFT = true, CENTER = true,
  RIGHT = true, BOTTOMLEFT = true, BOTTOM = true, BOTTOMRIGHT = true}

local function savedPosition(key)
  local saved = Core.db.profile[key]
  if type(saved) ~= "table" or not ANCHORS[saved.point] then return end
  for _, offset in ipairs({saved.x or 0, saved.y or 0}) do
    if type(offset) ~= "number" or offset ~= offset or offset == math.huge or offset == -math.huge then return end
  end
  return saved
end

function UIManager:PlaceNotificationMover(mover)
  if not canMove(mover) then return end
  local saved = savedPosition(mover.positionKey)
  mover:ClearAllPoints()
  if saved and saved.point then
    mover:SetPoint(saved.point, _G.UIParent, saved.point, saved.x or 0, saved.y or 0)
  else
    mover:SetPoint("BOTTOMLEFT", self.container, "TOPLEFT", 15, mover.defaultOffset)
  end
end

function UIManager:CreateNotificationMover(key, label, width, height, offset)
  local mover = _G.CreateFrame("Frame", nil, _G.UIParent)
  mover.positionKey, mover.defaultOffset = key, offset
  mover:SetSize(width, height)
  mover:SetClampedToScreen(true)
  self:PlaceNotificationMover(mover)
  local overlay = _G.CreateFrame("Frame", nil, mover)
  overlay:SetAllPoints()
  mover.overlay = overlay
  overlay:SetFrameStrata("DIALOG")
  overlay:EnableMouse(true)
  overlay:RegisterForDrag("LeftButton")
  mover:SetMovable(true)
  local background = overlay:CreateTexture(nil, "BACKGROUND")
  background:SetAllPoints()
  background:SetColorTexture(0.22, 0.62, 0.78, 0.5)
  local text = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  text:SetPoint("CENTER")
  text:SetText(Core:Localize(label))
  local reset = _G.CreateFrame("Button", nil, overlay, "UIPanelButtonTemplate")
  reset:SetPoint("TOPRIGHT", 0, 24)
  reset:SetSize(120, 22)
  reset:SetText(Core:Localize("Reset position"))
  local function place()
    self:PlaceNotificationMover(mover)
    if key == "voicePosition" then self:RefreshVoiceNotifications() end
  end
  reset:SetScript("OnClick", function ()
    Core.db.profile[key] = nil
    place()
  end)
  local function stop()
    if not mover.dragging then return end
    mover:StopMovingOrSizing()
    mover.dragging = nil
    local point, _, _, x, y = mover:GetPoint(1)
    Core.db.profile[key] = {point = point, x = x, y = y}
    place()
  end
  overlay:SetScript("OnDragStart", function ()
    if canMove(mover) then mover.dragging = true; mover:StartMoving() end
  end)
  overlay:SetScript("OnDragStop", stop)
  local function update()
    local editing = _G.EditModeManagerFrame and _G.EditModeManagerFrame:IsShown() and Core.db.profile.blizzardEditMode ~= false
    if not editing then stop() end
    overlay:SetShown(not not editing)
  end
  if _G.EditModeManagerFrame then
    _G.EditModeManagerFrame:HookScript("OnShow", update)
    _G.EditModeManagerFrame:HookScript("OnHide", update)
  end
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (changed)
    if changed == "blizzardEditMode" then update() end
    if changed == "framePosition" then place() end
  end)
  update()
  self.notificationMovers[#self.notificationMovers + 1] = mover
  return mover
end

function UIManager:AttachNotificationFrame(frame, mover)
  local placing, pending = false, false
  local function place()
    if placing or not canMove(frame) then return end
    placing = true
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, 0)
    placing = false
  end
  local function schedule()
    if placing or pending then return end
    pending = true
    _G.C_Timer.After(0, function () pending = false; place() end)
  end
  -- Wait until Blizzard finishes its anchoring pass before moving the container.
  _G.hooksecurefunc(frame, "SetPoint", schedule)
  frame:HookScript("OnShow", schedule)
  self.notificationPlacers[#self.notificationPlacers + 1] = place
  place()
end

function UIManager:RefreshVoiceNotifications()
  local manager = _G.VoiceActivityManager
  if not (manager and manager.GetChildren and self.voiceMover) then return end
  local notes = {manager:GetChildren()}
  local internal = {}
  for _, note in ipairs(notes) do
    if manager.notificationFrameToParentFrame and manager.notificationFrameToParentFrame[note] == manager then
      internal[note] = true
    end
  end
  self.internalVoiceNotes = internal
  for note in pairs(internal) do
    if not self.voiceNotes[note] then
      local state = {nativePoints = {}}
      self.voiceNotes[note] = state
      local moving, pending = false, false
      local function follow()
        if moving or not canMove(note) then return end
        local points = {}
        for index = 1, note:GetNumPoints() do points[index] = {note:GetPoint(index)} end
        for _, point in ipairs(points) do
          if point[2] == self.voiceMover then
            for _, native in ipairs(state.nativePoints) do
              if native[1] == point[1] then
                for index = 2, 5 do point[index] = native[index] end
                break
              end
            end
          end
        end
        state.nativePoints = points
        local saved = savedPosition("voicePosition")
        if not points[1] then return end
        moving = true
        note:ClearAllPoints()
        for _, point in ipairs(points) do
          local relativeTo = saved and not self.internalVoiceNotes[point[2]] and self.voiceMover or point[2]
          note:SetPoint(point[1], relativeTo, point[3], tonumber(point[4]) or 0, tonumber(point[5]) or 0)
        end
        moving = false
      end
      state.follow = follow
      _G.hooksecurefunc(note, "SetPoint", function ()
        if moving or pending then return end
        pending = true
        _G.C_Timer.After(0, function ()
          pending = false
          if self.internalVoiceNotes[note] then follow() end
        end)
      end)
    end
    self.voiceNotes[note].follow()
  end
end

function UIManager:StyleNotification(frame, key, restore)
  if not (frame and frame.GetRegions and frame.CreateTexture) then return end
  local state = self.notificationStyles[frame]
  local enabled = not restore and Core.db.profile[key]
  if state and not enabled then
    for region, saved in pairs(state.regions) do
      if saved.alpha then region:SetAlpha(saved.alpha) end
      if saved.font then region:SetFont(unpack(saved.font)) end
      if saved.color then region:SetTextColor(unpack(saved.color)) end
    end
    state.background:Hide()
    state.line:Hide()
    self.notificationStyles[frame] = nil
    return
  end
  if not enabled then return end
  local width = frame:GetWidth()
  if not publicNumber(width) or width <= 0 then return end
  if not state then
    state = {key = key, regions = {}}
    self.notificationStyles[frame] = state
    state.background = frame.glassyNotificationBackground or frame:CreateTexture(nil, "BACKGROUND", nil, -8)
    state.line = frame.glassyNotificationLine or frame:CreateTexture(nil, "ARTWORK")
    frame.glassyNotificationBackground, frame.glassyNotificationLine = state.background, state.line
    state.background:SetAllPoints()
    state.line:SetPoint("TOPLEFT")
    state.line:SetPoint("TOPRIGHT")
    state.line:SetHeight(1)
  end
  for _, region in ipairs({frame:GetRegions()}) do
    if region ~= state.background and region ~= state.line and not state.regions[region] then
      if region:IsObjectType("Texture") then
        local layer, regionWidth = region:GetDrawLayer(), region:GetWidth()
        if (layer == "BACKGROUND" or layer == "BORDER") and publicNumber(regionWidth) and regionWidth >= width * 0.6 then
          local alpha = region:GetAlpha()
          if publicNumber(alpha) then
            state.regions[region] = {alpha = alpha}
            region:SetAlpha(0)
          end
        end
      elseif region:IsObjectType("FontString") then
        local font, size, flags = region:GetFont()
        local red, green, blue, alpha = region:GetTextColor()
        if font and publicNumber(size) and publicNumber(red) and publicNumber(green) and publicNumber(blue) then
          state.regions[region] = {font = {font, size, flags}, color = {red, green, blue, alpha}}
        end
      end
    end
  end
  local font = Core.Libs.LSM:Fetch("font", Core.db.profile.font, true)
  local color = Core:GetThemeColor("tabTextColor")
  for region, saved in pairs(state.regions) do
    if saved.alpha then region:SetAlpha(0) end
    if saved.font and font then
      region:SetFont(font, saved.font[2], saved.font[3])
      if saved.color[1] * 0.2126 + saved.color[2] * 0.7152 + saved.color[3] * 0.0722 < 0.35 then
        region:SetTextColor(color.r, color.g, color.b, saved.color[4])
      end
    end
  end
  local background = Core.db.profile.chatBackgroundColor
  state.background:SetColorTexture(background.r, background.g, background.b, math.max(0.75, background.a))
  state.line:SetColorTexture(color.r, color.g, color.b, 0.55)
  state.background:Show()
  state.line:Show()
end

function UIManager:CollectNotifications()
  for _, entry in ipairs({{"BNToastFrame", "alertMover", "alertPosition", "Battle.net alerts", 10},
    {"ChatAlertFrame", "chatAlertMover", "chatAlertPosition", "Chat alerts", 10}}) do
    local frame = _G[entry[1]]
    if frame and not self[entry[2]] then
      local width, height = frame:GetSize()
      local mover = self:CreateNotificationMover(entry[3], entry[4], publicNumber(width) and math.max(250, width) or 250,
        publicNumber(height) and math.max(50, height) or 50, entry[5])
      self[entry[2]] = mover
      mover.overlay:ClearAllPoints()
      mover.overlay:SetPoint("BOTTOMLEFT", mover, "BOTTOMLEFT", 0, entry[2] == "chatAlertMover" and 26 or 0)
      mover.overlay:SetPoint("BOTTOMRIGHT", mover, "BOTTOMRIGHT", 0, entry[2] == "chatAlertMover" and 26 or 0)
      mover.overlay:SetHeight(24)
      self:AttachNotificationFrame(frame, mover)
    end
  end
  if _G.VoiceActivityManager and not self.voiceMover then
    self.voiceMover = self:CreateNotificationMover("voicePosition", "Voice chat", 200, 32, 140)
    local pending = false
    local function refresh()
      if pending then return end
      pending = true
      _G.C_Timer.After(0, function () pending = false; self:RefreshVoiceNotifications() end)
    end
    local manager = _G.VoiceActivityManager
    if manager.UpdateAlertNotificationVisibility then
      _G.hooksecurefunc(manager, "UpdateAlertNotificationVisibility", refresh)
    else
      manager:HookScript("OnEvent", refresh)
    end
  end
  self:RefreshVoiceNotifications()
  local function watch(frame, key)
    if not frame or self.watchedNotifications[frame] then return end
    self.watchedNotifications[frame] = key
    frame:HookScript("OnShow", function () self:StyleNotification(frame, key) end)
    frame:HookScript("OnHide", function ()
      local state = self.notificationStyles[frame]
      if state then
        self:StyleNotification(frame, key, true)
      end
    end)
    self:StyleNotification(frame, key)
  end
  watch(_G.BNToastFrame, "notificationStyle")
  local alerts = _G.AlertFrame
  if alerts and alerts.AddAlertFrame and not self.gameAlertsHooked then
    self.gameAlertsHooked = true
    _G.hooksecurefunc(alerts, "AddAlertFrame", function (_, frame) watch(frame, "alertStyle"); self:StyleNotification(frame, "alertStyle") end)
  end
end

function UIManager:InitializeNotifications()
  self.notificationMovers, self.notificationPlacers, self.voiceNotes = {}, {}, {}
  self.notificationStyles, self.watchedNotifications = {}, {}
  local events = _G.CreateFrame("Frame")
  events:RegisterEvent("ADDON_LOADED")
  events:RegisterEvent("PLAYER_REGEN_ENABLED")
  events:SetScript("OnEvent", function ()
    self:CollectNotifications()
    for _, place in ipairs(self.notificationPlacers) do place() end
  end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "notificationStyle" or key == "alertStyle" or key == "font" or key == "tabTextColor" or key == "chatBackgroundColor" then
      for frame, style in pairs(self.watchedNotifications) do self:StyleNotification(frame, style) end
    end
  end)
  self:CollectNotifications()
end
