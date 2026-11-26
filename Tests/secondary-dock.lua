local function noop() end
local pending = {}
C_Timer = {After = function (_, callback) pending[#pending + 1] = callback end}

local function frame(width)
  local f = {width = width or 0, points = {}, scripts = {}}
  function f:SetParent(parent) self.parent = parent end
  function f:GetWidth() return self.width end
  function f:SetWidth(value) self.width = value end
  function f:SetSize(value) self.width = value end
  function f:SetPoint(...) self.points[#self.points + 1] = {...} end
  function f:ClearAllPoints() self.points = {} end
  function f:SetScript(event, callback) self.scripts[event] = callback end
  function f:SetScrollChild(child) self.child = child end
  function f:GetHorizontalScroll() return self.scroll or 0 end
  function f:SetHorizontalScroll(value) self.scroll = value end
  function f:GetFrameStrata() return "MEDIUM" end
  function f:GetFontString() return {SetTextColor = noop} end
  function f:Show() self.shown = true end
  function f:Hide() self.shown = false end
  function f:SetShown(value) self.shown = value end
  f.SetHeight, f.SetFrameStrata, f.SetNormalFontObject, f.SetText = noop, noop, noop, noop
  return f
end
CreateFrame = function (_, _, parent)
  local f = frame()
  f.parent = parent
  return f
end
local core = {
  Components = {},
  db = {profile = {headerBackgroundColor = {a = 1}}},
  GetThemeColor = function () return {r = 1, g = 1, b = 1} end,
}
assert(loadfile("Glassy/Components/DetachedChatDock.lua"))("Glassy", {core, {DOCK_HEIGHT = 20, EVENTS = {}}})
local function dock(width)
  local f = frame(width)
  for key, method in pairs(core.Components.DetachedChatDockMixin) do f[key] = method end
  f.messageSeparator = {SetSeparatorColor = noop}
  f.SetGradientBackground = noop
  return f
end
local first, second, third = frame(60), frame(70), frame(80)
for _, tab in ipairs({first, second, third}) do
  tab.chatFrame = {}
  tab.UpdateVisualState = function (self) self.styled = (self.styled or 0) + 1 end
end

local d = dock(150)
d:SetTabs({first, second, third}, third)
assert(d.selected == third.chatFrame and d.selectedTab == third)
assert(first.glassySecondaryDock == d and second.glassySecondaryDock == d)
assert(first.parent == d.scrollFrame.child and third.parent == first.parent)
assert(first.points[1][4] == 0 and second.points[1][4] == 61 and third.points[1][4] == 132)
assert(d.scrollButtons[1].shown and d.scrollButtons[2].shown)
assert(d.scrollFrame.scroll == 102, "Selected tab was not scrolled fully into view")
d.scrollButtons[1].scripts.OnClick()
assert(d.scrollFrame.scroll == 47, "Left overflow button did not scroll")
d.scrollButtons[2].scripts.OnClick()
assert(d.scrollFrame.scroll == 102, "Right overflow button did not scroll")

third.width = 100
d:ScheduleTabOrder()
d:ScheduleTabOrder()
assert(#pending == 1, "Tab changes scheduled duplicate layouts")
pending[1]()
assert(d.scrollFrame.scroll == 122, "Resized selected tab was clipped")
d.width = 300
d:UpdateTabOrder()
assert(d.scrollFrame.scroll == 0 and not d.scrollButtons[1].shown)

local other = dock(200)
other:SetTabs({third}, third)
d:UpdateTabOrder()
assert(third.parent == other.scrollFrame.child, "Old group stole a moved tab")
d:SetTab(first)
assert(d.tabs == nil and d.tab == first and first.parent == d)
assert(first.glassySecondaryDock == nil and second.glassySecondaryDock == nil)
assert(third.glassySecondaryDock == other and not d.scrollFrame.shown)
other:SetTabs({})
assert(third.glassySecondaryDock == nil and other.selected == nil)
print("PASS: secondary dock orders, scrolls, resizes, and releases grouped tabs")
