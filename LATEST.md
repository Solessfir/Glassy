# 1.9.3 (2026-09-19)

## Maintenance

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
- Removed the shadow above the unread-message row.
