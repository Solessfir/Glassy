unpack = unpack or table.unpack
strjoin = table.concat
strsplit = function() return "" end
strfind = string.find
strlen = string.len
strsub = string.sub
date = os.date

local textProcessing = {}
local core = {
  db = {
    profile = {
      messageBlacklistEnabled = false,
      messageBlacklist = "",
    },
  },
}

function core:GetModule(name)
  assert(name == "TextProcessing")
  return textProcessing
end

assert(loadfile("Glassy/Modules/TextProcessing.lua"))("Glassy", {core})

local reminder = "Remember to act responsibly, protect your personal information"
assert(not textProcessing:IsMessageBlacklisted(reminder), "The blacklist must default to off")

core.db.profile.messageBlacklistEnabled = true
core.db.profile.messageBlacklist = "remember to act responsibly\n[Notice].*"
assert(textProcessing:IsMessageBlacklisted("REMEMBER   to act\nresponsibly"), "Matching must ignore case and repeated whitespace")
assert(textProcessing:IsMessageBlacklisted("|cffffd100Remember|r to act responsibly"), "Visible formatted text must match")
assert(textProcessing:IsMessageBlacklisted("Prefix [Notice].* suffix"), "Phrases must be matched literally")
assert(not textProcessing:IsMessageBlacklisted("Prefix Notice suffix"), "Lua patterns must not be evaluated")

core.db.profile.messageBlacklist = "different phrase"
assert(not textProcessing:IsMessageBlacklisted(reminder), "Changing the setting must refresh cached phrases")

print("PASS: message blacklist defaults off and uses normalized plain-text matching")
