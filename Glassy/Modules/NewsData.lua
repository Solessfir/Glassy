local Core = unpack(select(2, ...))

-- Release notes preserve their authored formatting, so suppress Luacheck's line-length warning for this table.
-- luacheck: push ignore 631
Core.NewsEntries = {
  {
    name = "1.9.3 (2026-09-19)",
    items = {[[
Maintenance update

- Consolidated normal, temporary, and detached chat-window state into one lifecycle-managed record per Blizzard chat frame.
- Split settings into profile, appearance, message, and support page modules while keeping migration, registration, commands, and diagnostics in the configuration core.
- Separated message rendering, layout, and Blizzard chat integration into focused SlidingMessageFrame modules.
- Separated chat-dock lifecycle, tab overflow and dragging, and detached-window behavior into focused components.
- Added regression coverage for configuration load order and chat-window registration, detaching, resizing, tab replacement, redocking, cleanup, and reopening.
- Centralized settings limits and choices shared by profile normalization and the settings pages.
- Separated edit-box appearance from Blizzard chat-input hooks.
- Made the message area always reuse the closed edit box's space and removed the static-area setting.
- Separated release-note data from the news window behavior.
- Moved Combat Log into a Tabs section, and Shortcuts and Compatibility into About sections.
- Coalesced profile-change layout updates to prevent script timeouts when resetting or switching profiles.
- Made the tab vertical offset reduce the message area instead of moving its bottom edge off-screen.
- Set the default tab vertical offset to 2 px and the edit-box vertical offset to -2 px.
- Extended the unread-message background through the gap created by a negative edit-box offset.
- Kept the unread-message row visible while the edit box is open.
- Made the shadow above the unread-message row optional and disabled it by default.
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
