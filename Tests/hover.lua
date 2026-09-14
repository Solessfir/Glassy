-- Run from the repository root with Lua 5.1.
Mixin = function (object, mixin)
  for key, value in pairs(mixin) do object[key] = value end
  return object
end
local function newRegion()
  return {
    visible = true, hovered = false,
    IsVisible = function (self) return self.visible end,
    SetWidth = function () end, SetHeight = function () end,
  }
end

for _, nativeMethod in ipairs({true, false}) do
  MouseIsOver = nil
  if not nativeMethod then MouseIsOver = function (region) return region.hovered end end
  CreateFrame = function ()
    local region = newRegion()
    if nativeMethod then region.IsMouseOver = function (self) return self.hovered end end
    return region
  end
  local events = {}
  local core = {
    Components = {}, db = {profile = {frameWidth = 450, frameHeight = 230}},
    Subscribe = function () end,
    Dispatch = function (_, event) events[#events + 1] = event end,
  }
  local constants = {EVENTS = {}, ACTIONS = {
    MouseEnter = function () return "enter" end,
    MouseLeave = function () return "leave" end,
  }}
  assert(loadfile("Glassy/Components/MainContainerFrame.lua"))("Glassy", {core, constants})
  local container = core.Components.CreateMainContainerFrame("Test", {})
  local input = CreateFrame()
  container:AddHoverRegion(input)
  container:OnFrame()
  assert(#events == 0)
  input.hovered = true
  container:OnFrame()
  container:OnFrame()
  assert(#events == 1 and events[1] == "enter", "Hover must reveal chat once")
  input.visible = false
  container:OnFrame()
  assert(#events == 2 and events[2] == "leave", "Hidden inputs must not keep chat revealed")
  container.hovered = true
  container:OnFrame()
  assert(#events == 3 and events[3] == "enter")
end
print("PASS: Retail region hover without MouseIsOver, legacy fallback, and enter/leave transitions.")
