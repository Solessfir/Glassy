-- Run from the repository root with Lua 5.1.
strsplit = function (delimiter, text)
  local parts = {}
  for part in (text..delimiter):gmatch("(.-)"..delimiter) do parts[#parts + 1] = part end
  return unpack(parts)
end

local chatCopy = {}
local textProcessing = {IsMessageBlacklisted = function () return false end}
local core = {
  db = {profile = {scrollbackLines = 100}},
  defaults = {profile = {scrollbackLines = 100}},
  Libs = {},
  Localize = function (_, text) return text end,
  GetModule = function (_, name) return name == "ChatCopy" and chatCopy or textProcessing end,
}
assert(loadfile("Glassy/Modules/ChatCopy.lua"))("Glassy", {core})

local copied
chatCopy.ShowText = function (_, _, text) copied = text end
local messages = {
  "|cnPURE_GREEN_COLOR:Loaded.|r Plain after",
  "|cff00ff00Green|r and 0 |4day:days;, 1 |4hour:hours;, 6 |4second:seconds;",
  "21 |4час:часа:часов;, 3 |4час:часа:часов;, 11 |4час:часа:часов;",
}
chatCopy:Show({
  GetName = function () return "ChatFrame1" end,
  GetNumMessages = function () return #messages end,
  GetMessageInfo = function (_, index) return messages[index] end,
})

assert(copied == "Loaded. Plain after\nGreen and 0 days, 1 hour, 6 seconds\n21 час, 3 часа, 11 часов", copied)
print("chat-copy-markup: ok")
