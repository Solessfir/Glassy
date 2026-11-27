local Core, Constants = unpack(select(2, ...))
local UIManager = Core:GetModule("UIManager")

-- luacheck: push ignore 113
local C_Timer = C_Timer
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc
-- luacheck: pop

local function getPoints(frame)
  if not (frame.GetNumPoints and frame.GetPoint and frame.ClearAllPoints and frame.SetPoint) then return end
  local points = {}
  for index = 1, frame:GetNumPoints() do
    local point, relative, relativePoint, x, y = frame:GetPoint(index)
    if not (point and relative and relativePoint) then return end
    points[index] = {point, relative, relativePoint, x or 0, y or 0}
  end
  return #points > 0 and points or nil
end

local function hasPoints(frame, points)
  local current = getPoints(frame)
  if not current or #current ~= #points then return false end
  for index, point in ipairs(points) do
    for field = 1, 5 do
      if current[index][field] ~= point[field] then return false end
    end
  end
  return true
end

local function setPoints(frame, points)
  frame:ClearAllPoints()
  for _, point in ipairs(points) do frame:SetPoint(unpack(point)) end
end

local strataOrder = {BACKGROUND = 1, LOW = 2, MEDIUM = 3, HIGH = 4, DIALOG = 5,
  FULLSCREEN = 6, FULLSCREEN_DIALOG = 7, TOOLTIP = 8}

local function raiseFrame(frame, renderer, layers)
  if not (frame and frame.GetFrameLevel and frame.SetFrameLevel and frame.GetFrameStrata and frame.SetFrameStrata
    and renderer.GetFrameLevel and renderer.GetFrameStrata) then return end
  local strata, target = frame:GetFrameStrata(), renderer:GetFrameStrata()
  local layer = {frame = frame}
  if strataOrder[strata] and strataOrder[target] and strataOrder[strata] < strataOrder[target] then
    layer.strata, layer.appliedStrata = strata, target
    frame:SetFrameStrata(target)
  end
  if frame:GetFrameStrata() == target and frame:GetFrameLevel() <= renderer:GetFrameLevel() then
    layer.level, layer.appliedLevel = frame:GetFrameLevel(), renderer:GetFrameLevel() + 1
    frame:SetFrameLevel(layer.appliedLevel)
  end
  layers[#layers + 1] = layer
end

local function releaseFrame(record)
  local frame = record.frame
  -- Native Details releases and re-embeds own their new anchors and dimensions.
  if frame:GetParent() == record.chatFrame and hasPoints(frame, record.points) then
    setPoints(frame, record.originalPoints)
    if record.width then frame:SetSize(record.width, record.height) end
  end
  if frame:IsIgnoringParentAlpha() ~= record.ignoreAlpha then frame:SetIgnoreParentAlpha(record.ignoreAlpha) end
  for _, layer in ipairs(record.layers) do
    if layer.strata and layer.frame:GetFrameStrata() == layer.appliedStrata then layer.frame:SetFrameStrata(layer.strata) end
    if layer.level and layer.frame:GetFrameLevel() == layer.appliedLevel then layer.frame:SetFrameLevel(layer.level) end
  end
end

local function reconcileNative(renderer)
  local frame = renderer.chatFrame
  local hooks = renderer.hooks and renderer.hooks[frame]
  if not (frame.isDocked and hooks and hooks.Show and hooks.Hide) then return end
  local selected = _G.GENERAL_CHAT_DOCK and _G.GENERAL_CHAT_DOCK.selected == frame
  local shown = not not (renderer.detailsEmbedHost and selected)
  if frame:IsShown() ~= shown then hooks[shown and "Show" or "Hide"](frame) end
end

local function releaseRenderer(renderer)
  renderer.detailsEmbedHost = nil
  if renderer.viewport and renderer.detailsEmbedViewportShown then renderer.viewport:Show() end
  if renderer.overlay and renderer.detailsEmbedOverlayShown and renderer.state and not renderer.state.scrollAtBottom then
    renderer.overlay:Show()
  end
  renderer.detailsEmbedViewportShown = nil
  renderer.detailsEmbedOverlayShown = nil
  reconcileNative(renderer)
end

function UIManager:ResizeDetailsEmbed(renderer)
  local state = self.detailsEmbedState
  if not (state and state.renderer == renderer and renderer.detailsEmbedHost) then return end
  local width, height = renderer.config.width, renderer.config.height
  if not (type(width) == "number" and width > 0 and type(height) == "number" and height > 0) then return end
  state.host:SetSize(width, height)
  for _, record in ipairs(state.frames) do
    if record.width and record.frame:GetParent() == record.chatFrame and hasPoints(record.frame, record.points) then
      record.frame:SetSize(math.max(1, record.width + (width - record.backgroundWidth) / 2),
        math.max(1, record.height + height - record.backgroundHeight))
    end
  end
end

function UIManager:SyncDetailsEmbedSelection()
  local state = self.detailsEmbedState
  local dock = _G.GENERAL_CHAT_DOCK
  local selected = dock and dock.selected
  if state then
    for _, record in ipairs(state.frames) do
      local frame = record.frame
      local visible = selected == record.chatFrame
      if frame:GetParent() == record.chatFrame and frame:IsIgnoringParentAlpha() ~= visible then
        frame:SetIgnoreParentAlpha(visible)
      end
    end
  end

  local details = _G.Details
  local settings = details and details.chat_tab_embed
  local chatFrame = Core.db.profile.detailsChatEmbed == true and settings and settings.enabled and details.chat_tab_embed_onframe
  local hidden = self.detailsHiddenFrames or {}
  self.detailsHiddenFrames = hidden
  for frame, owner in pairs(hidden) do
    if frame:GetParent() ~= owner then
      hidden[frame] = nil
    elseif owner ~= chatFrame or selected == owner then
      hidden[frame] = nil
      frame:Show()
    end
  end
  if not (chatFrame and chatFrame.isDocked and chatFrame ~= selected and type(details.GetInstance) == "function") then return end

  -- Details can show an embedded window on reload before it has stock anchors for Glassy to adopt.
  local hooks = self.detailsVisibilityHooks or {}
  self.detailsVisibilityHooks = hooks
  for index = 1, settings.single_window and 1 or 2 do
    local instance = details:GetInstance(index)
    local frame = instance and instance.baseframe
    if frame and frame:GetParent() == chatFrame and frame.IsShown then
      if not hooks[frame] and frame.HookScript then
        hooks[frame] = true
        frame:HookScript("OnShow", function () self:SyncDetailsEmbedSelection() end)
      end
      if frame:IsShown() then
        hidden[frame] = chatFrame
        frame:Hide()
      end
    end
  end
end

function UIManager:RefreshDetailsEmbed()
  self:HookDetailsEmbed()
  self:SyncDetailsEmbedSelection()
  local details = _G.Details
  local settings = details and details.chat_tab_embed
  if self.detailsStartupAlpha and (Core.db.profile.detailsChatEmbed ~= true
    or not (settings and settings.enabled) or details.chat_tab_embed_onframe) then
    self:EndDetailsStartupWait()
  end
  local chatFrame = settings and settings.enabled and details.chat_tab_embed_onframe
  local window = chatFrame and self:GetChatWindow(chatFrame)
  local renderer = window and window.slidingMessageFrame
  if Core.db.profile.detailsChatEmbed ~= true or not (window and renderer and renderer.viewport
    and renderer.config and chatFrame.isDocked and chatFrame ~= _G.ChatFrame2
    and not window.temporary and not chatFrame.isTemporary and not window.secondaryGroup
    and not renderer.detachedGroup and not renderer.detachedContainer
    and not (renderer.state and renderer.state.isCombatLog) and type(details.GetInstance) == "function") then
    renderer = nil
  end

  local state = self.detailsEmbedState
  if state then
    local retained = {}
    for _, record in ipairs(state.frames) do
      if state.renderer == renderer and record.frame:GetParent() == chatFrame and hasPoints(record.frame, record.points)
        and (not settings.single_window or record.index == 1) then
        retained[#retained + 1] = record
      else
        releaseFrame(record)
      end
    end
    state.frames = retained
    if state.renderer ~= renderer then
      releaseRenderer(state.renderer)
      self.detailsEmbedState, state = nil, nil
    end
  end

  if not renderer then return end
  local background = _G[chatFrame:GetName().."Background"]
  if not background then
    if state and #state.frames == 0 then
      releaseRenderer(renderer)
      self.detailsEmbedState = nil
    end
    return
  end
  local candidates = {}
  for index = 1, settings.single_window and 1 or 2 do
    local instance = details:GetInstance(index)
    local frame = instance and instance.baseframe
    local exists = false
    if state then
      for _, record in ipairs(state.frames) do if record.frame == frame then exists = true end end
    end
    if frame and not exists and frame:GetParent() == chatFrame and frame.IsIgnoringParentAlpha and frame.SetIgnoreParentAlpha then
      local points = getPoints(frame)
      local stock = points and #points == (settings.single_window and 2 or 1)
      if points then
        for pointIndex, point in ipairs(points) do
          local corner = settings.single_window and (pointIndex == 1 and "TOPLEFT" or "BOTTOMRIGHT")
            or (index == 1 and "TOPLEFT" or "TOPRIGHT")
          if point[2] ~= background or string.upper(point[1]) ~= corner or string.upper(point[3]) ~= corner then stock = false end
        end
      end
      if stock then
        local record = {frame = frame, chatFrame = chatFrame, index = index, originalPoints = points,
          ignoreAlpha = frame:IsIgnoringParentAlpha(), rowframe = instance.rowframe, layers = {}}
        if not settings.single_window then
          if frame.GetSize and frame.SetSize and background.GetSize then
            record.width, record.height = frame:GetSize()
            record.backgroundWidth, record.backgroundHeight = background:GetSize()
          end
          if not (record.width and record.height and record.backgroundWidth and record.backgroundHeight) then record = nil end
        end
        if record then candidates[#candidates + 1] = record end
      end
    end
  end

  if not state and #candidates == 0 then return end
  if not state then
    local host = renderer.detailsEmbedAnchor
    if not host then
      host = CreateFrame("Frame", nil, renderer)
      host:SetPoint("TOPLEFT", renderer, "TOPLEFT")
      renderer.detailsEmbedAnchor = host
    end
    state = {renderer = renderer, host = host, frames = {}}
    self.detailsEmbedState = state
  end
  for _, record in ipairs(candidates) do
    record.points = {}
    for index, point in ipairs(record.originalPoints) do
      record.points[index] = {point[1], state.host, point[3], point[4], point[5]}
    end
    setPoints(record.frame, record.points)
    raiseFrame(record.frame, renderer, record.layers)
    raiseFrame(record.rowframe, renderer, record.layers)
    state.frames[#state.frames + 1] = record
  end
  if #state.frames == 0 then
    releaseRenderer(renderer)
    self.detailsEmbedState = nil
    return
  end
  if not renderer.detailsEmbedHost then
    renderer.detailsEmbedViewportShown = renderer.viewport:IsShown()
    renderer.detailsEmbedOverlayShown = renderer.overlay and renderer.overlay:IsShown()
    renderer.detailsEmbedHost = true
    renderer.viewport:Hide()
    if renderer.overlay then renderer.overlay:QuickHide() end
  end
  self:ResizeDetailsEmbed(renderer)
  self:SyncDetailsEmbedSelection()
  reconcileNative(renderer)
end

function UIManager:ScheduleDetailsEmbed()
  if self.detailsEmbedScheduled then return end
  self.detailsEmbedScheduled = true
  C_Timer.After(0, function ()
    self.detailsEmbedScheduled = nil
    self:RefreshDetailsEmbed()
  end)
end

function UIManager:HookDetailsEmbed()
  local embed = _G.Details and _G.Details.chat_embed
  if not (embed and type(hooksecurefunc) == "function") then return end
  self.detailsEmbedHooks = self.detailsEmbedHooks or {}
  local hooks = self.detailsEmbedHooks[embed] or {}
  self.detailsEmbedHooks[embed] = hooks
  for _, method in ipairs({"DoEmbed", "ReleaseEmbed", "SetTabSettings"}) do
    if not hooks[method] and type(embed[method]) == "function" then
      hooksecurefunc(embed, method, function () self:ScheduleDetailsEmbed() end)
      hooks[method] = true
    end
  end
end

local function getDetailsStartupTarget(manager)
  local details = _G.Details
  local settings = details and details.chat_tab_embed
  local embed = details and details.chat_embed
  if Core.db.profile.detailsChatEmbed ~= true or not (settings and settings.enabled and not details.chat_tab_embed_onframe
    and type(settings.tab_name) == "string" and settings.tab_name ~= "" and embed
    and type(embed.GetTab) == "function" and type(embed.DoEmbed) == "function") then return end
  local chatFrame = embed:GetTab(settings.tab_name)
  local window = chatFrame and manager:GetChatWindow(chatFrame)
  -- Details clears the target tab's message groups. Only recover a dedicated docked tab.
  if window and chatFrame.isDocked and chatFrame ~= _G.ChatFrame1 and chatFrame ~= _G.ChatFrame2
    and not chatFrame.isTemporary and not window.temporary and not window.secondaryGroup then
    return details, settings, embed
  end
end

function UIManager:BeginDetailsStartupWait()
  local details, settings = getDetailsStartupTarget(self)
  if not (details and type(details.GetInstance) == "function") then return end
  self.detailsStartupAlpha = {}
  for index = 1, settings.single_window and 1 or 2 do
    local instance = details:GetInstance(index)
    local frame = instance and instance.baseframe
    if frame and frame:GetParent() == _G.UIParent and frame.GetAlpha and frame.SetAlpha then
      self.detailsStartupAlpha[frame] = frame:GetAlpha()
      frame:SetAlpha(0)
    end
  end
end

function UIManager:EndDetailsStartupWait()
  if not self.detailsStartupAlpha then return end
  for frame, alpha in pairs(self.detailsStartupAlpha) do
    if frame:GetAlpha() == 0 then frame:SetAlpha(alpha) end
  end
  self.detailsStartupAlpha = nil
end

function UIManager:RecoverDetailsStartupEmbed()
  local details, _, embed = getDetailsStartupTarget(self)
  if not details then return end
  local ok, err = pcall(embed.DoEmbed, embed)
  if not ok then
    self.detailsStartupResult = tostring(err)
  else
    self.detailsStartupResult = details.chat_tab_embed_onframe and "Attached" or "Details did not attach"
  end
  self:RefreshDetailsEmbed()
end

function UIManager:InitializeDetailsEmbed()
  if self.detailsEmbedEvents then return end
  self.detailsEmbedEvents = CreateFrame("Frame")
  self.detailsEmbedEvents:RegisterEvent("ADDON_LOADED")
  self.detailsEmbedEvents:RegisterEvent("PLAYER_ENTERING_WORLD")
  self.detailsEmbedEvents:SetScript("OnEvent", function (_, event)
    self:ScheduleDetailsEmbed()
    if event == "PLAYER_ENTERING_WORLD" then
      self.detailsEmbedEvents:UnregisterEvent(event)
      -- Details defers its own startup attach by five seconds.
      self:BeginDetailsStartupWait()
      C_Timer.After(6, function ()
        self:EndDetailsStartupWait()
        self:RecoverDetailsStartupEmbed()
      end)
    end
  end)
  if type(_G.FCFDock_SelectWindow) == "function" and type(hooksecurefunc) == "function" then
    hooksecurefunc("FCFDock_SelectWindow", function (dock)
      if dock == _G.GENERAL_CHAT_DOCK then self:SyncDetailsEmbedSelection() end
    end)
  end
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == nil or key == "detailsChatEmbed" then self:RefreshDetailsEmbed() end
  end)
  self:RefreshDetailsEmbed()
end
