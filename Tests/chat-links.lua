-- Run from the repository root with Lua 5.1.
local module, copied, invited = {}, nil, {}
local enabled = {}
local core = {
  db = {profile = {chatUrls = true, chatInvites = true}},
  GetModule = function (_, name)
    if name == "ChatCopy" then return {ShowText = function (_, _, value) copied = value end} end
    return module
  end,
  IsPratModuleEnabled = function (_, name) return enabled[name] end,
  Localize = function (_, text) return text end,
}
local alt, allowed = false, true
IsAltKeyDown = function () return alt end
CanGroupInvite = function () return allowed end
InviteUnit = function (name) invited[#invited + 1] = name end
assert(loadfile("Glassy/Modules/ChatLinks.lua"))("Glassy", {core})

local function url(value) return "|cffffffff|Hglassyurl:"..value.."|h["..value.."]|h|r" end
local function invite(value, name) return "|cffffff00|Hglassyinvite:"..name.."|h["..value.."]|h|r" end
local header = "|Hplayer:Elowen-Realm:123:SAY|h[Elowen]|h: "
for _, value in ipairs({"https://example.com/a?q=1%20b", "www.example.com", "example.com:9987/path",
  "127.0.0.1", "192.168.1.2:9987", "10.0.0.1/path", "hello+wow@example.com", '"W X"@example.com',
  "example.technology", "https://example.com/Some_(page)"}) do
  assert(module:Format(value) == url(value), value.." must become a URL")
end
assert(module:Format("See (https://example.com/a), then example.com!") ==
  "See ("..url("https://example.com/a").."), then "..url("example.com").."!")
for _, value in ipairs({"256.0.0.1", "1.2.3.4:70000", "example..com", ".example.com", "not.a", "foo", "-bad.com"}) do
  assert(module:Format(value) == value, value.." must not become a URL")
end
for _, value in ipairs({"|Hitem:123|h[example.com invite]|h", "|Texample.com:0|t", "|Aexample.com|a",
  "|Kexample.com|k", "||Hitem:example.com", "|Hbroken example.com"}) do
  assert(module:Format(value) == value, "Existing and incomplete markup is preserved")
end
assert(module:Format("|cff123456example.com tail|r") == "|cff123456"..url("example.com").."|cff123456 tail|r",
  "URL links restore the enclosing text color")
assert(module:Format(header.."invite?") == header..invite("invite?", "Elowen-Realm"))
assert(module:Format(header.."inv for dungeon") == header..invite("inv for", "Elowen-Realm").." dungeon")
assert(module:Format(header.."Invite Anduin") == header..invite("Invite Anduin", "Anduin"))
assert(module:Format(header.."send invite to Anduin") == header..invite("send invite to Anduin", "Anduin"))
assert(module:Format(header.."inv me") == header..invite("inv me", "Elowen-Realm"))
assert(module:Format(header.."invite please") == header..invite("invite", "Elowen-Realm").." please")
assert(module:Format(header.."invitation inventory") == header.."invitation inventory")
assert(module:Format("invite me") == "invite me", "Unattributed messages never gain invite links")
assert(module:Format("Look "..header.."invite") == "Look "..header.."invite", "Pasted player links are not senders")
local system = "|Hplayer:Elowen|h[Elowen]|h has come online: invite"
assert(module:Format(system) == system, "System message player links do not supply chat senders")
assert(module:Format(header.."초대") == header..invite("초대", "Elowen-Realm"))
local iconHeader = "|Hchannel:CHANNEL:2|h[2. Trade]|h |Ticon:14|t |cff00ff00[|Hplayer:Elowen:1|hElowen|h]|r: "
assert(module:Format(iconHeader.."invite") == iconHeader..invite("invite", "Elowen"), "Formatted sender icons remain supported")
assert(#invited == 0, "Formatting never invites players")

assert(module:HandleClick("glassyurl:https://example.com/a", "LeftButton") and copied == "https://example.com/a")
copied = nil
assert(module:HandleClick("glassyurl:https://example.com/a", "RightButton") and copied == nil)
assert(not module:HandleClick("player:Elowen:123:SAY", "LeftButton"))
alt = true
assert(module:HandleClick("player:Elowen:123:SAY", "LeftButton") and invited[1] == "Elowen")
assert(not module:HandleClick("player:Elowen:123:SAY", "RightButton"))
alt = false
assert(module:HandleClick("glassyinvite:Anduin-Realm", "LeftButton") and invited[2] == "Anduin-Realm")
assert(module:HandleClick("glassyinvite:bad|Hplayer:someone", "LeftButton") and #invited == 2)
allowed = false
assert(module:Format(header.."invite") == header.."invite")
assert(module:HandleClick("glassyinvite:Anduin", "LeftButton") and #invited == 2)
allowed = true

enabled.UrlCopy, enabled.Invites = true, true
assert(module:Format(header.."invite example.com") == header.."invite example.com", "Prat modules own their features")
alt = true
assert(not module:HandleClick("player:Elowen:123:SAY", "LeftButton") and #invited == 2)
enabled.UrlCopy, enabled.Invites = false, false
core.db.profile.chatUrls, core.db.profile.chatInvites = false, false
assert(module:Format(header.."invite example.com") == header.."invite example.com")
assert(not module:HandleClick("player:Elowen:123:SAY", "LeftButton") and #invited == 2)

core.db.profile.chatUrls, core.db.profile.chatInvites = true, true
local forever = "|Hplayer:Elowen Silvermoon:123:SAY|h[Elowen Silvermoon]|h: "
assert(module:Format(forever.."invite") == forever..invite("invite", "Elowen Silvermoon"))
assert(module:HandleClick("invplr:Elowen Silvermoon", "LeftButton") and invited[3] == "Elowen Silvermoon")
assert(module:HandleClick("url:https://example.com/old", "LeftButton") and copied == "https://example.com/old")

local secret = setmetatable({}, {__tostring = function () error("Protected text was parsed") end})
canaccessvalue = function (value) return value ~= secret end
assert(module:Format(secret) == secret and not module:HandleClick(secret, "LeftButton"))
print("PASS: URL forms, safe markup, sender invite tags, click actions and Prat coexistence")

-- Exercise the shared click subscriber used by message rows and whisper transcripts.
local hyperlinks, listeners, nativeClicks = {}, {}, {}
local getModule = core.GetModule
core.GetModule = function (self, name)
  if name == "Hyperlinks" then return hyperlinks end
  return getModule(self, name)
end
core.Subscribe = function (_, event, callback) listeners[event] = callback end
hooksecurefunc = function () end
SetItemRef = function (link, text, button, frame)
  nativeClicks[#nativeClicks + 1] = {link, text, button, frame}
end
local constants = {ACTIONS = {}, EVENTS = {
  HYPERLINK_CLICK = "click", HYPERLINK_ENTER = "enter", HYPERLINK_LEAVE = "leave",
}}
assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
hyperlinks:OnInitialize()
hyperlinks:OnEnable()
local chatFrame = {}
local function click(name, button)
  listeners.click({"player:"..name..":123:PARTY", "["..name.."]", button or "LeftButton", chatFrame})
end

invited = {}
alt = true
for _, name in ipairs({"Elowen Silvermoon", "Elowen Silvermoon-Realm", "Élowen-Realm", "Elowen-Realm"}) do
  click(name)
  assert(invited[#invited] == name, "Alt-click must send the complete hyperlink target to InviteUnit")
end
assert(#invited == 4 and #nativeClicks == 0, "Handled Alt-clicks must not also open a whisper")
click("Elowen Silvermoon", "RightButton")
assert(#invited == 4 and nativeClicks[1][4] == nil, "Alt-right-click retains the native player menu")
alt = false
click("Elowen Silvermoon")
assert(#invited == 4 and nativeClicks[2][4] == chatFrame, "Normal player clicks retain Blizzard behavior")
alt, allowed = true, false
click("Elowen Silvermoon")
assert(#invited == 4 and #nativeClicks == 3, "Unavailable invite permission leaves the native action intact")
allowed, enabled.Invites = true, true
click("Elowen Silvermoon")
assert(#invited == 4 and #nativeClicks == 4, "Prat receives the player click without a duplicate Glassy invite")
enabled.Invites, core.db.profile.chatInvites = false, false
click("Elowen Silvermoon")
assert(#invited == 4 and #nativeClicks == 5, "Disabling invite links also disables Alt-invite")
core.db.profile.chatInvites = true
InviteUnit, CanGroupInvite = nil, nil
C_PartyInfo = {
  CanInvite = function () return allowed end,
  InviteUnit = function (name) invited[#invited + 1] = name end,
}
click("Elowen Silvermoon-Realm")
assert(invited[5] == "Elowen Silvermoon-Realm" and #nativeClicks == 5,
  "Modern clients use C_PartyInfo without changing the invite target")
click("Elowen  Silvermoon")
assert(#invited == 5 and #nativeClicks == 6, "Malformed targets must not reach the invite API")
print("PASS: Alt-invite dispatch keeps full Forever names, native clicks, Prat ownership and API fallbacks")
