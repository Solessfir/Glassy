# 1.9.4 (unreleased)

## What's new

- Added Shadow, Shadow Outline, and Shadow Thick choices to each section's font-outline dropdown.
- Font outlines default to None in every section, without legacy outline inheritance or automatic message shadows.
- Removed hover brightness controls. Tabs, Combat Log filters, unread messages, and overflow controls use the shared active/hover text color directly.
- Moved font selection and outlines from General to separate Tabs, Messages, and Edit box controls. Combat Log filters share the Tabs settings; existing choices are preserved.
- Added a shared tab and Combat Log filter font-size control. Messages, the edit box, and tabs now default to size 13.
- Added separate edit-box fade-in and fade-out durations, independent of message fades.
- Message-area resizing when opening or closing the edit box now follows the edit-box durations instead of message fade timing.
- Default tab text is yellow at 60% opacity and selected text at 100%. Tab and edit-box separators default to yellow at 0% opacity.
- Added shared text color and opacity controls for chat tabs and Combat Log filters under Tabs → Appearance, with a separate selected/hover color.
- Removed the active-tab brightness slider; selected tabs and Combat Log filters now use the selected text color directly.
