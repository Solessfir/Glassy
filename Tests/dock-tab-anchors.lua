-- Run from the repository root with Lua 5.1 and the bundled AceHook library.
local function noop() end
strmatch = string.match
issecurevariable = function () return false end
local postHooks = {}
hooksecurefunc = function (object, method, callback)
  if type(object) == "string" then callback, method, object = method, object, _G end
  local fn = object[method]
  postHooks[fn] = postHooks[fn] or {}
  table.insert(postHooks[fn], callback)
end
local function native(fn)
  local wrapper
  wrapper = function (...)
    fn(...)
    for _, callback in ipairs(postHooks[wrapper] or {}) do callback(...) end
  end
  return wrapper
end
dofile("libs/LibStub/LibStub.lua")
dofile("libs/AceHook-3.0/AceHook-3.0.lua")
local AceHook = LibStub("AceHook-3.0")

local function depends(node, target, seen)
  if node == target then return true end
  if not node or seen[node] then return false end
  seen[node] = true
  if depends(node.parent, target, seen) then return true end
  for _, point in pairs(node.points) do
    if depends(point[2], target, seen) then return true end
  end
  return false
end
local function frame(name, parent, width)
  local f = {name = name, parent = parent, points = {}, width = width or 40, scripts = {}}
  function f:GetName() return self.name end
  function f:GetParent() return self.parent end
  function f:ClearAllPoints() self.points = {} end
  function f:SetParent(p) self.parent = p end
  function f:GetWidth() return self.width end
  function f:SetWidth(w) self.width = w end
  function f:SetScript(key, callback) self.scripts[key] = callback end
  function f:GetNumPoints() local n = 0; for _ in pairs(self.points) do n = n + 1 end; return n end
  function f:GetPoint(index)
    local n = 0
    for _, point in pairs(self.points) do n = n + 1; if n == index then return unpack(point) end end
  end
  function f:GetHorizontalScroll() return self.scroll or 0 end
  function f:SetHorizontalScroll(v) self.scroll = v end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:SetShown(shown) self.shown = shown end
  function f:IsShown() return self.shown end
  f.SetHeight, f.SetFrameStrata, f.SetSeparatorColor = noop, noop, noop
  f.SetPoint = native(function (self, point, relative, relativePoint, x, y)
    assert(not depends(relative, self, {}), "Cannot anchor to a region dependent on it: "..self.name)
    self.points[point] = {point, relative, relativePoint, x, y}
  end)
  return f
end

FCFDock_GetSelectedWindow = function (dock) return dock.selected end
FCFDock_SelectWindow = native(function (dock, chat) dock.selected = chat end)
-- Native static/dynamic tab anchoring order from FloatingChatFrame.lua's FCFDock_UpdateTabs.
FCFDock_UpdateTabs = native(function (dock)
  local static, dynamic
  for _, chat in ipairs(dock.DOCKED_CHAT_FRAMES) do
    local tab = _G[chat:GetName().."Tab"]
    tab:ClearAllPoints()
    tab:Show()
    if chat.isStaticDocked then
      tab:SetParent(dock)
      if static then tab:SetPoint("LEFT", static, "RIGHT", 1, 0)
      else tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0) end
      static = tab
    else
      tab:SetParent(dock.scrollFrame.child)
      tab:SetPoint("LEFT", dynamic or dock.scrollFrame.child, dynamic and "RIGHT" or "LEFT", 1, 0)
      dynamic = tab
    end
  end
  if static then
    dock.scrollFrame:SetPoint("LEFT", static, "RIGHT", 0, 0)
    dock.scrollFrame:SetPoint("BOTTOMRIGHT", dock, "BOTTOMRIGHT", 0, -1)
  end
end)

local function scenario(env, width, reverse, hidden, staleAnchor)
  local dock = frame("dock", nil, width)
  GENERAL_CHAT_DOCK = dock
  local core = {
    Components = {CreateSeparatorFrame = function () return frame("separator") end},
    Libs = {AceHook = AceHook},
    db = {profile = {frameWidth = width, combatLogHidden = hidden,
      headerBackgroundColor = {a = 1}, tabOrder = reverse and {"ChatFrame11", "ChatFrame1", "ChatFrame2"} or {}}},
    GetThemeColor = function () return {} end,
    Subscribe = noop,
  }
  local constants = {ENV = env, DOCK_HEIGHT = 20, EVENTS = {}}
  local utils = {}
  assert(loadfile("Glassy/utils.lua"))("Glassy", {core, constants, utils})
  assert(loadfile("Glassy/Components/ChatDock.lua"))("Glassy", {core, constants, utils})
  assert(loadfile("Glassy/Components/ChatDockTabs.lua"))("Glassy", {core, constants, utils})
  for key, value in pairs(core.Components.ChatDockMixin) do dock[key] = value end
  for _, method in ipairs({"UpdateFadeSettings", "StyleOverflowButton", "UpdateTabVisualStates",
    "SetGradientBackground", "QuickHide", "QuickShow"}) do dock[method] = noop end
  AceHook:Embed(dock)
  dock.scrollFrame = frame("scrollFrame", dock)
  dock.scrollFrame.child = frame("child", dock.scrollFrame)
  dock.overflowButton = frame("overflow", dock, 16)
  dock.overflowButton.list = frame("list", dock.overflowButton)
  local general, combat, whisper = frame("ChatFrame1"), frame("ChatFrame2"), frame("ChatFrame11")
  general.isStaticDocked, combat.isStaticDocked = true, true
  ChatFrame1, ChatFrame2 = general, combat
  dock.DOCKED_CHAT_FRAMES, dock.selected = {general, combat, whisper}, general
  for _, chat in ipairs(dock.DOCKED_CHAT_FRAMES) do
    _G[chat:GetName().."Tab"] = frame(chat:GetName().."Tab", dock)
  end
  FCFDock_UpdateTabs(dock)
  dock:Init(frame("container"))
  -- Restoring another whisper docks a new dynamic tab before Blizzard updates the dock.
  local restored = frame("ChatFrame12")
  ChatFrame12Tab = frame("ChatFrame12Tab", dock)
  table.insert(dock.DOCKED_CHAT_FRAMES, restored)
  -- Repeated native updates restore static tabs before Glassy's secure post-hook lays them out again.
  for _ = 1, 2 do
    FCFDock_UpdateTabs(dock)
    assert(ChatFrame1Tab.parent == dock.scrollFrame.child)
    assert(ChatFrame2Tab.shown == not hidden)
    assert(ChatFrame2Tab.parent == (hidden and dock or dock.scrollFrame.child))
    assert(dock.scrollFrame.points.LEFT[2] == dock)
    assert(dock.overflowButton.shown == (width < (hidden and 122 or 163)))
  end
  if staleAnchor then
    -- Separate defensive case: another anchor still refers to a hidden static tab.
    ChatFrame1Tab:ClearAllPoints()
    ChatFrame1Tab:SetParent(dock)
    ChatFrame1Tab:SetPoint("BOTTOMLEFT", dock, "BOTTOMLEFT", 0, 0)
    ChatFrame2Tab:ClearAllPoints()
    ChatFrame2Tab:SetParent(dock)
    ChatFrame2Tab:SetPoint("LEFT", ChatFrame1Tab, "RIGHT", 1, 0)
    dock.scrollFrame:SetPoint("BOTTOMLEFT", ChatFrame2Tab, "RIGHT", 0, 0)
  end
  dock:LayoutDockedTabs(dock:GetOrderedDockFrames(), false, {index = 2, width = 40})
  assert(dock.scrollFrame.points.BOTTOMLEFT == nil)
  assert(dock.scrollFrame.scroll >= 0)
  dock:UnhookAll()
end
for _, env in ipairs({"retail", "classic"}) do
  for _, width in ipairs({300, 60}) do
    for _, reverse in ipairs({false, true}) do
      for _, hidden in ipairs({false, true}) do scenario(env, width, reverse, hidden) end
      scenario(env, width, reverse, true, true)
    end
  end
end
print("PASS: native dock updates through real AceHook hooks, hidden/visible combat tabs, saved order, overflow, drag gaps, and stale anchors")
