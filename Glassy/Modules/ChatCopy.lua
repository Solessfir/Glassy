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
  clean = clean:gsub("|r", "")
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
end

function ChatCopy:Show(chatFrame)
  chatFrame = chatFrame or getSelectedChatFrame()
  if chatFrame == nil then
    return
  end

  ensureCopyWindow()
  copyFrame:SetTitle(L("Glassy: Copy chat — ")..getFrameLabel(chatFrame))
  copyTextBox:SetText(readChatFrame(chatFrame))
  copyFrame:Show()
  copyTextBox:SetFocus()
  copyTextBox:HighlightText()
end
