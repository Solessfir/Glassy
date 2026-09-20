local core = {
  Components = {},
  Libs = {AceHook = {}},
  db = {profile = {chatAlwaysVisible = false, chatHoldTime = 10, chatShowWhileTyping = true}},
}
local constants = {
  EVENTS = {
    EDIT_BOX_VISIBILITY_CHANGED = "edit-box-visibility-changed",
    MOUSE_ENTER = "mouse-enter",
    MOUSE_LEAVE = "mouse-leave",
    UPDATE_CONFIG = "update-config",
  },
}
local utils = {}
assert(loadfile("Glassy/Components/ChatDock.lua"))("Glassy", {core, constants, utils})
assert(loadfile("Glassy/Components/DetachedChatDock.lua"))("Glassy", {core, constants, utils})

local function exercise(mixin, detached)
  core.db.profile.chatShowWhileTyping = true
  local dock = {editBoxVisible = false, mouseOver = false, state = {editBoxVisible = false, mouseOver = false, typing = false}, typing = false}
  for key, value in pairs(mixin) do dock[key] = value end
  local shows, hides = 0, 0
  dock.QuickShow = function () shows = shows + 1 end
  dock.HideDelay = function (_, delay) assert(delay == 10); hides = hides + 1 end
  local state = detached and dock or dock.state

  dock:SetTyping(true)
  assert(state.editBoxVisible and state.typing and shows == 1, "Typing did not reveal tabs")
  dock:SetTyping(false)
  assert(not state.typing and hides == 1, "Closing the input did not restore tab fading")

  state.mouseOver = true
  dock:SetTyping(true)
  dock:SetTyping(false)
  assert(hides == 1, "Closing the input hid tabs while they were hovered")

  state.mouseOver = false
  core.db.profile.chatShowWhileTyping = false
  dock:SetTyping(true)
  assert(not state.typing and shows == 2, "Disabled typing visibility revealed tabs")
  core.db.profile.chatShowWhileTyping = true
  dock:SetTyping(state.editBoxVisible)
  assert(state.typing and shows == 3, "Enabling the setting while typing did not reveal tabs")
  core.db.profile.chatShowWhileTyping = false
  dock:SetTyping(state.editBoxVisible)
  assert(not state.typing and hides == 2, "Disabling the setting while typing did not restore fading")

  core.db.profile.chatAlwaysVisible = true
  dock:SetTyping(false)
  dock:UpdateAutomaticVisibility()
  assert(shows == 4, "Always visible stopped keeping tabs visible")
  core.db.profile.chatAlwaysVisible = false
end

exercise(core.Components.ChatDockMixin, false)
exercise(core.Components.DetachedChatDockMixin, true)
print("PASS: typing reveals docked and detached tabs while preserving hover and always-visible behavior")
