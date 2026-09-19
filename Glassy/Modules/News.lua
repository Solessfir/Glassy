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

-- Release notes preserve their authored formatting, so suppress Luacheck's line-length warning for this table.
-- luacheck: push ignore 631
local CHANGELOG = {
  {
    name = "1.9.3 (Unreleased)",
    items = {[[
Maintenance update

- Consolidated normal, temporary, and detached chat-window state into one lifecycle-managed record per Blizzard chat frame.
- Split chat rendering initialization, UI startup, and settings-page construction into focused functions without changing behavior.
- Added regression coverage for chat-window registration, detaching, resizing, tab replacement, redocking, cleanup, and reopening.
    ]]}
  },
  {
    name = "1.9.2 (2026-09-19)",
    items = {[[
What's new

- Glassy now styles and manages detached chat windows while preserving their Blizzard-managed position and size.
- Added profile export and import, including options to create a new profile or replace the current one.
- Added an optional message blacklist that hides messages containing configured phrases, including restored Prat history.
- Added full interface localization for English, German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian, Simplified Chinese, and Traditional Chinese.
- Added an option to reveal faded messages while typing.
- Added configurable tab hover highlighting, message and edit-box separators, message spacing, edit-box padding, and unread-message appearance.
- Reorganized settings with dedicated Shortcuts and About pages. Use /gl news to reopen these notes.

Bug fixes

- Chat tabs stay hidden after login or /reload until the chat is hovered.
- Large Prat histories are restored over multiple frames to prevent script timeouts.
- Protected keyboard-input calls are avoided during combat.
- Improved frame bounds, edit-box spacing, unread-message placement, and Combat Log tab behavior.
- Added Classic Forever interface 16001 support.
    ]]}
  },
  {
    name = "1.9.1 (2026-09-14)",
    items = {[[
What's new

- This fork is now Glassy! Open settings with /gl. /glassy and /glass still work.
- Releases are available from GitHub, CurseForge, and Wago Addons.
- Added support for Burning Crusade Anniversary, Mists of Pandaria Classic, and Retail alongside Classic Era and Hardcore.
- Updated the installation guide, addon compatibility notes, and GitHub links.

Bug fixes

- Fixed hidden chat input and conflicts with Prat TellTarget. Keep Prat's Editbox module disabled and reload after changing it.
- Fixed missing Retail tabs and repeated mouse-hover errors.
- Fixed Retail Combat Log protected-action errors when switching tabs or using its filter buttons.
- Protected Retail message text is displayed without parsing and replaced with <protected> when copied.

On Retail, chat tab selection and reordering now work without protected-action errors.
    ]]}
  },
  {
    name = "1.9.0 (2026-08-26)",
    items = {[[
What's new

- New: Shift-click a chat tab to open its contents for copying.
- New: Open a copyable layout report with /gl debug.
- New: Configure how much chat history is retained for copying.
- New: Add Glassy-owned timestamps with format, optional color override, and per-tab controls.
- New: Choose the color, opacity, and left/right fade distances of Glassy backgrounds.
- New: Render Combat Log entries like Glassy messages and style, reposition, or hide its filter bar.
- New: Hide the Combat Log without losing its retained history.
- New: Reorder any chat tab, including General and Combat Log, by dragging it.
- New: Review optional Prat integration and module conflicts on the Compatibility settings page.
- New: Choose separate easing styles for chat-message fades and slide-in movement.
- New: Optionally brighten the active chat tab while preserving the original appearance by default.
- New: Optionally reuse the closed edit box's space for messages, with separate easing controls for message movement and background fades.
- New: Use Ctrl+E, Ctrl+U, Ctrl+K, and Ctrl+Y for terminal-style chat editing.
- New: Use Alt keybindings while typing without losing the current message.
- New: Browse all available chat shortcuts on the Shortcuts settings page.
- New: Show supported emoji shortcodes with ElvUI's emoji textures while ElvUI Chat remains disabled.
- New: Open Channels from a chat tab's right-click menu.

Improvements

- Improved compatibility with WoW Classic Era, temporary chat tabs, the Combat Log, and optional Prat message formatting.
- Improved coexistence with ElvUI when its Chat module is disabled.
- Improved startup, idle, and long-session performance by bounding rendered messages and processing chat only when needed.
- Improved live setting and profile updates for fonts, spacing, icons, dimensions, overlays, and scrollback.
- Improved settings organization with a dedicated Timestamps page and animation preview.
- Improved tab hover, overflow, unread-message, and interrupted-fade feedback.
- Improved dynamic edit-box transitions so the background fades smoothly while the chat label and input caret close immediately.

Bug fixes

- Fixed missing, misaligned, or incorrectly sized chat tabs and Combat Log controls.
- Fixed closed chat-window slots appearing in the timestamp settings.
- Fixed chat and tabs disappearing after an edit-box hook error.
- Fixed invalid font paths, pooled-frame errors, duplicate temporary frames, and stale hooks.
- Fixed profile actions from other addons appearing in Glassy settings.
- Fixed chat editing during Blizzard's messaging lockdown causing protected-command errors.
    ]]}
  },
  {
    name = "1.8.0 (2020-10-14)",
    items = {[[
What's new

- New: Updated for Shadowlands!
    ]]}
  },
  {
    name = "1.7.0 (2020-09-29)",
    items = {[[
What's new

- New: Glassy now indents lines that wrap past the first line. Super helpful for visually distinguishing lines that belong to a single message. Note: If you don't like this new behavior, you can turn it off in the settings.
    ]]}
  },
  {
    name = "1.6.0 (2020-09-23)",
    items = {[[
What's new

- New: Glassy now supports Prat's History module! As long as it's enabled, Glassy now restores your chat message history.

Bug fixes

- Fixed: There was an issue where messages that were received before Glassy initialized were lost (e.g. Guild Message of the Day). This has now been fixed.
    ]]}
  },
  {
    name = "1.5.0 (2020-09-14)",
    items = {[[
What's new

- New: You can now stick the edit box to the top of the chat window! Very useful if you like chat flush to a bottom corner.
- New: You no longer need a 16,000 DPI gaming mouse to move Glassy to the perfect spot. Now you can use sliders for window positioning.
- New: More control over the font, including leading, line padding, and outline.
- New: New options for controlling animations. Now you can adjust how fast messages fade in, fade out, and slide in. You can even set these to zero to disable animations completely if that's not your cup of tea.
- New: This thing! Glassy is getting constant updates with new features and fixes added almost weekly. We thought it would be a good idea to write up changes and new stuff between each release. Watch this space!

Bug fixes

- Fixed: Sometimes messages do not appear. This now happens... even less often!
    ]]}
  },
  {
    name = "1.4.2 (2020-09-09)",
    items = {[[
Bug fixes

- Fixed: Icons in chat messages used to stutter as new messages come in. They now slide smoothly up along with the text. So smooth.
- Fixed: Sometimes messages do not appear. This now happens... less often!
- Fixed: Scrolling used to break just after resizing the chat window. This should no longer happen.
    ]]}
  },
  {
    name = "1.4.1 (2020-09-08)",
    items = {[[
Bug fixes

- Fixed: There was an issue with how Glassy saved the window position that was causing AceDB to throw a fit. This issue has been resolved.
    ]]}
  },
  {
    name = "1.4.0 (2020-09-07)",
    items = {[[
What's new

- New: World of Waracraft Classic is now officially supported!
    ]]}
  },
  {
    name = "1.3.0 (2020-09-06)",
    items = {[[
What's new

- New: Glassy now supports Prat 3.0 URL links! This will now allow you click URL links in chat as long as you have Prat's UrlCopy module enabled.
- New: Much better scrolling experience. The chat no longer snaps to the bottom when a new message arrives while you're scrolling through history. In addition, we've added a little arrow you can click to go back to your most recent messages. It even tells you when you have unread messages!

Bug fixes

- Fixed: Players have been experiencing issues with the edit box being visible even if it's not focused. This is caused by the chat style setting being set to "IM style". From now on, Glassy will automatically set the chat style to "Classic" so that you don't have to do it yourself.
    ]]}
  },
  {
    name = "1.2.1 (2020-09-01)",
    items = {[[
Bug fixes

- Fixed: There was a conflict with the ElvUI mover and Glassy. This has been fixed.
    ]]}
  },
  {
    name = "1.2.0 (2020-08-31)",
    items = {[[
What's new

- New: Glassy now supports the "New tab" whisper mode! Other "temporary" chat windows are also now supported, including the Pet Battle tab.
- New: Major architecture changes for Glassy. You won't see any changes while using the addon, but rest well in knowing that we've given the engine a massive tune up.
    ]]}
  },
  {
    name = "1.1.1 (2020-08-26)",
    items = {[[
Bug fixes:

- Fixed: You will find that animations are now 99% less jittery!
- Fixed: Some players were experiencing issues when using Glassy with other addons. These issues have been addressed and should no longer happen.
    ]]}
  },
  {
    name = "1.1.0 (2020-08-24)",
    items = {[[
What's new

- New: Players have been having a hard time figuring out how to move Glassy around. So we've added a new "Unlock Window" option when right-clicking the "General" tab. This is how the default chat UI unlocked its windows so hopefully this will be more obvious.
- New: Glassy now supports Prat Timestamps! If you're using Prat, you should find that timestamps are now displayed.
    ]]}
  },
  {
    name = "1.0.1 (2020-08-22)",
    items = {[[
Bug fixes

- Fixed: The Battle.net toast used to be out of place. We've given it a nudge and it should now be where it belongs.
- Fixed: Previously, some text icons become "squished". We've removed the Squisher Module so you should now see icons in their full, unsquished glory.
    ]]}
  },
  {
    name = "1.0.0 (2020-08-22)",
    items = {[[
What's new

- New: Glassy exists!
    ]]}
  }
}
-- luacheck: pop

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
