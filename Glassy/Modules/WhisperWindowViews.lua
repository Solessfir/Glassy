local Core, Constants, Utils = unpack(select(2, ...))
local WhisperWindows = Core:GetModule("WhisperWindows")
local Ellesmere = Core:GetModule("Ellesmere")
local L = function(text) return Core:Localize(text) end

local views
local panels, sparePanels = {}, {}
local panelCount = 0
local INBOX_ICON_WIDTH = 20

local function hyperlinkClick(_, link, text, button)
  if _G.canaccessvalue and not _G.canaccessvalue(link) then return end
  Core:Dispatch(Constants.ACTIONS.HyperlinkClick({link, text, button, _G.ChatFrame1}))
end

local function createWindow(width, height, minWidth, minHeight)
  local window = Core.Libs.AceGUI:Create("Frame")
  local frame = window.frame
  local title = window.titletext
  local titleArea = title:GetParent()
  window:SetWidth(width)
  window:SetHeight(height)
  window:Hide()
  frame:SetResizeBounds(minWidth, minHeight)
  frame:SetClampedToScreen(true)
  window.statustext:GetParent():Hide()
  -- Keep AceGUI's drag and resize handlers while giving the title a full-width drag area.
  titleArea:ClearAllPoints()
  titleArea:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -2)
  titleArea:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -42, -2)
  titleArea:SetHeight(24)
  title:ClearAllPoints()
  title:SetAllPoints(titleArea)
  title:SetJustifyH("LEFT")
  title:SetTextColor(1, 1, 1)
  for _, region in ipairs({frame:GetRegions()}) do
    if region:IsObjectType("Texture") and region:GetTexture() == 131080 then region:SetAlpha(0) end
  end
  window.content:ClearAllPoints()
  window.content:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -32)
  window.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 14)
  local parts = {{type = "FontString", fontString = title}}
  for _, button in ipairs({frame:GetChildren()}) do
    if button.obj == window and button:IsObjectType("Button") and button:GetText() == _G.CLOSE then
      button:ClearAllPoints()
      button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -7, -4)
      button:SetSize(24, 20)
      button:SetText("×")
      parts[#parts + 1] = {type = "CloseButton", button = button}
      break
    end
  end
  return window, parts
end

local function createScrollArea(parent, parts)
  local scroll = _G.CreateFrame("ScrollFrame", nil, parent, "ScrollFrameTemplate")
  scroll.ScrollBar:SetHideIfUnscrollable(true)
  parts[#parts + 1] = {type = "ScrollFrame", scrollbar = scroll.ScrollBar}
  return scroll
end

local menuConversation
local function setupMenus()
  if not (_G.Menu and _G.Menu.ModifyMenu) then return end
  for _, which in ipairs({"FRIEND", "FRIEND_OFFLINE", "BN_FRIEND", "BN_FRIEND_OFFLINE", "PLAYER", "CHAT_ROSTER"}) do
    _G.Menu.ModifyMenu("MENU_UNIT_"..which, function (_, root)
      local conversation = menuConversation
      if conversation then
        root:CreateDivider()
        root:CreateButton(L("Close conversation"), function () WhisperWindows:CloseConversation(conversation) end)
      end
    end)
  end
end

function WhisperWindows:ShowConversationMenu(conversation, owner)
  if not self:IsActive() or not conversation then return end
  if conversation.name:find("[|:%c]") then return end
  if not conversation.battleNet and conversation.target:find("[|:/\\%c]") then return end
  local link = conversation.battleNet and "BNplayer:"..conversation.name..":"..conversation.target
    or "player:"..conversation.target
  -- Report links only contain an incoming message ID from this session.
  if conversation.lineID then
    link = link..":"..conversation.lineID..(conversation.battleNet and ":BN_WHISPER:" or ":WHISPER:")..conversation.target
  end
  if _G.SetItemRef then
    menuConversation = conversation
    Core:Dispatch(Constants.ACTIONS.HyperlinkClick({link, conversation.name, "RightButton", _G.ChatFrame1}))
    menuConversation = nil
  elseif _G.MenuUtil and _G.MenuUtil.CreateContextMenu then
    _G.MenuUtil.CreateContextMenu(owner, function (_, root)
      if not conversation.battleNet then
        local invite = (_G.C_PartyInfo and _G.C_PartyInfo.InviteUnit) or _G.InviteUnit
        if invite then root:CreateButton(_G.INVITE or L("Invite"), function () invite(conversation.target) end) end
      end
      root:CreateButton(_G.COPY_CHARACTER_NAME or L("Copy name"), function ()
        Core:GetModule("ChatCopy"):ShowText(L("Glassy: Copy name"), conversation.name)
      end)
      root:CreateButton(L("Close conversation"), function () self:CloseConversation(conversation) end)
    end)
  end
end

local function panelAtBottom(panel)
  if Core.db.profile.whisperWindowsBubbles then
    return panel.bubbles:GetVerticalScroll() >= panel.bubbles:GetVerticalScrollRange() - 1
  end
  return panel.transcript:AtBottom()
end

local function markPanelRead(panel)
  if not panel.rendering and panel.conversation and panel.window.frame:IsShown() and panelAtBottom(panel)
    and panel.conversation.unread > 0 then
    WhisperWindows:MarkRead(panel.conversation)
    return true
  end
  return false
end

local function onPanelScroll(panel)
  if WhisperWindows:IsActive() and markPanelRead(panel) then WhisperWindows:UpdateViews() end
end

local function renderBubbles(panel)
  if panel.rendering then return end
  panel.rendering = true
  local scroll, child = panel.bubbles, panel.bubbleChild
  local range, offset = scroll:GetVerticalScrollRange(), scroll:GetVerticalScroll()
  local atBottom = not panel.bubbleLayout or offset >= range - 1
  local anchor, inset
  if not atBottom then
    for _, entry in ipairs(panel.bubbleLayout) do
      if entry.bottom > offset then
        anchor, inset = entry.message, offset - entry.top
        break
      end
    end
  end
  local width = math.max(120, scroll:GetWidth() - 8)
  child:SetWidth(width)
  local height, layout, anchoredOffset = 4, {}, nil
  for index, message in ipairs(panel.conversation.messages) do
    local row = panel.bubbleRows[index]
    if not row then
      row = _G.CreateFrame("Frame", nil, child)
      row.background = row:CreateTexture(nil, "BACKGROUND")
      row.background:SetAllPoints()
      row.background:SetTexture("Interface\\Buttons\\WHITE8x8")
      row.text = row:CreateFontString(nil, "OVERLAY", "ChatFontNormal")
      row.text:SetPoint("TOPLEFT", 8, -6)
      row.text:SetJustifyH("LEFT")
      row.text:SetWordWrap(true)
      row:SetHyperlinksEnabled(true)
      row:SetScript("OnHyperlinkClick", hyperlinkClick)
      panel.bubbleRows[index] = row
    end
    local rowWidth = width * 0.82
    row.text:SetWidth(rowWidth - 16)
    local author = message.outgoing and L("You") or panel.conversation.name
    local stamp = message.time and _G.date("%H:%M", message.time).." " or ""
    row.text:SetText(stamp..author.."\n"..message.text)
    local rowHeight = row.text:GetStringHeight() + 12
    row:SetSize(rowWidth, rowHeight)
    row:ClearAllPoints()
    row:SetPoint(message.outgoing and "TOPRIGHT" or "TOPLEFT", child, message.outgoing and "TOPRIGHT" or "TOPLEFT", 0, -height)
    row.background:SetVertexColor(message.outgoing and 0.28 or 0.12, 0.12, message.outgoing and 0.34 or 0.18, 0.9)
    row:Show()
    layout[index] = {message = message, top = height, bottom = height + rowHeight + 6}
    if message == anchor then anchoredOffset = height + inset end
    height = height + rowHeight + 6
  end
  for index = #panel.conversation.messages + 1, #panel.bubbleRows do panel.bubbleRows[index]:Hide() end
  child:SetHeight(height)
  scroll:UpdateScrollChildRect()
  -- Retained messages keep their position even when the oldest rows leave the history cap.
  scroll:SetVerticalScroll(atBottom and scroll:GetVerticalScrollRange()
    or math.max(0, math.min(anchoredOffset or 0, scroll:GetVerticalScrollRange())))
  panel.bubbleLayout = layout
  panel.rendering = false
end

local function renderPanel(panel)
  local conversation = panel.conversation
  panel.window:SetTitle(conversation.name)
  local bubbles = Core.db.profile.whisperWindowsBubbles == true
  panel.rendering = true
  panel.bubbles:SetShown(bubbles)
  panel.transcript:SetShown(not bubbles)
  if bubbles then
    panel.rendering = false
    renderBubbles(panel)
    return
  end
  local transcript = panel.transcript
  local atBottom, offset = transcript:AtBottom(), transcript:GetScrollOffset()
  local previous = panel.transcriptMessages or {}
  local anchor = previous[#previous - offset]
  local messages, anchoredOffset = {}, nil
  transcript:Clear()
  for index, message in ipairs(conversation.messages) do
    messages[index] = message
    if message == anchor then anchoredOffset = #conversation.messages - index end
    local author = message.outgoing and L("You") or conversation.name
    local stamp = message.time and _G.date("%H:%M", message.time).." " or ""
    transcript:AddMessage(stamp..author..": "..message.text, 1, 0.75, 1)
  end
  if atBottom then transcript:ScrollToBottom()
  else transcript:SetScrollOffset(anchoredOffset or math.max(0, #messages - 1)) end
  panel.transcriptMessages = messages
  panel.rendering = false
end

local function setReplyError(panel, message)
  local label = panel.error
  label:SetText(message or "")
  if message then label:SetHeight(0) end
  label:SetHeight(message and math.max(1, label:GetStringHeight()) or 1)
  label:SetShown(message ~= nil)
end

local function acquirePanel(conversation)
  local panel = table.remove(sparePanels)
  if not panel then
    panel = {}
    panelCount = panelCount + 1
    local window, parts = createWindow(540, 360, 360, 240)
    panel.window = window
    -- Stagger new panels so simultaneous senders remain reachable.
    window.frame:ClearAllPoints()
    local offset = ((panelCount - 1) % 6) * 28
    window.frame:SetPoint("CENTER", _G.UIParent, "CENTER", offset, -offset)

    local transcript = _G.CreateFrame("ScrollingMessageFrame", nil, window.content)
    transcript:SetPoint("TOPLEFT", 0, -4)
    transcript:SetFontObject(_G.ChatFontNormal or _G.GameFontHighlight)
    transcript:SetJustifyH("LEFT")
    transcript:SetFading(false)
    transcript:SetMaxLines(500)
    transcript:SetHyperlinksEnabled(true)
    transcript:SetScript("OnHyperlinkClick", hyperlinkClick)
    transcript:EnableMouseWheel(true)
    transcript:SetScript("OnMouseWheel", function (frame, delta)
      if delta > 0 then frame:ScrollUp() else frame:ScrollDown() end
      onPanelScroll(panel)
    end)
    if transcript.SetOnScrollChangedCallback then
      transcript:SetOnScrollChangedCallback(function () onPanelScroll(panel) end)
    else
      transcript:SetScript("OnMessageScrollChanged", function () onPanelScroll(panel) end)
    end
    panel.transcript = transcript

    local bubbles = createScrollArea(window.content, parts)
    bubbles:SetPoint("TOPLEFT", 0, -4)
    local child = _G.CreateFrame("Frame", nil, bubbles)
    child:SetSize(1, 1)
    bubbles:SetScrollChild(child)
    panel.bubbles, panel.bubbleChild, panel.bubbleRows = bubbles, child, {}
    bubbles:EnableMouseWheel(true)
    bubbles:SetScript("OnMouseWheel", function (frame, delta)
      frame:SetVerticalScroll(math.max(0, math.min(frame:GetVerticalScrollRange(), frame:GetVerticalScroll() - delta * 30)))
      onPanelScroll(panel)
    end)
    bubbles:HookScript("OnVerticalScroll", function () onPanelScroll(panel) end)
    bubbles:SetScript("OnSizeChanged", function ()
      if panel.conversation and Core.db.profile.whisperWindowsBubbles then
        renderBubbles(panel)
        onPanelScroll(panel)
      end
    end)
    local function openMenu(_, button)
      if button == "RightButton" then WhisperWindows:ShowConversationMenu(panel.conversation, window.frame) end
    end
    window.frame:HookScript("OnMouseUp", openMenu)
    window.titletext:GetParent():HookScript("OnMouseUp", openMenu)

    local replyError = window.content:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    replyError:SetPoint("BOTTOMLEFT", 2, 0)
    replyError:SetPoint("BOTTOMRIGHT", -2, 0)
    replyError:SetJustifyH("LEFT")
    replyError:SetWordWrap(true)
    replyError:SetTextColor(1, 0.5, 0.5)
    panel.error = replyError
    parts[#parts + 1] = {type = "FontString", fontString = replyError}
    local reply = _G.CreateFrame("EditBox", nil, window.content, "InputBoxTemplate")
    reply:SetAutoFocus(false)
    reply:SetMaxLetters(255)
    reply:SetPoint("BOTTOMLEFT", replyError, "TOPLEFT", 4, 4)
    reply:SetPoint("BOTTOMRIGHT", replyError, "TOPRIGHT", -84, 4)
    reply:SetHeight(28)
    transcript:SetPoint("BOTTOMRIGHT", reply, "TOPRIGHT", 86, 8)
    bubbles:SetPoint("BOTTOMRIGHT", reply, "TOPRIGHT", 68, 8)
    panel.reply = reply
    window.frame:HookScript("OnHide", function () reply:ClearFocus() end)

    local function sendReply()
      local text = reply:GetText()
      if not text:find("%S") then return end
      -- Retain the draft when the backend cannot hand it to the client.
      if WhisperWindows:Send(panel.conversation, text) then
        reply:SetText("")
        setReplyError(panel)
      else
        setReplyError(panel, L("Unable to send. Your draft was kept. Try /w or /r in chat."))
      end
    end
    reply:SetScript("OnEnterPressed", sendReply)
    local send = _G.CreateFrame("Button", nil, window.content, "UIPanelButtonTemplate")
    send:SetSize(74, 26)
    send:SetPoint("LEFT", reply, "RIGHT", 8, 0)
    send:SetText(L("Send"))
    send:SetScript("OnClick", sendReply)
    parts[#parts + 1] = {type = "EditBox", editbox = reply}
    parts[#parts + 1] = {type = "Button", button = send}
    Ellesmere:SkinWindow(window, parts)
    Utils.closeOnEscape(window, "GlassyWhisperWindow"..panelCount, reply)
  end
  panel.rendering = true
  panel.conversation = conversation
  panel.bubbleLayout, panel.transcriptMessages = nil, nil
  panel.reply:SetText("")
  panel.transcript:ScrollToBottom()
  panel.bubbles:SetVerticalScroll(0)
  panel.rendering = false
  setReplyError(panel)
  panels[conversation] = panel
  return panel
end

function Core:GetWhisperInboxColor(highlighted)
  local color = self.db.profile[highlighted and "whisperInboxHoverColor" or "whisperInboxColor"]
  if color and color.r >= 0 then return color end
  return self:GetThemeColor(highlighted and "tabHighlightTextColor" or "tabTextColor")
end

local function updateInboxColor(inbox)
  local color = Core:GetWhisperInboxColor(inbox.hovered or inbox.unread > 0)
  inbox.icon:SetVertexColor(color.r, color.g, color.b, color.a or 1)
  inbox.count:SetTextColor(color.r, color.g, color.b, color.a or 1)
end

local function setInboxShown(shown)
  local inbox = views.inbox
  if inbox:IsShown() == shown then return end
  inbox:SetShown(shown)
  views.dock:ScheduleTabOrder()
end

local function ensureViews()
  if views then return end
  local dock = Core:GetModule("UIManager").dock
  views = {rows = {}, dock = dock}
  setupMenus()
  local window, parts = createWindow(300, 310, 260, 200)
  views.window = window
  window:SetTitle(L("Whispers"))
  local empty = window.content:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  empty:SetPoint("LEFT", 14, 8)
  empty:SetPoint("RIGHT", -14, 8)
  empty:SetJustifyH("CENTER")
  empty:SetWordWrap(true)
  empty:SetText(L("No whispers yet.").."\n\n"..L("Use /w Name-Realm to start a conversation."))
  parts[#parts + 1] = {type = "FontString", fontString = empty}
  local list = createScrollArea(window.content, parts)
  list:SetPoint("TOPLEFT", 0, -4)
  list:SetPoint("BOTTOMRIGHT", -18, 4)
  local listChild = _G.CreateFrame("Frame", nil, list)
  listChild:SetSize(220, 1)
  list:SetScrollChild(listChild)
  list:SetScript("OnSizeChanged", function (_, width) listChild:SetWidth(width) end)
  views.list, views.listChild, views.empty = list, listChild, empty
  Ellesmere:SkinWindow(window, parts)
  Utils.closeOnEscape(window, "GlassyWhisperInboxWindow")

  local inbox = _G.CreateFrame("Button", "GlassyWhisperInbox", dock)
  inbox:SetSize(INBOX_ICON_WIDTH, Constants.DOCK_HEIGHT)
  inbox:SetPoint("LEFT", dock, "LEFT", 0, 0)
  inbox:Hide()
  inbox.unread = 0
  inbox.icon = inbox:CreateTexture(nil, "ARTWORK")
  inbox.icon:SetTexture("Interface\\AddOns\\Glassy\\Glassy\\Assets\\chatButtonIcons")
  inbox.icon:SetTexCoord(7 / 8, 1, 0, 1)
  inbox.icon:SetSize(16, 16)
  inbox.icon:SetPoint("LEFT", 2, 1)
  inbox.count = inbox:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  inbox.count:SetPoint("LEFT", inbox, "LEFT", INBOX_ICON_WIDTH, 0)
  inbox:SetScript("OnEnter", function (button)
    button.hovered = true
    updateInboxColor(button)
    _G.GameTooltip:SetOwner(button, "ANCHOR_TOP")
    _G.GameTooltip:SetText(L("Whispers"))
    if button.unread > 0 then
      _G.GameTooltip:AddLine(L("Unread messages")..": "..button.unread)
    end
    _G.GameTooltip:Show()
  end)
  inbox:SetScript("OnLeave", function (button)
    button.hovered = nil
    updateInboxColor(button)
    _G.GameTooltip:Hide()
  end)
  Core:Subscribe(Constants.EVENTS.UPDATE_CONFIG, function (key)
    if key == "tabTextColor" or key == "tabHighlightTextColor" or key == "whisperInboxColor"
      or key == "whisperInboxHoverColor" then updateInboxColor(inbox) end
  end)
  inbox:SetScript("OnClick", function ()
    if window.frame:IsShown() then window:Hide() else window:Show() end
  end)
  views.inbox, dock.glassyWhisperInbox = inbox, inbox
  updateInboxColor(inbox)
end

function WhisperWindows:OpenConversation(conversation, focus)
  if not self:IsActive() or not conversation then return end
  ensureViews()
  local panel = panels[conversation] or acquirePanel(conversation)
  renderPanel(panel)
  panel.window:Show()
  markPanelRead(panel)
  panel.window.frame:Raise()
  self:UpdateViews()
  if focus then panel.reply:SetFocus() end
  return not focus or panel.reply:HasFocus()
end

function WhisperWindows:IsConversationPinned(conversation)
  local panel = panels[conversation]
  if not panel then return false end
  if panel.window.frame:IsShown() then return true end
  local draft = panel.reply:GetText()
  return (_G.canaccessvalue and not _G.canaccessvalue(draft)) or (type(draft) == "string" and draft ~= "")
end

function WhisperWindows:UpdateViews(conversation, autoOpen)
  if not self:IsActive() then
    if views then
      views.window:Hide()
      setInboxShown(false)
      for _, panel in pairs(panels) do panel.window:Hide() end
    end
    return
  end
  ensureViews()
  setInboxShown(true)
  local conversations = self:GetConversations()
  views.list:SetShown(#conversations > 0)
  views.empty:SetShown(#conversations == 0)
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
  for item, panel in pairs(panels) do
    if panel.window.frame:IsShown() and (not conversation or item == conversation) then
      renderPanel(panel)
      markPanelRead(panel)
    end
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
      row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
      row:SetScript("OnClick", function (button, mouseButton)
        if mouseButton == "RightButton" then self:ShowConversationMenu(button.conversation, button)
        else self:OpenConversation(button.conversation) end
      end)
      row:SetScript("OnEnter", function (button)
        local contact = button.conversation
        _G.GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
        _G.GameTooltip:SetText(contact.name)
        if contact.unread > 0 then _G.GameTooltip:AddLine(L("Unread messages")..": "..contact.unread) end
        _G.GameTooltip:Show()
      end)
      row:SetScript("OnLeave", function () _G.GameTooltip:Hide() end)
      Ellesmere:SkinPart({type = "Button", button = row})
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
  local inbox = views.inbox
  local newUnread = totalUnread > inbox.unread
  inbox.unread = totalUnread
  inbox.count:SetText(totalUnread > 99 and "99+" or (totalUnread > 0 and tostring(totalUnread) or ""))
  local width = INBOX_ICON_WIDTH
  if totalUnread > 0 then width = width + 2 + math.ceil(inbox.count:GetStringWidth()) end
  if width ~= inbox:GetWidth() then
    inbox:SetWidth(width)
    views.dock:ScheduleTabOrder()
  end
  updateInboxColor(inbox)
  if newUnread then
    local dock = views.dock
    dock:Show()
    if not dock.state.mouseOver then dock:UpdateAutomaticVisibility() end
  end
end

local lastLink, lastLinkAt
local function insertIntoReply(link)
  if not WhisperWindows:IsActive() or (_G.canaccessvalue and not _G.canaccessvalue(link)) or type(link) ~= "string" then return end
  local now = _G.GetTime and _G.GetTime()
  if now and link == lastLink and lastLinkAt == now then return end
  for _, panel in pairs(panels) do
    if panel.window.frame:IsShown() and panel.reply:HasFocus() then
      lastLink, lastLinkAt = link, now
      panel.reply:Insert(link)
      return
    end
  end
end
if _G.hooksecurefunc then
  if _G.ChatFrameUtil and _G.ChatFrameUtil.InsertLink then _G.hooksecurefunc(_G.ChatFrameUtil, "InsertLink", insertIntoReply) end
  if _G.ChatEdit_InsertLink then _G.hooksecurefunc("ChatEdit_InsertLink", insertIntoReply) end
end
