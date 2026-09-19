# 1.9.2 (2026-09-19)

## What's new

- Glassy now styles and manages detached chat windows while preserving their Blizzard-managed position and size.
- Added profile export and import, including options to create a new profile or replace the current one.
- Added an optional message blacklist that hides messages containing configured phrases, including restored Prat history.
- Added full interface localization for English, German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian, Simplified Chinese, and Traditional Chinese.
- Added an option to reveal faded messages while typing.
- Added configurable tab hover highlighting, message and edit-box separators, message spacing, edit-box padding, and unread-message appearance.
- Reorganized settings with dedicated Shortcuts and About pages. Use `/gl news` to reopen these notes.

## Fixes

- Chat tabs stay hidden after login or `/reload` until the chat is hovered.
- Large Prat histories are restored over multiple frames to prevent script timeouts.
- Protected keyboard-input calls are avoided during combat.
- Improved frame bounds, edit-box spacing, unread-message placement, and Combat Log tab behavior.
- Added Classic Forever interface `16001` support.
