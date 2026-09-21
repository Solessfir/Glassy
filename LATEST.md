# 1.9.4 (unreleased)

## What's new

- Glassy settings are now available under Options → AddOns → Glassy, with the same controls as `/gl`.
- Escape now closes the What's new window.
- Added Shadow, Shadow Outline, and Shadow Thick choices to each section's font-outline dropdown.
- Font outlines default to None in every section, without legacy outline inheritance or automatic message shadows.
- Removed hover brightness controls. Tabs, Combat Log filters, unread messages, and overflow controls use the shared hover label color directly.
- Moved font selection and outlines from General to separate Tabs, Messages, and Edit box controls. Combat Log filters share the Tabs settings; existing choices are preserved.
- Added a shared tab and Combat Log filter font-size control. Messages, the edit box, and tabs now default to size 13.
- Added separate edit-box fade-in and fade-out durations, independent of message fades.
- Message-area resizing when opening or closing the edit box now follows the edit-box durations instead of message fade timing.
- Default tab text is #AB9A1B and active/hover text is #CAB620, both at 100% opacity. All separators default to #AB9A1B at 0% opacity.
- Added shared color and opacity controls under General → Appearance: Label color and Hover label color. They apply to tabs, Combat Log filters, unread messages, and the jump-to-latest control.
- Removed the active-tab brightness slider; selected tabs and Combat Log filters now use the hover label color directly.
- While scrolled back, the bottom control now shows Jump to latest and changes to Unread messages when new chat arrives. The tooltip has been removed.
- Replaced the return-to-latest icon with a white texture that follows the interface colors, including hover, and aligned it with the label.
- Moved Commands into its own section below the About buttons instead of listing them under Shortcuts.
