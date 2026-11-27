-- Run from the repository root with Lua 5.1 or newer.
unpack = unpack or table.unpack
strfind, strlen, strsub, date = string.find, string.len, string.sub, os.date
strjoin = function (separator, ...) return table.concat({...}, separator) end
strsplit = function (separator, text)
  local parts = {}
  for part in (text..separator):gmatch("(.-)"..separator) do parts[#parts + 1] = part end
  return unpack(parts)
end
local secret = setmetatable({}, {__tostring = function () error("Protected value inspected") end})
canaccessvalue = function (value) return value ~= secret end
local profile, enabled, modules, updates = {}, {}, {ChatRules = {}, TextProcessing = {}, MessageFormatting = {}}, {}
local core = {db = {profile = profile}}
function core:GetModule(name) return assert(modules[name], name) end
function core:IsPratModuleEnabled(name) return enabled[name] end
function core:Dispatch(key) updates[#updates + 1] = key end
local addon = {core, {ACTIONS = {UpdateConfig = function (key) return key end}}, {lower = string.lower}}
for _, name in ipairs({"ChatRules", "TextProcessing", "MessageFormatting"}) do
  assert(loadfile("Glassy/Modules/"..name..".lua"))("Glassy", addon)
end
local rules, tp = modules.ChatRules, modules.TextProcessing
local options = rules:BuildOptions().args
local alt = "|Hplayer:Alt-Realm:7:YELL|h[Alt]|h"
local item = "|cffaabbcc|Hitem:1:0|h[buy gold]|h|r"
local raw = alt..": hello "..item.." |Kbuy gold|k |Tbuy gold:12|t |A:buy gold:12:12|a"
local displayed, original = tp:ProcessText(raw)
assert(displayed == raw and original == raw and not tp:IsMessageBlacklisted(raw), "All features default to off")

profile.chatAltNamesEnabled, profile.chatAltNames = true, "Alt = Main\nAlt-Realm = Specific Main"
displayed, original = tp:ProcessText(raw)
assert(displayed:find("|Hplayer:Alt-Realm:7:YELL|h[Alt] (Specific Main)|h", 1, true), displayed)
assert(original == raw, "Main labels preserve the original for copying and the original hyperlink target")
enabled.PlayerNames = true
assert(tp:ProcessText(raw) == displayed, "Main mappings coexist with Prat PlayerNames when AltNames is inactive")
enabled.PlayerNames = false
assert(rules:AppendMainName("player:ALT-Other:1:SAY", "[ALT]") == "[ALT] (Main)")
assert(rules:AppendMainName("BNplayer:Alt:1", "[Alt]") == "[Alt]")
assert(rules:AppendMainName("player:Alt:1:SAY", "|KAlt|k") == "|KAlt|k")
enabled.AltNames = true
assert(tp:ProcessText(raw) == raw, "Prat AltNames takes precedence")
enabled.AltNames = false
profile.chatAltNamesEnabled = false

profile.chatSubstitutionsEnabled, profile.chatSubstitutions = true, "hello => hi\nbuy gold => flowers\nhi => bye"
displayed, original = tp:ProcessText(raw)
assert(displayed == alt..": bye "..item.." |Kbuy gold|k |Tbuy gold:12|t |A:buy gold:12:12|a", displayed)
assert(original == raw, "Substitutions preserve the source")
assert(rules:Substitute("hello |cff123456hello|r || hello") == "bye |cff123456bye|r || bye")
assert(rules:Substitute("hello |Hitem:hello|h[hello]") == "bye |Hitem:hello|h[hello]", "Incomplete links stay opaque")
assert(rules:Substitute("hello |unknown hello") == "bye |unknown hello", "Unknown codes stay opaque")
assert(rules:Substitute(secret) == secret and tp:ProcessText(secret) == secret)
profile.chatSubstitutions = "[ => percent %1 %"
assert(rules:Substitute("[ hi") == "percent %1 % hi", "Plain searches and replacement percent signs are literal")
profile.chatSubstitutionPatterns, profile.chatSubstitutions = true, "(%d+) => %1"
assert(rules:Substitute("12 apples") == "%1 apples", "Replacements never execute code or expand captures")
profile.chatSubstitutions = "hello => hi\n[ => broken"
assert(rules:Substitute("hello [") == "hello [", "Invalid imported patterns disable the entire list")
profile.chatSubstitutionPatterns, profile.chatSubstitutions = false, "hello => "
assert(rules:Substitute("hello") == "", "Empty replacements remove a match")
enabled.Substitutions = true
assert(rules:Substitute("hello") == "hello", "Prat Substitutions takes precedence")
enabled.Substitutions = false

profile.chatFilterRulesEnabled = true
profile.chatFilterRules = "keep|plain|trusted seller\nhide|plain|buy gold\nhide|pattern|^%d+ spam$"
assert(tp:IsMessageBlacklisted("BUY   gold"), "Plain rules ignore case and whitespace")
assert(tp:IsMessageBlacklisted(item), "Filters see link labels")
assert(not tp:IsMessageBlacklisted("|Hitem:buy gold|h[flowers]|h"), "Filters do not inspect hyperlink payloads")
assert(not tp:IsMessageBlacklisted("|Kbuy gold|k |Tbuy gold:12|t |A:buy gold:12:12|a"), "Opaque markup cannot match")
assert(not tp:IsMessageBlacklisted("trusted seller: buy gold"), "First matching keep rule wins")
assert(tp:IsMessageBlacklisted("12 spam") and not tp:IsMessageBlacklisted("12 SPAM"), "Patterns are case-sensitive")
assert(not tp:IsMessageBlacklisted(secret))
profile.messageBlacklistEnabled, profile.messageBlacklist = true, "trusted seller"
assert(tp:IsMessageBlacklisted("trusted seller: buy gold"), "Keep rules cannot override blocked phrases")
profile.messageBlacklistEnabled = false
profile.chatSubstitutions = "buy gold => flowers"
displayed, original = tp:ProcessText("buy gold")
assert(displayed == "flowers" and original == "buy gold" and tp:IsMessageBlacklisted(original), "Filtering uses the original before substitutions")
enabled.CustomFilters = true
assert(not tp:IsMessageBlacklisted("buy gold"), "Prat CustomFilters takes precedence")
profile.messageBlacklistEnabled, profile.messageBlacklist = true, "buy gold"
assert(tp:IsMessageBlacklisted("buy gold"), "Prat does not disable existing blocked phrases")
profile.messageBlacklistEnabled, enabled.CustomFilters = false, false
profile.chatFilterRules = "hide|plain|buy gold\nhide|pattern|["
assert(not tp:IsMessageBlacklisted("buy gold"), "Malformed imported rules cannot partially hide messages")
profile.chatFilterRules = "hide|pattern|^a"
assert(not tp:IsMessageBlacklisted(string.rep("a", 513)), "Patterns skip oversized visible messages")
profile.chatFilterRules = "hide|plain|a"
assert(tp:IsMessageBlacklisted(string.rep("a", 513)), "Plain rules remain available on longer messages")
profile.chatSubstitutionPatterns, profile.chatSubstitutions = true, "a => b"
assert(rules:Substitute(string.rep("a", 513)) == string.rep("a", 513), "Substitution patterns skip oversized text spans")
profile.chatSubstitutionPatterns = false

assert(options.chatAltNames.validate(nil, "Alt = Main") == true)
assert(type(options.chatAltNames.validate(nil, "Alt = |Hplayer:Other|hMain|h")) == "string")
assert(type(options.chatSubstitutions.validate(nil, "missing delimiter")) == "string")
assert(type(options.chatSubstitutions.validate(nil, "text => |Khidden|k")) == "string")
assert(options.chatSubstitutions.validate(nil, "[ => okay") == true)
profile.chatSubstitutions = "[ => okay"
assert(type(options.chatSubstitutionPatterns.validate(nil, true)) == "string", "Pattern toggle validates existing searches")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|[")) == "string")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|prefix[")) == "string", "Validation checks the entire pattern even when its prefix cannot match")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|a*a*b")) == "string", "Patterns cannot introduce unbounded backtracking")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|%b()")) == "string")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|(a+)%1")) == "string")
assert(type(options.chatFilterRules.validate(nil, "hide|pattern|prefix"..string.rep("()", 33))) == "string")
assert(options.chatFilterRules.validate(nil, "hide|pattern|%f[%a]spam%f[^%a]") == true)
assert(options.chatFilterRules.validate(nil, "hide|pattern|[]]") == true)
assert(type(options.chatFilterRules.validate(nil, "hide|plain|")) == "string")
assert(type(options.chatFilterRules.validate(nil, string.rep("hide|plain|x\n", 101))) == "string")
assert(type(options.chatFilterRules.validate(nil, string.rep("x", 16385))) == "string")
assert(options.chatFilterRules.validate(nil, "keep|plain|trusted\nhide|pattern|^spam") == true)
options.chatAltNames.set(nil, "Alt = New Main")
assert(updates[#updates] == "messageFormatting")
options.chatFilterRules.set(nil, "hide|plain|spam")
assert(updates[#updates] == "messageBlacklist")
enabled.AltNames, enabled.Substitutions, enabled.CustomFilters = true, true, true
assert(options.chatAltNamesEnabled.disabled() and options.chatSubstitutionsEnabled.disabled() and options.chatFilterRulesEnabled.disabled())
assert(options.chatAltNames.disabled())
print("Chat rule checks passed")
