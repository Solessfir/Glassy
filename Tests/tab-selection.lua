-- Run from the repository root with Lua 5.1.
local function noop() end
local function frame(parent)
  local object = {parent = parent, shown = true, alpha = 1, width = 60, height = 20, scripts = {}}
  function object:GetParent() return self.parent end
  function object:SetFrameLevel(level) self.level = level end
  function object:GetFrameLevel() return self.level or 1 end
  function object:SetSize(width, height) self.actualWidth, self.actualHeight = width, height end
  function object:GetWidth() return self.width end
  function object:GetHeight() return self.height end
  function object:ClearAllPoints() self.point = nil end
  function object:SetPoint(...) self.point = {...} end
  function object:SetScript(key, callback) self.scripts[key] = callback end
  function object:SetAlpha(alpha) self.alpha = alpha end
  function object:GetAlpha() return self.alpha end
  function object:Hide() self.shown = false end
  function object:Show() self.shown = true end
  function object:IsShown() return self.shown end
  function object:CreateTexture()
    local texture = frame(self)
    texture.SetColorTexture, texture.SetHeight, texture.SetVertexColor = noop, noop, noop
    return texture
  end
  return object
end
CreateFrame = function (_, _, parent) return frame(parent) end
GENERAL_CHAT_DOCK = {}
local core = {
  db = {profile = {tabSelectionAnimation = "none", tabStyle = "minimal"}},
  Components = {ChatDockMixin = {}},
  GetThemeColor = function () return {r = 1, g = 0.8, b = 0.2} end,
}
core.Components.GetChatTabStyle = function () return core.db.profile.tabStyle end
core.Components.RenderChatTabStyle = function (host, style, state)
  host.renderedStyle, host.renderedState = style, state
end
assert(loadfile("Glassy/Components/ChatTabSelection.lua"))("Glassy", {core, {COLORS = {}, DOCK_HEIGHT = 20}})
local dock = {scrollFrame = {child = frame()}}
for key, value in pairs(core.Components.ChatDockMixin) do dock[key] = value end
local function tab(name, offset, width)
  local chat = {isDocked = true, GetName = function () return name end}
  local object = frame(dock.scrollFrame.child)
  object.glassyDockOffset, object.width = offset, width
  _G[name.."Tab"] = object
  return chat, object
end
local first, firstTab = tab("TestFirst", 0, 60)
local second, secondTab = tab("TestSecond", 61, 100)
GENERAL_CHAT_DOCK.selected = first
dock:UpdateTabSelection()
assert(not dock.tabSelection, "Off must preserve the existing Minimal tab")
core.db.profile.tabSelectionAnimation = "slide"
dock:UpdateTabSelection()
local selection = dock.tabSelection
local piece = selection.piece
assert(piece:GetParent() == dock.scrollFrame.child, "Selection art must stay inside the tab scroller")
assert(piece.level == dock.scrollFrame.child:GetFrameLevel(), "Selection art must stay below tab text")
assert(piece.line:IsShown() and firstTab.glassySelectionAnimated)
assert(piece.x == 0 and piece.actualWidth == 60 and not selection.elapsed)
GENERAL_CHAT_DOCK.selected = second
dock:UpdateTabSelection()
assert(not firstTab.glassySelectionAnimated and secondTab.glassySelectionAnimated)
assert(selection.elapsed == 0 and piece.x == 0 and piece.actualWidth == 60)
dock:StepTabSelection(0.15)
assert(math.abs(piece.x - 30.5) < 0.001 and math.abs(piece.actualWidth - 80) < 0.001)
local interruptedX, interruptedWidth = piece.x, piece.width
GENERAL_CHAT_DOCK.selected = first
dock:UpdateTabSelection()
assert(piece.x == interruptedX and piece.width == interruptedWidth, "Rapid clicks must start at the current position")
dock:StepTabSelection(0.3)
assert(piece.x == 0 and piece.actualWidth == 60 and not piece.scripts.OnUpdate)
firstTab.width = 72
dock:UpdateTabSelection()
assert(piece.actualWidth == 72, "Unread count and font layout changes must resize the selection")

core.db.profile.tabStyle = "pill"
core.db.profile.tabSelectionAnimation = "grow"
dock:UpdateTabSelection()
assert(not piece.line:IsShown() and piece.renderedStyle == "pill")
GENERAL_CHAT_DOCK.selected = second
dock:UpdateTabSelection()
assert(selection.ghost:IsShown() and piece.actualWidth == 30)
assert(math.abs(piece.x + piece.width / 2 - 111) < 0.001, "Grow must open from the target center")
dock:StepTabSelection(0.14)
assert(selection.ghost.actualWidth < 72 and selection.ghost:GetAlpha() < 1)
dock:StepTabSelection(0.14)
assert(piece.actualWidth == 100 and piece.x == 61 and piece:GetAlpha() == 1)
assert(not selection.ghost:IsShown() and not piece.scripts.OnUpdate)

dock.tabDrag = {}
dock:UpdateTabSelection()
assert(not piece:IsShown() and not secondTab.glassySelectionAnimated, "Dragging must restore the tab's own art")
dock.tabDrag = nil
dock:UpdateTabSelection()
assert(piece:IsShown() and not selection.elapsed, "Dropping must snap to the final layout")
for _, style in ipairs({"classic", "minimal"}) do
  core.db.profile.tabStyle = style
  core.db.profile.tabSelectionAnimation = "none"
  dock:UpdateTabSelection()
  assert(not piece:IsShown() and not secondTab.glassySelectionAnimated)
end
core.db.profile.tabStyle = "classic"
core.db.profile.tabSelectionAnimation = "slide"
dock:UpdateTabSelection()
assert(not piece:IsShown(), "Classic must retain Blizzard's selected art")
core.db.profile.tabStyle = "underline"
core.db.profile.tabSelectionAnimation = "grow"
dock:UpdateTabSelection()
assert(piece.renderedStyle == "underline" and piece:IsShown())
GENERAL_CHAT_DOCK.selected = first
dock:UpdateTabSelection()
assert(piece.actualHeight == 20, "Growing lines must remain at the tab edge")
dock:StepTabSelection(0.14)
assert(selection.ghost.actualHeight == 20)
GENERAL_CHAT_DOCK.selected = second
dock:UpdateTabSelection()
canaccessvalue = function (value) return value ~= secondTab.width end
dock:UpdateTabSelection()
assert(not piece:IsShown() and not secondTab.glassySelectionAnimated, "Protected widths must fall back to static art")
canaccessvalue = nil
dock:UpdateTabSelection()
secondTab:Hide()
dock:UpdateTabSelection()
assert(not piece:IsShown() and not secondTab.glassySelectionAnimated, "Hidden Combat Log and closed tabs must not leave art behind")
print("Tab selection animation tests passed")
