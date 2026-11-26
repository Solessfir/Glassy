local Core, Constants, Utils = unpack(select(2, ...))
local WhisperWindows = Core:GetModule("WhisperWindows")
local L = function(text) return Core:Localize(text) end

local views
local panels, sparePanels = {}, {}
local panelCount = 0
local INSTRUCTIONS = "Mouse wheel scrolls messages. Press Enter or Send to reply."

local function renderPanel(panel)
  local conversation = panel.conversation
  panel.window:SetTitle("Glassy: "..conversation.name)
  local transcript = panel.transcript
  local atBottom, offset = transcript:AtBottom(), transcript:GetScrollOffset()
  transcript:Clear()
  for _, message in ipairs(conversation.messages) do
    local author = message.outgoing and L("You") or conversation.name
    local stamp = message.time and _G.date("%H:%M", message.time).." " or ""
    transcript:AddMessage(stamp..author..": "..message.text, 1, 0.75, 1)
  end
  if atBottom then transcript:ScrollToBottom() else transcript:SetScrollOffset(offset) end
end

local function acquirePanel(conversation)
  local panel = table.remove(sparePanels)
  if not panel then
    panel = {}
    panelCount = panelCount + 1
    local window = Core.Libs.AceGUI:Create("Frame")
    panel.window = window
    window:SetWidth(540)
    window:SetHeight(360)
    window:SetCallback("OnClose", function () window:Hide() end)
    window:Hide()
    window.frame:SetResizeBounds(360, 240)
    window.frame:SetClampedToScreen(true)
    -- Stagger new panels so simultaneous senders remain reachable.
    window.frame:ClearAllPoints()
    local offset = ((panelCount - 1) % 6) * 28
    window.frame:SetPoint("CENTER", _G.UIParent, "CENTER", offset, -offset)

    local transcript = _G.CreateFrame("ScrollingMessageFrame", nil, window.content)
    transcript:SetPoint("TOPLEFT", 0, -4)
    transcript:SetPoint("BOTTOMRIGHT", 0, 44)
    transcript:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlight)
    transcript:SetJustifyH("LEFT")
    transcript:SetFading(false)
    transcript:SetMaxLines(500)
    transcript:SetHyperlinksEnabled(true)
    transcript:SetScript("OnHyperlinkClick", function (_, link, text, button)
      if _G.canaccessvalue and not _G.canaccessvalue(link) then return end
      Core:Dispatch(Constants.ACTIONS.HyperlinkClick({link, text, button, _G.ChatFrame1}))
    end)
    transcript:EnableMouseWheel(true)
    transcript:SetScript("OnMouseWheel", function (frame, delta)
      if delta > 0 then frame:ScrollUp() else frame:ScrollDown() end
    end)
    panel.transcript = transcript

    local reply = _G.CreateFrame("EditBox", nil, window.content, "InputBoxTemplate")
    reply:SetAutoFocus(false)
    reply:SetMaxLetters(255)
    reply:SetPoint("BOTTOMLEFT", 6, 4)
    reply:SetPoint("BOTTOMRIGHT", -84, 4)
    reply:SetHeight(28)
    panel.reply = reply
    window.frame:HookScript("OnHide", function () reply:ClearFocus() end)

    local function sendReply()
      local text = reply:GetText()
      if not text:find("%S") then return end
      -- Retain the draft when the backend cannot hand it to the client.
      if WhisperWindows:Send(panel.conversation, text) then
        reply:SetText("")
        window:SetStatusText(L(INSTRUCTIONS))
      else
        window:SetStatusText(L("Unable to send. Your draft is kept; try /w or /r in chat."))
      end
    end
    reply:SetScript("OnEnterPressed", sendReply)
    local send = _G.CreateFrame("Button", nil, window.content, "UIPanelButtonTemplate")
    send:SetSize(74, 26)
    send:SetPoint("LEFT", reply, "RIGHT", 8, 0)
    send:SetText(L("Send"))
    send:SetScript("OnClick", sendReply)
    Core:GetModule("Ellesmere"):SkinWindow(window, {{type = "EditBox", editbox = reply}})
    Utils.closeOnEscape(window, "GlassyWhisperWindow"..panelCount, reply)
  end
  panel.conversation = conversation
  panel.reply:SetText("")
  panel.transcript:ScrollToBottom()
  panel.window:SetStatusText(L(INSTRUCTIONS))
  panels[conversation] = panel
  return panel
end

local function ensureViews()
  if views then return end
  views = {rows = {}}
  local window = Core.Libs.AceGUI:Create("Frame")
  views.window = window
  window:SetTitle("Glassy: "..L("Whispers"))
  window:SetWidth(300)
  window:SetHeight(360)
  window:SetStatusText(L("Whisper someone with /w Name-Realm to start a conversation."))
  window:SetCallback("OnClose", function () window:Hide() end)
  window:Hide()
  window.frame:SetResizeBounds(260, 240)
  window.frame:SetClampedToScreen(true)
  local list = _G.CreateFrame("ScrollFrame", nil, window.content, "UIPanelScrollFrameTemplate")
  list:SetPoint("TOPLEFT", 0, -4)
  list:SetPoint("BOTTOMRIGHT", -24, 4)
  local listChild = _G.CreateFrame("Frame", nil, list)
  listChild:SetSize(220, 1)
  list:SetScrollChild(listChild)
  list:SetScript("OnSizeChanged", function (_, width) listChild:SetWidth(width) end)
  views.listChild = listChild
  Core:GetModule("Ellesmere"):SkinWindow(window)
  Utils.closeOnEscape(window, "GlassyWhisperInboxWindow")

  local inbox = _G.CreateFrame("Button", "GlassyWhisperInbox", _G.UIParent, "UIPanelButtonTemplate")
  inbox:SetSize(150, 24)
  inbox:SetClampedToScreen(true)
  local manager = Core:GetModule("UIManager")
  inbox:SetPoint("TOPLEFT", manager.container or _G.ChatFrame1, "BOTTOMLEFT", 0, -4)
  inbox:SetText(L("Whispers"))
  inbox:SetScript("OnClick", function ()
    if window.frame:IsShown() then window:Hide() else window:Show() end
  end)
  views.inbox = inbox
end

function WhisperWindows:OpenConversation(conversation)
  if not self:IsActive() or not conversation then return end
  ensureViews()
  local panel = panels[conversation] or acquirePanel(conversation)
  renderPanel(panel)
  self:MarkRead(conversation)
  panel.window:Show()
  panel.window.frame:Raise()
  self:UpdateViews()
end

function WhisperWindows:UpdateViews(conversation, autoOpen)
  if not self:IsActive() then
    if views then
      views.window:Hide()
      views.inbox:Hide()
      for _, panel in pairs(panels) do panel.window:Hide() end
    end
    return
  end
  ensureViews()
  views.inbox:Show()
  local conversations = self:GetConversations()
  local retained = {}
  for _, item in ipairs(conversations) do retained[item] = true end
  for item, panel in pairs(panels) do
    if not retained[item] then
      panel.window:Hide()
      panel.conversation = nil
      panel.reply:SetText("")
      panel.transcript:Clear()
      panels[item] = nil
      sparePanels[#sparePanels + 1] = panel
    end
  end
  if conversation and autoOpen and retained[conversation] then
    local typing = false
    for _, panel in pairs(panels) do
      if panel.window.frame:IsShown() and panel.reply:HasFocus() then typing = true break end
    end
    -- Incoming whispers never interrupt a reply in another conversation.
    if not typing then
      local panel = panels[conversation] or acquirePanel(conversation)
      panel.window:Show()
    end
  end
  local panel = conversation and panels[conversation]
  if panel and panel.window.frame:IsShown() then
    if conversation.unread > 0 then self:MarkRead(conversation) end
    renderPanel(panel)
  end

  local totalUnread = 0
  for index, item in ipairs(conversations) do
    totalUnread = totalUnread + item.unread
    local row = views.rows[index]
    if not row then
      row = _G.CreateFrame("Button", nil, views.listChild, "UIPanelButtonTemplate")
      row:SetHeight(28)
      row:SetPoint("TOPLEFT", 0, -(index - 1) * 30)
      row:SetPoint("RIGHT")
      row:SetScript("OnClick", function (button) self:OpenConversation(button.conversation) end)
      row:SetScript("OnEnter", function (button)
        local contact = button.conversation
        _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        _G.GameTooltip:SetText(contact.name)
        if contact.unread > 0 then _G.GameTooltip:AddLine(L("Unread messages")..": "..contact.unread) end
        _G.GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function () _G.GameTooltip:Hide() end)
      views.rows[index] = row
    end
    row.conversation = item
    row:SetText(item.name..(item.unread > 0 and " ("..item.unread..")" or ""))
    row:Show()
  end
  for index = #conversations + 1, #views.rows do
    views.rows[index].conversation = nil
    views.rows[index]:Hide()
  end
  views.listChild:SetHeight(math.max(1, #conversations * 30))
  views.inbox:SetText(L("Whispers")..(totalUnread > 0 and " ("..totalUnread..")" or ""))
end
