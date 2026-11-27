local profile = {saveCommandHistory = true}
local char = {}
local pratOwnsHistory
local mixin = {}
local core = {
  Components = {EditBoxMixin = mixin, EditBoxHelpers = {}},
  db = {profile = profile, char = char},
  IsPratModuleEnabled = function (_, name, option)
    return name == "History" and option == "savehistory" and pratOwnsHistory
  end,
}
local constants = {ACTIONS = {}, EVENTS = {}}
assert(loadfile("Glassy/Components/EditBoxNative.lua"))("Glassy", {core, constants, {}})

local secret = setmetatable({}, {__tostring = function () error("Protected text") end})
canaccessvalue = function (value) return value ~= secret end
IsSecureCmd = function (command) return command == "/TARGET" end
ChatTypeInfo = {WHISPER = {}}
hash_ChatTypeInfoList = {["/W"] = "WHISPER", ["/RELOAD"] = "RELOAD"}
function hooksecurefunc(object, name, callback)
  local original = object[name]
  object[name] = function (self, value)
    original(self, value)
    callback(self, value)
  end
end

local function newEditBox()
  local box = setmetatable({nativeHistory = {}}, {__index = mixin})
  function box:AddHistoryLine(text) self.nativeHistory[#self.nativeHistory + 1] = text end
  box:ConnectCommandHistory()
  return box
end

local box = newEditBox()
for _, line in ipairs({"/reload", "/dance", "/reload", "/target Mira", "/w Mira private", "/2 trade", "hi", secret}) do
  box:AddHistoryLine(line)
end
assert(table.concat(char.commandHistory, ",") == "/dance,/reload")
assert(#box.nativeHistory == 8, "Native session history still keeps its own lines")
box = newEditBox()
assert(table.concat(box.nativeHistory, ",") == "/dance,/reload", "Persisted commands are restored oldest first")

pratOwnsHistory = true
box = newEditBox()
assert(#box.nativeHistory == 0, "Prat takes precedence for command restoration")
box:AddHistoryLine("/prat")
assert(#char.commandHistory == 2, "Prat takes precedence for command capture")
pratOwnsHistory = false
profile.saveCommandHistory = false
box = newEditBox()
box:AddHistoryLine("/gl")
assert(#box.nativeHistory == 1 and #char.commandHistory == 2)
profile.saveCommandHistory = true
for index = 1, 40 do box:AddHistoryLine("/gl "..index) end
assert(#char.commandHistory == 32 and char.commandHistory[1] == "/gl 9")
core.db.char = {}
assert(#newEditBox().nativeHistory == 0, "Another character starts with its own command history")

print("PASS: slash commands survive reload without capturing protected commands, sent chat, or another character's history")
