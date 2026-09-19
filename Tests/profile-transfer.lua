local transfer = {}
local core = {GetModule = function (_, name)
  assert(name == "ProfileTransfer")
  return transfer
end}

assert(loadfile("Glassy/Modules/ProfileTransfer.lua"))("Glassy", {core})

local defaults = {
  enabled = true,
  size = 12,
  font = "Default",
  color = {r = 1, g = 1, b = 1, a = 1},
  tabOrder = {},
  timestampFrames = {["*"] = true},
}
local profile = {
  timestampFrames = {ChatFrame1 = false},
  tabOrder = {"ChatFrame2", "ChatFrame1"},
  color = {a = 0.5, b = 0.3, g = 0.2, r = 0.1},
  font = "Привет",
  size = 14,
  enabled = false,
}

local encoded = assert(transfer:Export(profile))
assert(string.sub(encoded, 1, 8) == "GLASSY1:")
local imported = assert(transfer:Import("\n"..encoded.."\n", defaults))
assert(imported.enabled == false and imported.size == 14 and imported.font == "Привет")
assert(imported.color.r == 0.1 and imported.color.a == 0.5)
assert(imported.tabOrder[1] == "ChatFrame2" and imported.tabOrder[2] == "ChatFrame1")
assert(imported.timestampFrames.ChatFrame1 == false)

local reordered = {
  enabled = false,
  size = 14,
  font = "Привет",
  color = {r = 0.1, g = 0.2, b = 0.3, a = 0.5},
  tabOrder = {"ChatFrame2", "ChatFrame1"},
  timestampFrames = {ChatFrame1 = false},
}
assert(transfer:Export(reordered) == encoded, "Equivalent profiles must have stable exports")

local withUnknown = {}
for key, value in pairs(profile) do withUnknown[key] = value end
withUnknown.futureSetting = "ignored"
local portable = assert(transfer:Import(assert(transfer:Export(withUnknown)), defaults))
assert(portable.futureSetting == nil and portable.font == profile.font, "Unknown future settings must be ignored")

assert(not transfer:Import("return os.execute('anything')", defaults))
assert(not transfer:Import(string.sub(encoded, 1, -2), defaults))
local wrongType = {enabled = "yes", size = 14}
assert(not transfer:Import(assert(transfer:Export(wrongType)), defaults))

print("PASS: profile exports are stable, portable, safely parsed, and schema validated")
