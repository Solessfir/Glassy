-- Run from the repository root with Lua 5.1.
strsplit = function (delimiter, text)
  local parts = {}
  for part in (text..delimiter):gmatch("(.-)"..delimiter) do parts[#parts + 1] = part end
  return unpack(parts)
end
COPY_CHARACTER_NAME, MOVE_TO_NEW_WINDOW = "Copy Character Name", "Move to New Window"
MOVE_TO_WHISPER_WINDOW = "Move to Whisper Window"
local openedWindow
FCF_OpenTemporaryWindow = function (...) openedWindow = {...} end

local listeners, modifiers = {}, {}
local refs, copied, poppedOut = {}, nil, nil
local module = {}
local chatCopy = {ShowText = function (_, _, text) copied = text end}
local handledLink
local chatLinks = {HandleClick = function (_, link, button)
  if link ~= "glassyurl:https://example.com" then return false end
  handledLink = {link, button}
  return true
end}
local core = {
  GetModule = function (_, name)
    if name == "ChatCopy" then return chatCopy end
    if name == "ChatLinks" then return chatLinks end
    return module
  end,
  Subscribe = function (_, event, callback) listeners[event] = callback end,
  Localize = function (_, text) return text end,
  Dispatch = function () end,
}
local constants = {ACTIONS = {}, EVENTS = {HYPERLINK_CLICK = "click", HYPERLINK_ENTER = "enter", HYPERLINK_LEAVE = "leave"}}
hooksecurefunc = function () end
Menu = {ModifyMenu = function (tag, callback) modifiers[tag] = callback end}

-- Menus are generated while SetItemRef runs, just as Blizzard opens them during the click.
local function menu(text)
  local element = {text = text}
  function element:SetResponder(callback) self.responder = callback end
  local root = {element}
  function root:EnumerateElementDescriptions() return ipairs(self) end
  return root, element
end
local copyMenu, copyElement = menu(COPY_CHARACTER_NAME)
local whisperElement = {text = MOVE_TO_WHISPER_WINDOW}
function whisperElement:SetResponder(callback) self.responder = callback end
copyMenu[2] = whisperElement
local channelMenu, moveElement = menu(MOVE_TO_NEW_WINDOW)
SetItemRef = function (link, text, button, frame)
  refs[#refs + 1] = {link = link, button = button, frame = frame}
  if link:match("^player:") then
    modifiers.MENU_UNIT_PLAYER(nil, copyMenu, {name = "Elowen", chatType = "WHISPER", chatTarget = "Elowen"})
  end
  if link:match("^channel:") then modifiers.MENU_CHAT_FRAME_CHANNEL(nil, channelMenu) end
end

local tracked = {}
C_TradeSkillUI = {
  IsRecipeTracked = function (id) return tracked[id] == true end,
  SetRecipeTracked = function (id, value) tracked[id] = value end,
}
MenuUtil = {
  GetElementText = function (element) return element.text end,
  CreateContextMenu = function (_, generator)
    local root = {CreateTitle = function (self, title) self.title = title end}
    function root:CreateButton(text, callback) self.button, self.callback = text, callback end
    generator(nil, root)
    MenuUtil.lastMenu = root
  end,
}
ChatFrameUtil = {PopOutChat = function (frame, chatType, target) poppedOut = {frame, chatType, target} end}

UIParent = {}
local function tooltip()
  local frame = {}
  function frame:SetOwner(_, anchor) self.ownerAnchor = anchor end
  function frame:ClearAllPoints() self.point = nil end
  function frame:SetPoint(...) self.point = {...} end
  function frame:GetPoint() return unpack(self.point or {}) end
  function frame:GetBottom() return self.point and self.point[5] end
  function frame:Show() self.shown = true end
  function frame:Hide() self.shown = false end
  function frame:SetHyperlink(link) self.link = link end
  return frame
end
GameTooltip, BattlePetTooltip = tooltip(), tooltip()
BattlePetTooltip.Owned = {}
ShowUIPanel = function (frame) frame:Show() end
local petLinksShown = 0
BattlePetToolTip_ShowLink = function (text)
  assert(BattlePetTooltip.Owned, "Forever clients without Owned must skip pet tooltips")
  assert(BattlePetTooltip:GetBottom() and BattlePetTooltip:GetBottom() >= 0,
    "TSM's OnShow hook needs a positioned pet tooltip")
  assert(text == "[Pet]", "The full link text reaches Blizzard")
  BattlePetTooltip:Show()
  BattlePetTooltip:ClearAllPoints()
  BattlePetTooltip:SetPoint(GameTooltip:GetPoint(1))
  assert(BattlePetTooltip:GetBottom(), "Blizzard must retain a valid anchor after showing")
  petLinksShown = petLinksShown + 1
end

assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
module:OnInitialize()
module:OnEnable()
local chatFrame = {}

listeners.click({"glassyurl:https://example.com", "[https://example.com]", "LeftButton", chatFrame})
assert(handledLink[1] == "glassyurl:https://example.com" and handledLink[2] == "LeftButton" and #refs == 0,
  "Native chat link clicks are handled before Blizzard's item link handler")

listeners.click({"enchant:2337", "|cffffffff|Henchant:2337|h[Alchemy: Lesser Healing Potion]|h|r", "RightButton", chatFrame})
assert(#refs == 0, "Recipe right-clicks open Glassy's tracking menu instead")
assert(MenuUtil.lastMenu.title == "Alchemy: Lesser Healing Potion" and MenuUtil.lastMenu.button == "Track Recipe")
MenuUtil.lastMenu.callback()
assert(tracked[2337] == true)

listeners.click({"item:6948", "[Hearthstone]", "LeftButton", chatFrame})
assert(refs[1].frame == chatFrame, "Left clicks keep their chat frame")

listeners.click({"player:Elowen", "[Elowen]", "RightButton", chatFrame})
assert(refs[2].frame == nil, "Right-click menus are not anchored to the hidden native frame")
copyElement.responder()
assert(copied == "Elowen", "Copy Character Name opens Glassy's copy window")
whisperElement.responder()
assert(openedWindow[1] == "WHISPER" and openedWindow[2] == "Elowen" and openedWindow[3] == chatFrame
  and openedWindow[4] == true, "Move to Whisper Window carries the conversation from the clicked chat frame")

listeners.click({"channel:CHANNEL:2", "[2. Trade]", "RightButton", chatFrame})
moveElement.responder()
assert(poppedOut[1] == chatFrame and poppedOut[2] == "CHANNEL" and poppedOut[3] == "2",
  "Move to New Window receives the frame the link came from")

-- Menus opened outside Glassy keep Blizzard's own entries.
copyElement.responder, copied = nil, nil
modifiers.MENU_UNIT_PLAYER(nil, copyMenu, {name = "Elowen"})
assert(copyElement.responder == nil, "Blizzard's own menus are left unchanged")
print("PASS: links keep their chat frame, recipes can be tracked, and link menus are redirected")

local petLink = {"battlepet:39:1:2:100:10:10", "[Pet]"}
for _ = 1, 2 do
  -- Repeated hovers must work after the previous line or tooltip has been reused.
  BattlePetTooltip:ClearAllPoints()
  listeners.enter(petLink)
  assert(module.state.showingTooltip == BattlePetTooltip and BattlePetTooltip.shown)
  assert(BattlePetTooltip.point[1] == "BOTTOMRIGHT" and BattlePetTooltip.point[2] == UIParent)
  assert(BattlePetTooltip.point[4] == -13 and BattlePetTooltip.point[5] == 64)
  assert(GameTooltip.ownerAnchor == "ANCHOR_NONE" and not GameTooltip.shown)
  listeners.leave(petLink[1])
  assert(not BattlePetTooltip.shown and not module.state.showingTooltip)
end
assert(petLinksShown == 2)

BattlePetTooltip.Owned = nil
listeners.enter(petLink)
assert(petLinksShown == 2 and not module.state.showingTooltip, "Missing Owned safely skips hover")
listeners.leave(petLink[1])

BattlePetTooltip = nil
assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
module:OnInitialize()
module:OnEnable()
listeners.enter(petLink)
assert(petLinksShown == 2 and not module.state.showingTooltip, "Missing pet tooltip safely skips hover")

listeners.enter({"item:6948", "[Hearthstone]"})
assert(module.state.showingTooltip == GameTooltip and GameTooltip.link == "item:6948" and GameTooltip.shown)
assert(GameTooltip.ownerAnchor == "ANCHOR_CURSOR", "Other links keep cursor tooltips")
listeners.leave("item:6948")
assert(not GameTooltip.shown and not module.state.showingTooltip)
print("PASS: pet hovers anchor before OnShow, skip incomplete clients, and preserve normal tooltips")
