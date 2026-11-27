-- Run with Lua 5.1 from the repository root.
strsplit = function (delimiter, value)
  local parts = {}
  for part in (value..delimiter):gmatch("(.-)"..delimiter) do parts[#parts + 1] = part end
  return unpack(parts)
end
MOVE_TO_NEW_WINDOW = "Move to New Window"
GUILD, SAY, OFFICER = "Guild", "Say", "Officer"
CHAT_CATEGORY_LIST = {GUILD = {"GUILD_ACHIEVEMENT", "GUILD_ITEM_LOOTED"}, CHANNEL = {"CHANNEL_JOIN", "CHANNEL_LEAVE"}}
ChatFrameUtil = {GetChannelShortcutName = function (target) return ({["2"] = "Trade", ["3"] = "General"})[tostring(target)] end}
ChatHistory_GetAccessID = function (chatType, target) return chatType..":"..(target or "") end

-- Model Blizzard's destructive filter/history move so repeated calls cannot silently pass.
function ChatFrameUtil.PopOutChat(source, chatType, target)
  local frame = FCF_OpenNewWindow()
  frame:RemoveAllMessageGroups()
  frame:RemoveAllChannels()
  frame:AddMessageGroup(chatType)
  for _, group in pairs(CHAT_CATEGORY_LIST[chatType] or {}) do frame:AddMessageGroup(group) end
  if chatType == "CHANNEL" then
    local channel = ChatFrameUtil.GetChannelShortcutName(target)
    frame:AddChannel(channel)
    source:RemoveChannel(channel)
  else
    source:RemoveMessageGroup(chatType)
    for _, group in pairs(CHAT_CATEGORY_LIST[chatType] or {}) do source:RemoveMessageGroup(group) end
  end
  local accessID = ChatHistory_GetAccessID(chatType, target)
  for line = 1, source:GetNumMessages() do
    local text, r, g, b, typeID, messageAccessID, lineID = source:GetMessageInfo(line)
    if messageAccessID == accessID then frame:AddMessage(text, r, g, b, typeID, messageAccessID, lineID) end
  end
  source:RemoveMessagesByPredicate(function (_, _, _, _, _, messageAccessID) return messageAccessID == accessID end)
end

local listeners, modifiers, module = {}, {}, {}
local core = {
  GetModule = function (_, name) return name == "Hyperlinks" and module or {} end,
  Subscribe = function (_, event, callback) listeners[event] = callback end,
  Localize = function (_, text) return text end,
}
local constants = {ACTIONS = {}, EVENTS = {HYPERLINK_CLICK = "click", HYPERLINK_ENTER = "enter", HYPERLINK_LEAVE = "leave"}}
hooksecurefunc = function () end
Menu = {ModifyMenu = function (tag, callback) modifiers[tag] = callback end}
MenuUtil = {GetElementText = function (element) return element.text end}
local lastResponder
SetItemRef = function ()
  local element = {text = MOVE_TO_NEW_WINDOW, SetResponder = function (_, callback) lastResponder = callback end}
  local root = {element}
  function root:EnumerateElementDescriptions() return ipairs(self) end
  modifiers.MENU_CHAT_FRAME_CHANNEL(nil, root)
end

NUM_CHAT_WINDOWS = 6
local opened, selected, flashed = 0
FCF_GetChatWindowInfo = function (index) return nil, nil, nil, nil, nil, nil, _G["ChatFrame"..index].active end
FCF_CanOpenNewWindow = function ()
  for index = 3, NUM_CHAT_WINDOWS do
    if not _G["ChatFrame"..index].active then return true end
  end
  return false
end
FCF_SelectDockFrame = function (frame) selected = frame end
FCF_FlashTab = function (frame) flashed = frame end
FCF_CopyChatSettings = function () end

local function removeValue(list, value)
  for index, item in pairs(list) do if item == value then list[index] = nil end end
end
local function newFrame(index)
  local frame = {messageTypeList = {}, channelList = {}, history = {}, active = index <= 2, isDocked = index <= 2}
  frame.editBox = {SetChatType = function () end, SetStickyType = function () end, SetChannelTarget = function () end}
  function frame:RemoveAllMessageGroups() self.messageTypeList = {} end
  function frame:RemoveAllChannels() self.channelList = {} end
  function frame:ReceiveAllPrivateMessages() end
  function frame:AddMessageGroup(group) self.messageTypeList[#self.messageTypeList + 1] = group end
  function frame:AddChannel(channel) self.channelList[#self.channelList + 1] = channel end
  function frame:RemoveMessageGroup(group) removeValue(self.messageTypeList, group) end
  function frame:RemoveChannel(channel) removeValue(self.channelList, channel) end
  function frame:GetNumMessages() return #self.history end
  function frame:GetMessageInfo(line) return unpack(self.history[line]) end
  function frame:AddMessage(...) self.history[#self.history + 1] = {...} end
  function frame:RemoveMessagesByPredicate(predicate)
    for line = #self.history, 1, -1 do
      if predicate(unpack(self.history[line])) then table.remove(self.history, line) end
    end
  end
  return frame
end
FCF_OpenNewWindow = function ()
  assert(FCF_CanOpenNewWindow(), "Native PopOutChat must never reach window creation while full")
  for index = 3, NUM_CHAT_WINDOWS do
    local frame = _G["ChatFrame"..index]
    if not frame.active then
      opened = opened + 1
      frame.active, frame.isDocked = true, true
      return frame
    end
  end
end
local function reset()
  opened, selected, flashed = 0, nil, nil
  for index = 1, NUM_CHAT_WINDOWS do _G["ChatFrame"..index] = newFrame(index) end
end
local function click(frame, link)
  listeners.click({link or "channel:GUILD", "[Guild]", "RightButton", frame})
  return lastResponder
end
local function message(frame, accessID, text)
  frame:AddMessage(text or "history", 1, 1, 1, 1, accessID, 1)
end
assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
module:OnInitialize()
module:OnEnable()

reset()
ChatFrame1.messageTypeList = {"SAY", "GUILD", "GUILD_ACHIEVEMENT", "GUILD_ITEM_LOOTED"}
message(ChatFrame1, "GUILD:")
message(ChatFrame1, "SAY:")
local stale = click(ChatFrame1)
stale()
assert(opened == 1 and #ChatFrame3.history == 1 and #ChatFrame1.history == 1)
assert(ChatFrame1.history[1][6] == "SAY:" and ChatFrame1.messageTypeList[1] == "SAY")
click(ChatFrame3)()
assert(opened == 1 and selected == ChatFrame3 and #ChatFrame3.history == 1,
  "Repeating a category pop-out preserves its dedicated window and history")
stale()
assert(opened == 1 and selected == ChatFrame3, "A stale source menu reuses the moved conversation")
ChatFrame3.isDocked = false
click(ChatFrame3)()
assert(opened == 1 and flashed == ChatFrame3, "Undocked dedicated windows flash without creating a window")

reset()
ChatFrame1.messageTypeList = {"GUILD"}
message(ChatFrame1, "GUILD:")
click(ChatFrame1)()
assert(opened == 1 and #ChatFrame3.history == 1, "Single-filter General still permits its first native pop-out")
ChatFrame4.active, ChatFrame4.isDocked = true, true
ChatFrame4.messageTypeList = {"GUILD", "OFFICER"}
message(ChatFrame4, "GUILD:")
message(ChatFrame4, "OFFICER:")
click(ChatFrame4)()
assert(opened == 2 and #ChatFrame5.history == 1 and #ChatFrame4.history == 1,
  "Multi-filter custom windows retain native move behavior even with an existing Guild destination")
assert(ChatFrame4.history[1][6] == "OFFICER:")

reset()
ChatFrame1.messageTypeList = {"SAY", "CHANNEL"}
ChatFrame1.channelList = {"Trade", "General"}
message(ChatFrame1, "CHANNEL:2")
message(ChatFrame1, "CHANNEL:3")
local staleChannel = click(ChatFrame1, "channel:CHANNEL:2")
staleChannel()
assert(opened == 1 and #ChatFrame3.history == 1 and #ChatFrame1.history == 1)
assert(ChatFrame3.channelList[1] == "Trade" and ChatFrame1.channelList[2] == "General")
click(ChatFrame3, "channel:CHANNEL:2")()
staleChannel()
assert(opened == 1 and selected == ChatFrame3, "Channel targets and their native category children are recognized")
ChatFrame3.channelList[2] = "General"
click(ChatFrame3, "channel:CHANNEL:2")()
assert(opened == 2 and ChatFrame3.channelList[2] == "General", "Another subscribed channel permits a legitimate split")

reset()
ChatFrame1.messageTypeList = {"GUILD", "SAY"}
message(ChatFrame1, "GUILD:")
local capacityChanged = click(ChatFrame1)
for index = 3, NUM_CHAT_WINDOWS do _G["ChatFrame"..index].active = true end
capacityChanged()
assert(opened == 0 and #ChatFrame1.history == 1 and ChatFrame1.messageTypeList[1] == "GUILD",
  "Capacity is checked again when a stale menu action executes")

reset()
ChatFrame1.messageTypeList = {"SAY"}
ChatFrame3.messageTypeList = {"GUILD"}
click(ChatFrame1)()
assert(opened == 1, "Closed windows with stale filters are not reused")

reset()
ChatFrame1.messageTypeList = {"SAY"}
ChatFrame3.active, ChatFrame3.isDocked, ChatFrame3.isTemporary = true, true, true
ChatFrame3.messageTypeList = {"GUILD"}
click(ChatFrame1)()
assert(opened == 1 and ChatFrame4.messageTypeList[1] == "GUILD", "Temporary windows are not reused")

reset()
ChatFrame3.active, ChatFrame3.isDocked = true, true
ChatFrame3.messageTypeList = {"GUILD"}
FCF_IsChatWindowIndexReserved = function (index) return index <= 3 end
click(ChatFrame3)()
assert(opened == 1 and ChatFrame4.messageTypeList[1] == "GUILD", "Reserved windows retain their first pop-out")
FCF_IsChatWindowIndexReserved = nil

-- Clients without the modern menu API retain their native hyperlink handling.
Menu, ChatFrameUtil = nil, nil
assert(loadfile("Glassy/Modules/Hyperlinks.lua"))("Glassy", {core, constants})
module:OnInitialize()
module:OnEnable()
print("PASS: category/channel moves, repeated and stale menus, multi-filter windows, capacity, and Classic fallback")
