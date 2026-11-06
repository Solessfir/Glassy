-- Run from the repository root with Lua 5.1.
strsplit = function (delimiter, text)
  local parts = {}
  for part in (text..delimiter):gmatch("(.-)"..delimiter) do parts[#parts + 1] = part end
  return unpack(parts)
end
COPY_CHARACTER_NAME, MOVE_TO_NEW_WINDOW = "Copy Character Name", "Move to New Window"

local listeners, modifiers = {}, {}
local refs, copied, poppedOut = {}, nil, nil
local module = {}
local chatCopy = {ShowText = function (_, _, text) copied = text end}
local core = {
  GetModule = function (_, name) return name == "ChatCopy" and chatCopy or module end,
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
local channelMenu, moveElement = menu(MOVE_TO_NEW_WINDOW)
SetItemRef = function (link, text, button, frame)
  refs[#refs + 1] = {link = link, button = button, frame = frame}
  if link:match("^player:") then modifiers.MENU_UNIT_PLAYER(nil, copyMenu, {name = "Elowen"}) end
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

assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
module:OnInitialize()
module:OnEnable()
local chatFrame = {}

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

listeners.click({"channel:CHANNEL:2", "[2. Trade]", "RightButton", chatFrame})
moveElement.responder()
assert(poppedOut[1] == chatFrame and poppedOut[2] == "CHANNEL" and poppedOut[3] == "2",
  "Move to New Window receives the frame the link came from")

-- Menus opened outside Glassy keep Blizzard's own entries.
copyElement.responder, copied = nil, nil
modifiers.MENU_UNIT_PLAYER(nil, copyMenu, {name = "Elowen"})
assert(copyElement.responder == nil, "Blizzard's own menus are left unchanged")
print("PASS: links keep their chat frame, recipes can be tracked, and link menus are redirected")
