local Core, Constants = unpack(select(2, ...))
local News = Core:GetModule("News")

local AceGUI = Core.Libs.AceGUI
local L = function(text) return Core:Localize(text) end

local OPEN_NEWS = Constants.EVENTS.OPEN_NEWS
local ISSUES_URL = "https://github.com/Solessfir/Glassy/issues"

local function setLabelFont(label, size)
  if _G.GameFontHighlight then
    local path, _, flags = _G.GameFontHighlight:GetFont()
    label:SetFont(path, size, flags)
  end
end

local function setGlassBackground(widget)
  local engine = _G.ElvUI and _G.ElvUI[1]
  local color = engine and engine.media and engine.media.backdropcolor
  local r, g, b = 0.1, 0.1, 0.1
  if color then
    r, g, b = color.r or color[1], color.g or color[2], color.b or color[3]
  end
  local background = widget.frame and (widget.frame.backdrop or widget.frame)
  if background and background.SetBackdropColor then
    background.customBackdropAlpha = 0.95
    background:SetBackdropColor(r, g, b, 0.95)
  end
end

local issueFrame
local issueEditBox

function News:ShowIssueLink()
  if issueFrame == nil then
    issueFrame = AceGUI:Create("Frame")
    issueFrame:SetTitle("Glassy: "..L("Report an issue"))
    issueFrame:SetWidth(620)
    issueFrame:SetHeight(150)
    issueFrame:SetStatusText(L("Press Ctrl+C to copy, then close this window."))
    issueFrame:SetCallback("OnClose", function(widget)
      widget:Hide()
    end)
    issueFrame:SetLayout("Fill")

    issueEditBox = AceGUI:Create("EditBox")
    issueEditBox:SetLabel("GitHub Issues")
    issueEditBox:DisableButton(true)
    issueFrame:AddChild(issueEditBox)
  end

  setGlassBackground(issueFrame)
  issueEditBox:SetText(ISSUES_URL)
  issueFrame:Show()
  issueEditBox:SetFocus()
  issueEditBox:HighlightText()
end

local CHANGELOG = Core.NewsEntries

-- Module
function News:OnEnable()
  local labels = {}
  local frame = AceGUI:Create("Frame")
  frame:SetTitle(L("Glassy: Version history"))
  frame:SetWidth(800)
  frame:SetHeight(600)
  frame:SetStatusText(L("Version:").." "..Core.Version)
  frame:SetCallback("OnClose", function(widget) frame:Hide() end)
  frame:SetLayout("Fill")
  setGlassBackground(frame)
  frame:Hide()

  local scrollFrame = AceGUI:Create("ScrollFrame")
  scrollFrame:SetLayout("List")
  frame:AddChild(scrollFrame)

  for _, release in ipairs(CHANGELOG) do
    local releaseLabel = AceGUI:Create("Label")
    releaseLabel:SetRelativeWidth(1)
    setLabelFont(releaseLabel, 14)
    labels[#labels + 1] = {releaseLabel, 14}
    releaseLabel:SetText("|c00DFBA69"..release.name.."|r")
    scrollFrame:AddChild(releaseLabel)

    for i, item in ipairs(release.items) do
      local itemLabel = AceGUI:Create("Label")
      itemLabel:SetRelativeWidth(1)
      setLabelFont(itemLabel, 13)
      labels[#labels + 1] = {itemLabel, 13}
      itemLabel.label:SetSpacing(3.2)
      itemLabel.label:SetAlpha(0.95)

      local prefix, suffix = "", ""

      if i == 1 then
        prefix = "\n"
      end

      if i == #release.items then
        suffix = "\n"
      end

      itemLabel:SetText(prefix..item..suffix)
      scrollFrame:AddChild(itemLabel)
    end
  end

  Core:Subscribe(OPEN_NEWS, function ()
    setGlassBackground(frame)
    for _, entry in ipairs(labels) do
      setLabelFont(entry[1], entry[2])
    end
    frame:Show()
    scrollFrame:DoLayout()
  end)
end
