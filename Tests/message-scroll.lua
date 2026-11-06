-- Run from the repository root with Lua 5.1.
local function noop() end
GetServerTime = function () return 0 end
GetTime = function () return 0 end
C_Timer = {NewTimer = function () return {Cancel = noop} end}
CreateFrame, CreateObjectPool, Mixin = noop, noop, noop

local eases = {}
local core = {
  Libs = {AceHook = {}, LibEasing = {
    OutCubic = noop,
    Ease = function (_, _, start, finish, duration)
      eases[#eases + 1] = {start = start, finish = finish, duration = duration}
      return #eases
    end,
    StopEasing = noop,
  }},
  Components = {},
  db = {profile = {chatSlideInDuration = 0.5, chatHoldTime = 10, scrollbackLines = 500}},
  defaults = {profile = {scrollbackLines = 500}},
  GetModule = function () return {ProcessText = function (_, text) return text end, QueueFrameForUpdate = noop} end,
}
assert(loadfile("Glassy/Components/SlidingMessageFrame.lua"))("Glassy", {core, {DOCK_HEIGHT = 20, EVENTS = {}}, {}})

-- Rows model the engine's anchor rule: a link that reaches back to its own row is an error.
local function createRow(height)
  local row = {glassyHeight = height, text = {ClearText = noop, SetFontObject = noop, SetTextColor = noop}}
  function row:IsChainedTo(target, relativePoint, point)
    return self.chained and self.target == target and self.relativePoint == relativePoint and self.point == point
  end
  function row:ClearChainAnchor() self.chained, self.target, self.relativePoint, self.point = nil, nil, nil, nil end
  function row:SetChainAnchor(target, relativePoint, point)
    local node = target
    while node do
      assert(node ~= self, "Anchor cycle")
      node = node.target
    end
    self.chained, self.target, self.relativePoint, self.point = true, target, relativePoint, point
  end
  row.SetDisplayText, row.UpdateFrame, row.Show = noop, noop, noop
  row.IsVisible = function () return false end
  return row
end

local nextHeights = {}
local view = setmetatable({}, {__index = core.Components.SlidingMessageFrameMixin})
view.config = {height = 200, overflowHeight = 60}
view.state = {messages = {}, incomingMessages = {}, incomingScrollbackMessages = {}, scrollIndex = 1, messageOffset = 0,
  slideOffset = 0, scrollAtBottom = true}
view.slider = {ClearAllPoints = noop, SetPoint = function (self, _, _, _, _, y) self.y = y end}
view.overlay = {Show = noop, Hide = noop, HideDelay = noop, ShowNewMessageAlert = noop, HideNewMessageAlert = noop}
view.messageFramePool = {
  Acquire = function () return createRow(table.remove(nextHeights, 1)) end,
  Release = function (_, row) row:ClearChainAnchor() end,
}
view.CancelDynamicEditBoxLayout, view.UpdateViewportHeight = noop, noop

local function receive(...)
  local incoming = {}
  for index = 1, select("#", ...) do
    nextHeights[index] = select(index, ...)
    incoming[index] = {nil, "line"}
  end
  view:Update(incoming, false)
end

receive(20, 20, 40)
local messages = view.state.messages
assert(messages[3].target == nil and messages[3].point == "BOTTOMLEFT", "Newest row sits on the bottom edge")
assert(messages[2].target == messages[3] and messages[1].target == messages[2], "Older rows stack upwards")
assert(eases[#eases].start == -80, "A readable batch slides in by its height")

view:SetScrollPosition(2, 0)
assert(not view.state.scrollAtBottom and messages[2].target == nil, "Scrolling pins the selected row")
assert(messages[3].target == messages[2] and messages[3].point == "TOPLEFT", "Newer rows hang below the pinned row")
assert(view:GetDistanceToBottom() == 40)

-- A secret row arriving while scrolled back must not move the row being read.
local pinned = messages[2]
receive(nil)
assert(messages[#messages - view.state.scrollIndex + 1] == pinned and pinned.target == nil,
  "New lines must not shift the pinned row")
assert(view:GetDistanceToBottom() == nil, "Secret rows make the jump distance unknown")
local easeCount = #eases
view:SnapToBottom()
assert(#eases == easeCount and view.slider.y == 0, "Unknown distances snap without animating")
assert(view.state.scrollAtBottom and messages[#messages].target == nil)

-- Batches containing secret text skip the slide instead of guessing its height.
receive(20, nil)
assert(#eases == easeCount and view.slider.y == 0, "Secret batches must not slide")

-- Trimming history while scrolled back keeps the selected row pinned.
view:SetScrollPosition(3, 0)
pinned = messages[#messages - 2]
view:ReleaseOldestMessages(2)
view:SetScrollPosition(view.state.scrollIndex, view.state.messageOffset)
assert(view.state.messages[#view.state.messages - 2] == pinned and pinned.target == nil)

-- Shift-scrolling pans within the pinned row.
view:SetScrollPosition(3, 30)
assert(view.slider.y == -30 and not view.state.scrollAtBottom)
view:SetScrollPosition(1, 0)
assert(view.state.scrollAtBottom and view.slider.y == 0)
print("PASS: per-message scrolling pins the read row and never needs secret heights")
