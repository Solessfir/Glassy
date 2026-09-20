-- Run from the repository root with Lua 5.1 and the bundled libraries available.
local editBoxFile, hookFile = ...
strmatch = string.match
issecurevariable = function () return false end
dofile("libs/LibStub/LibStub.lua")
dofile(hookFile or "libs/AceHook-3.0/AceHook-3.0.lua")
local AceHook = LibStub("AceHook-3.0")
local Core = {Libs = {AceHook = AceHook, LibEasing = {}}, Components = {}}
local Constants = {ACTIONS = {}, EVENTS = {}}

local function newEditBox()
  local scripts = {}
  local nativeChatFrame = {shown = false}
  return {
    parent = nativeChatFrame,
    chatFrame = nativeChatFrame,
    SetParent = function (self, parent) self.parent = parent end,
    GetParent = function (self) return self.parent end,
    IsVisible = function (self) return self.shown and self.parent.shown end,
    hooks = {external = true},
    GetScript = function (_, name) return scripts[name] end,
    HasScript = function () return true end,
    HookScript = function (_, name, callback)
      local previous = scripts[name]
      scripts[name] = function (...)
        if previous then previous(...) end
        callback(...)
      end
    end,
    Show = function (self) self.shown = true end,
  }
end

Mixin = function (object, ...)
  for i = 1, select("#", ...) do
    for key, value in pairs(select(i, ...)) do object[key] = value end
  end
  return object
end

-- Isolate hook ownership from visual initialization, which needs the game renderer.
Core.Components.GradientBackgroundMixin = {
  Init = function (object) object.Init = function () end end,
}
assert(loadfile(editBoxFile or "Glassy/Components/EditBox.lua"))("Glassy", {Core, Constants, {}})
assert(loadfile("Glassy/Components/EditBoxNative.lua"))("Glassy", {Core, Constants, {super = function () end}})
assert(type(Core.Components.EditBoxMixin.Init) == "function", "EditBox native integration did not load")

Core.db = {profile = {
  chatAlwaysVisible = true,
  dynamicEditBox = false,
  editBoxAnchor = {position = "BELOW", yOfs = 0},
  editBoxBackgroundColor = {a = 0.4},
  editBoxMessageSeparatorColor = {a = 0},
}}
assert(Core.Components.EditBoxHelpers.shouldKeepBackgroundVisible(), "Always visible did not preserve the non-dynamic edit-box background")
Core.db.profile.dynamicEditBox = true
assert(not Core.Components.EditBoxHelpers.shouldKeepBackgroundVisible(), "Always visible preserved the dynamic edit-box background")
local dynamicEditBox = Mixin({glassyEntryVisible = false, GetHeight = function () return 24 end}, Core.Components.EditBoxMixin)
assert(dynamicEditBox:GetReusableMessageHeight() == 24, "Dynamic message area did not reclaim the full hidden edit-box height")

for _, pratFirst in ipairs({false, true}) do
  ChatFrame1EditBox = newEditBox()
  local nativeHookScript, externalHooks = ChatFrame1EditBox.HookScript, ChatFrame1EditBox.hooks
  local prat, calls = AceHook:Embed({}), 0
  local function installPrat()
    prat:SecureHookScript(ChatFrame1EditBox, "OnTextChanged", function () calls = calls + 1 end)
  end
  if pratFirst then installPrat() end
  local nativeChatFrame = ChatFrame1EditBox.chatFrame
  local glassyParent = {shown = true}
  local editBox = Core.Components.CreateEditBox(glassyParent)
  assert(editBox:GetParent() == glassyParent, "The input still inherits the hidden native chat frame")
  assert(editBox.chatFrame == nativeChatFrame, "The input lost its native chat channel association")
  assert(editBox.HookScript == nativeHookScript, "Glassy replaced the native HookScript method")
  assert(editBox.hooks == externalHooks, "Glassy changed another addon's hook storage")
  assert(editBox.glassyHooks and editBox.glassyHooks ~= editBox, "Glassy needs a separate hook owner")
  if not pratFirst then installPrat() end
  editBox:GetScript("OnTextChanged")(editBox)
  assert(calls == 1, "Prat's secure script hook did not run")
  prat:UnhookAll()
  editBox:GetScript("OnTextChanged")(editBox)
  assert(calls == 1, "Prat's hook was not disabled")
  editBox.glassyHooks:RawHook(editBox, "Show", function (frame)
    editBox.glassyHooks.hooks[frame].Show(frame)
  end, true)
  editBox:Show()
  assert(editBox.shown, "Glassy's raw hook lost the original method")
  assert(editBox:IsVisible(), "The input is invisible while the original chat frame is hidden")
  nativeChatFrame.shown = true
  nativeChatFrame.shown = false
  assert(editBox:IsVisible(), "Switching native chat tabs hid the input")
  glassyParent.shown = false
  assert(not editBox:IsVisible(), "The input should follow the Glassy container's visibility")
  editBox.glassyHooks:UnhookAll()
end
print("PASS: native hooks preserved; Prat works in both load orders; input follows Glassy visibility and keeps its chat association.")
