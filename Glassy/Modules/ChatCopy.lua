local Core = unpack(select(2, ...))
local ChatCopy = Core:GetModule("ChatCopy")
local TP = Core:GetModule("TextProcessing")

local AceGUI = Core.Libs.AceGUI
local L = function(text) return Core:Localize(text) end
local MAX_COPY_BYTES = 60000

-- WoW provides these globals at runtime, so suppress Luacheck's undefined-global warning while localizing them.
-- luacheck: push ignore 113
local DEFAULT_CHAT_FRAME = DEFAULT_CHAT_FRAME
-- luacheck: pop

local copyFrame
local copyTextBox

local function stripChatMarkup(text)
  if _G.canaccessvalue and not _G.canaccessvalue(text) then return "<protected>" end
  if type(text) ~= "string" then
    return nil
  end

  local clean = text
  clean = clean:gsub("|K.-|k", "<protected>")
  clean = clean:gsub("|H.-|h(.-)|h", "%1")
  clean = clean:gsub("|A.-|a", "")
  clean = clean:gsub("|T.-|t", "")
  clean = clean:gsub("|c%x%x%x%x%x%x%x%x", "")
  clean = clean:gsub("|cn[%w_]+:", "")
  clean = clean:gsub("|r", "")
  -- Chat font strings resolve "|4singular:plural;" from the preceding number; edit boxes print it raw.
  clean = clean:gsub("(%d*)(%s*)|4([^;]*);", function (number, space, forms)
    local list = {strsplit(":", forms)}
    local n = tonumber(number)
    local form = list[#list]
    if n and #list >= 3 then
      local mod10, mod100 = n % 10, n % 100
      form = (mod10 == 1 and mod100 ~= 11) and list[1]
        or (mod10 >= 2 and mod10 <= 4 and (mod100 < 12 or mod100 > 14)) and list[2]
        or list[3]
    elseif n == 1 then
      form = list[1]
    end
    return number..space..form
  end)
  clean = clean:gsub("||", "|")
  return clean
end

local function getSelectedChatFrame()
  return _G.SELECTED_CHAT_FRAME or
    (_G.GeneralDockManager and _G.GeneralDockManager.selected) or
    DEFAULT_CHAT_FRAME
end

local function getFrameLabel(chatFrame)
  local tab = chatFrame and _G[chatFrame:GetName().."Tab"]
  local label = tab and tab.Text and tab.Text:GetText()

  if label == nil or label == "" then
    label = chatFrame and chatFrame:GetName() or L("Chat")
  end

  return label
end

local function readChatFrame(chatFrame)
  local reverseLines = {}
  local bytesUsed = 0
  local limit = tonumber(Core.db.profile.scrollbackLines) or Core.defaults.profile.scrollbackLines
  limit = math.max(1, math.floor(limit))
  local count = chatFrame and chatFrame:GetNumMessages() or 0
  local first = math.max(1, count - limit + 1)

  -- Blizzard's hidden chat frame already retains lightweight history.
  -- Read it newest-first so the copy window remains bounded without cutting old lines.
  for index = count, first, -1 do
    local text = stripChatMarkup(chatFrame:GetMessageInfo(index))
    if text and text ~= "" and not TP:IsMessageBlacklisted(text) then
      local separatorBytes = #reverseLines > 0 and 1 or 0
      if bytesUsed + separatorBytes + #text > MAX_COPY_BYTES then
        break
      end

      reverseLines[#reverseLines + 1] = text
      bytesUsed = bytesUsed + separatorBytes + #text
    end
  end

  if #reverseLines == 0 then
    if count > 0 then
      return L("The newest chat message exceeds Glassy's 60,000-character copy limit.")
    end

    return L("This chat tab has no messages to copy.")
  end

  local lines = {}
  for index = #reverseLines, 1, -1 do
    lines[#lines + 1] = reverseLines[index]
  end

  return table.concat(lines, "\n")
end

local function ensureCopyWindow()
  if copyFrame ~= nil then
    return
  end

  copyFrame = AceGUI:Create("Frame")
  copyFrame:SetWidth(760)
  copyFrame:SetHeight(500)
  copyFrame:SetStatusText(L("Press Ctrl+C to copy, then close this window."))
  copyFrame:SetCallback("OnClose", function(widget)
    widget:Hide()
  end)
  copyFrame:SetLayout("Fill")

  copyTextBox = AceGUI:Create("MultiLineEditBox")
  copyTextBox:SetLabel(L("All text is selected"))
  copyTextBox:DisableButton(true)
  copyFrame:AddChild(copyTextBox)
  Core:GetModule("Ellesmere"):SkinWindow(copyFrame, {copyTextBox})
end

function ChatCopy:ShowText(title, text)
  ensureCopyWindow()
  copyFrame:SetTitle(title)
  copyTextBox:SetText(text)
  copyFrame:Show()
  copyTextBox:SetFocus()
  copyTextBox:HighlightText()
end

function ChatCopy:Show(chatFrame)
  chatFrame = chatFrame or getSelectedChatFrame()
  if chatFrame == nil then
    return
  end

  self:ShowText(L("Glassy: Copy chat — ")..getFrameLabel(chatFrame), readChatFrame(chatFrame))
end

local SEARCH_RESULT_LIMIT = 200
local searchFrame
local searchInput
local searchResults

local function toHex(value)
  return string.format("%02x", math.floor(math.max(0, math.min(1, value or 1)) * 255 + 0.5))
end

-- Newest first, in each message's chat color. Secret and blocked lines are never searched.
local function searchChatFrame(chatFrame, query)
  local lines, found = {}, 0
  query = query:lower()
  for index = chatFrame:GetNumMessages(), 1, -1 do
    local text, red, green, blue = chatFrame:GetMessageInfo(index)
    local plain = (not _G.canaccessvalue or _G.canaccessvalue(text)) and stripChatMarkup(text)
    if plain and plain:lower():find(query, 1, true) and not TP:IsMessageBlacklisted(plain) then
      found = found + 1
      if found <= SEARCH_RESULT_LIMIT then
        lines[#lines + 1] = "|cff"..toHex(red)..toHex(green)..toHex(blue)..plain:gsub("|", "||").."|r"
      end
    end
  end
  return lines, found
end

local function updateSearch()
  local query = searchInput:GetText() or ""
  if query == "" then
    searchResults:SetLabel(L("Type to search"))
    searchResults:SetText("")
    return
  end
  local lines, found = searchChatFrame(searchFrame.chatFrame, query)
  if found == 0 then
    searchResults:SetLabel(L("No messages found"))
  elseif found > SEARCH_RESULT_LIMIT then
    local shown = " ("..L("showing the newest").." "..SEARCH_RESULT_LIMIT..")"
    searchResults:SetLabel(L("Messages found:").." "..found..shown)
  else
    searchResults:SetLabel(L("Messages found:").." "..found)
  end
  searchResults:SetText(table.concat(lines, "\n"))
end

local function ensureSearchWindow()
  if searchFrame ~= nil then
    return
  end

  searchFrame = AceGUI:Create("Frame")
  searchFrame:SetWidth(640)
  searchFrame:SetHeight(460)
  searchFrame:SetStatusText(L("Results can be selected and copied with Ctrl+C."))
  searchFrame:SetCallback("OnClose", function (widget)
    widget:Hide()
  end)
  searchFrame:SetLayout("Flow")

  searchInput = AceGUI:Create("EditBox")
  searchInput:SetLabel(L("Search messages"))
  searchInput:SetFullWidth(true)
  searchInput:DisableButton(true)
  searchInput:SetCallback("OnTextChanged", updateSearch)
  searchFrame:AddChild(searchInput)

  searchResults = AceGUI:Create("MultiLineEditBox")
  searchResults:SetFullWidth(true)
  searchResults:SetFullHeight(true)
  searchResults:DisableButton(true)
  searchFrame:AddChild(searchResults)
  Core:GetModule("Ellesmere"):SkinWindow(searchFrame, {searchInput, searchResults})
end

function ChatCopy:ShowSearch(chatFrame)
  chatFrame = chatFrame or getSelectedChatFrame()
  if chatFrame == nil then
    return
  end

  ensureSearchWindow()
  searchFrame.chatFrame = chatFrame
  searchFrame:SetTitle(L("Glassy: Search — ")..getFrameLabel(chatFrame))
  searchFrame:Show()
  updateSearch()
  searchInput:SetFocus()
end
