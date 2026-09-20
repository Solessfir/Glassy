# 1.9.3 (2026-09-20)

## What's new

- The chat background fills the empty space beneath visible tabs and fades with them.
- New profiles now select the active UI font by its actual name after login, including font replacements from other addons, while preserving saved custom font choices.
- Added live snapping to screen edges and corners while dragging the unlocked chat frame.
- Made the message area always reuse the closed input box's space, removing the old static-area mode.
- Expanded **Always visible** to keep messages, tabs, headers, and the active input box visible together.
- Added one shared hover-highlight control for tabs, Combat Log filters, overflow controls, and the unread-message row.
- Reorganized settings into **General**, **Tabs**, **Messages**, and **Edit Box**. Combat Log controls now live under Tabs, timestamps under Messages, and Shortcuts and Compatibility under About.
- Refined the default layout to a 600 × 250 frame with zero frame offsets, a 2 px tab offset, and a -2 px input-box offset.
- Added a release-preparation command that generates README, changelog, and in-game notes from one source, with CI checks to catch stale release metadata and notes.

## Improvements and fixes

- Kept the unread-message row visible while typing and removed its forced shadow.
- Made **Show while typing** reveal docked and detached chat tabs together with faded messages.
- Removed gaps, overlaps, and dark seams between tabs, Combat Log filters, messages, the unread-message row, and the input box.
- Made tab vertical offsets reduce the message area instead of pushing messages off-screen.
- Smoothed input-box transitions and return-to-latest scrolling while preserving the latest-message position.
- Prevented profile resets and switches from exhausting the script budget during large layout refreshes.
- Improved normal, temporary, and detached chat-window setup, cleanup, redocking, resizing, and reopening across supported clients.
- Split large UI responsibilities into focused components and expanded regression coverage for chat-window and configuration behavior.
- Centralized shared settings limits, separated edit-box appearance from native input hooks, and separated release-note data from the news window.
- Centered the unread-message arrow, hid its separator by default, and extended its background through negative input-box offsets.
