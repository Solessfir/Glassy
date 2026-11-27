-- Run from the repository root with Lua 5.1.
local timers, active, combat = {}, "plugin:Glassy:general", false
C_Timer = {After = function (_, callback) timers[#timers + 1] = callback end}
local function flush()
  local pending = timers
  timers = {}
  for _, callback in ipairs(pending) do callback() end
end
InCombatLockdown = function () return combat end
local module = {optionsRegistered = true}
local core = {GetModule = function () return module end}
assert(loadfile("Glassy/Modules/EllesmereOptions.lua"))("Glassy", {core, {EVENTS = {}}, {}})

local offset, rowTop, rowBottom, updates, writes = 0, 450, 478, 0, 0
local shown, laidOut = true, true
local range = 500
local row = {_folder = active, IsShown = function () return true end,
  GetTop = function () if laidOut then return 1000 - rowTop end end,
  GetBottom = function () if laidOut then return 1000 - rowBottom end end}
local scroll = {
  IsVisible = function () return shown end,
  GetVerticalScroll = function () return offset end,
  GetHeight = function () return 200 end,
  GetVerticalScrollRange = function () return range end,
  SetVerticalScroll = function (_, value) offset = value; writes = writes + 1 end,
  GetScript = function (_, event)
    assert(event == "OnScrollRangeChanged")
    return function () updates = updates + 1 end
  end,
}
local firstOpen = true
EllesmereUI = {
  OpenPlugin = function (id, key)
    assert(id == "Glassy" and key == "general")
    if firstOpen then
      firstOpen, shown = false, false
      C_Timer.After(0, function () shown = true end)
    end
    return true
  end,
  GetPluginModuleKey = function () return "plugin:Glassy:general" end,
  GetActiveModule = function () return active end,
  _addonScrollFrame = scroll,
  _addonScrollChild = {GetChildren = function () return row end, GetTop = function () return 1000 end},
}
assert(module:OpenOptions() and offset == 0, "Opening waits for EUI's deferred panel construction")
flush()
assert(offset == 278 and updates == 1, "The selected row scrolls fully into view and updates the native thumb")
assert(module:OpenOptions())
flush()
assert(offset == 278 and writes == 1, "A fully visible row preserves the sidebar position")

offset, rowTop, rowBottom = 400, 100, 128
module:OpenOptions()
flush()
assert(offset == 100, "A row above the viewport is revealed")
offset, rowTop, rowBottom = 0, 700, 728
module:OpenOptions()
flush()
assert(offset == 500, "The requested offset is clamped to the native range")

offset, rowTop, rowBottom = 0, 450, 478
module:OpenOptions()
active = "plugin:Other:general"
flush()
assert(offset == 0, "Manual navigation before the deferred callback does not scroll another module")
active = row._folder
shown = false
module:OpenOptions()
flush()
assert(offset == 0, "A panel closed before the callback stays untouched")
shown, laidOut = true, false
module:OpenOptions()
flush()
assert(offset == 0 and #timers == 1, "An unpositioned row gets one layout retry")
laidOut = true
flush()
assert(offset == 278)

offset, range = 0, 0
module:OpenOptions()
flush()
assert(offset == 0 and #timers == 1, "A sidebar whose scroll range is not ready gets a retry")
range = 500
flush()
assert(offset == 278)

combat = true
assert(not module:OpenOptions() and #timers == 0, "Combat does not open or queue scrolling")
combat = false
EllesmereUI._addonScrollFrame = nil
assert(module:OpenOptions())
flush()
EllesmereUI.GetPluginModuleKey = nil
assert(module:OpenOptions() and #timers == 0, "Older EUI versions retain their normal open behavior")
print("PASS: EllesmereUI opens Glassy's sidebar entry, preserves visible rows, and guards deferred navigation")
