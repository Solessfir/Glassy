# Changelog

## 1.9.3 (2026-09-20)

### What's new

- New profiles now select the active UI font by its actual name after login, including font replacements from other addons, while preserving saved custom font choices.
- Added live snapping to screen edges and corners while dragging the unlocked chat frame.
- Made the message area always reuse the closed input box's space, removing the old static-area mode.
- Expanded **Always visible** to keep messages, tabs, headers, and the active input box visible together.
- Added one shared hover-highlight control for tabs, Combat Log filters, overflow controls, and the unread-message row.
- Reorganized settings into **General**, **Tabs**, **Messages**, and **Edit Box**. Combat Log controls now live under Tabs, timestamps under Messages, and Shortcuts and Compatibility under About.
- Refined the default layout to a 600 × 250 frame with zero frame offsets, a 2 px tab offset, and a -2 px input-box offset.
- Added a release-preparation command that generates README, changelog, and in-game notes from one source, with CI checks to catch stale release metadata and notes.

### Improvements and fixes

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

## 1.9.2 (2026-09-19)

* Add built-in localization for English, German, Spanish, French, Italian, Korean, Brazilian Portuguese, Russian, Simplified Chinese, and Traditional Chinese across settings, tooltips, dialogs, status text, and copy-window messages.
* Enlarge the version-history window and use the game UI font with a 95%-opaque settings-theme background. Add an About page for the version and action buttons, move command help to Shortcuts, and add `/gl news`.
* Read the runtime version from the addon's TOC metadata, keeping `Glassy.toc` as the single version source.
* Add a **Show while typing** option that reveals faded chat messages while the chat input is open and resumes normal fading when it closes.
* Add a **Tab hover highlight** strength setting, default it to 65%, and reserve a dedicated row for the unread-message control so it no longer overlaps chat text.
* Default chat-tab interaction tooltips to off.
* Add independently colored, pixel-snapped gradient separators between tabs and messages, the edit box and messages, and the unread-message control and messages. Setting a separator's opacity to 0 hides it. The edit-box separator follows its fade animation. Add a vertical message offset and an independent unread-message background color.
* Add configurable vertical padding above and below edit-box text, defaulting to half a line height per side.
* Make screen-anchor offsets use the visible chat and attached edit-box bounds instead of a fixed 35-pixel edit-box estimate.
* Preserve the edit box's bottom text padding when its space is reused for chat messages, keeping both states equally inset from the screen edge.
* Change the default left text padding from 15 pixels to 4 pixels.
* Keep the chat tabs hidden after login or UI reload while still showing chat messages.
* Add Classic Forever interface `16001` support.
* Avoid protected keyboard-propagation calls during combat when handling Alt shortcuts in the chat input.
* Add an optional message blacklist with case-insensitive plain-text matching, whitespace normalization, and filtering for live, copied, and restored Prat messages.
* Spread chat-history restoration across game frames to avoid script timeouts during login and UI reload.
* Add validated, locale-independent profile export and import, with options to create a new profile or replace the current profile after confirmation.
* Apply Glassy styling and behavior to detached chat windows while preserving each window's Blizzard-managed position and dimensions.

## 1.9.1 (2026-09-14)

* Replace legacy Travis CI with GitHub Actions package checks and tag-only publishing to CurseForge and GitHub Releases. Keep `Tests/` out of release ZIPs and include the missing CallbackHandler library.
* Rename this fork to Glassy, with `/gl` as the primary command and `/glassy` and `/glass` aliases. Update addon paths, packaging, branding, and repository links.
* Publish tagged releases to Wago Addons alongside CurseForge and GitHub Releases.
* Remove remaining Retail replacements of native chat visibility, tab styling, and Combat Log filter-bar methods. Use guarded secure post-hooks for presentation, and leave native chat frames transparent instead of intercepting their visibility.
* Preserve Blizzard's secure tab clicks and Retail Combat Log visibility callbacks to avoid protected filter errors. Retail keeps Blizzard's initial tab selection and reorders tabs without programmatically selecting them.
* Use the frame's `IsMouseOver()` API on Retail, fixing repeated hover errors and chat tabs failing to reveal.
* Add Retail `120100` metadata and runtime detection, support Retail's field-based tab artwork and focus borders, and tolerate optional chat buttons that have not loaded.
* Preserve protected Retail message text without parsing it, redact it in copied chat, and reset pooled FontStrings using Blizzard's approach.
* Add Mists of Pandaria Classic interface `50504` support and the shared edit-box fixes, with in-game testing completed.
* Reparent the chat input to Glassy so its text and background remain visible when the native chat frame is hidden.
* Keep Glassy's edit-box hooks on a separate owner so Prat TellTarget can safely use the native `HookScript` method, regardless of addon load order.
* Declare Burning Crusade Anniversary interface `20506` alongside Era `11509`, so Anniversary can load Glassy without enabling out-of-date addons.
* Validate Anniversary chat and confirm Retail Combat Log tab switching and filter buttons work in game.

## 1.9.0 (2026-08-26)

* Add terminal-style chat editing with Ctrl+E, Ctrl+U, Ctrl+K, and Ctrl+Y
* Allow Alt keybindings while typing and document available shortcuts in settings
* Add optional emoji shortcode rendering using ElvUI textures
* Add Channels to the chat-tab context menu
* Report detected Prat and ElvUI versions in Compatibility
* Guard custom editing during Blizzard's chat messaging lockdown
* Document commands, shortcuts, and feature requirements for Prat and ElvUI in the fork README
* Add a copy window for a chat tab, available by Shift-clicking its tab
* Add a copyable layout report available with `/gl debug`
* Add configurable per-tab copyable history (500 messages by default)
* Bound history restoration before allocation and reduce startup memory, idle CPU use, and high-volume chat overhead
* Fix pooled temporary-chat hooks and duplicate temporary-frame allocation
* Add safe font fallback, profile layout refreshes, and frame-height validation
* Cap copied text and reduce updater work after frame-rate hitches
* Fix the scroll overlay mask path and live Combat Log scrollback updates
* Add Glassy-owned timestamps with format, optional color override, and per-tab controls
* Show only active chat windows in the per-tab timestamp controls
* Add an optional Prat compatibility report with module-conflict guidance
* Refresh the scroll overlay and text-icon offsets when settings change
* Fix version ordering and MoverDialog FontString creation
* Preserve the edit box OnShow handler without colliding with AceHook
* Align the native Combat Log controls with Glassy message padding
* Add configurable colors and opacity for chat, header, and edit-box backgrounds
* Add an optional dynamic message area that reuses the closed edit box's space with separate movement and background-fade easing
* Add separate easing-style controls for chat-message fades and slide-in movement
* Add optional active-tab highlighting and clearer tab interaction feedback
* Reorganize settings with a dedicated Timestamps page and animation preview
* Synchronize header fading and improve tab overflow and unread-message interactions
* Prevent other addons from injecting actions into Glassy profile settings

## 1.8.0 (2020-10-14)

* Updated for Shadowlands

## 1.7.0 (2020-09-29)

* Add line indention support

## 1.6.0 (2020-09-23)

* Refactor gradient backgrounds (#109)
* Refactor scroll overlay (#109)
* Refactor new message alert (#109)
* Refactor OnUpdate handler (#109)
* Fix GMOTD not displaying (#110)
* Add support for Prat's history module (#100)

## 1.5.0 (2020-09-14)

* Add more customization options (#107)
* Add in-game changelog (#108)

## 1.4.2 (2020-09-09)

* Fix icons not sliding up (#99)
* Fix messages not being displayed sometimes (#99)
* Fix issues with scrolling after frame resize (#99)

## 1.4.1 (2020-09-08)

* Fix AceDB issues

## 1.4.0 (2020-09-07)

* Add classic support (#95)

## 1.3.0 (2020-09-06)

* Add support for third-party chat links (#90)
* Improve scrolling behavior (#92)
* Force chatStyle to classic (#94)

## 1.2.1 (2020-09-01)

* Fix conflict with ElvUI Mover

## 1.2.0 (2020-08-31)

* Major rearchitecture (#79)
* Add support for new tab whisper mode (#80)

## 1.1.1 (2020-08-26)

* Fix text processing pipeline (#70)
* Fix jittery animations (#71)
* Fix dependency issues (#72)

## 1.1.0 (2020-08-24)

* Add "Unlock Window" option to context menu - SammyJames
* Add support for Prat timestamps

## 1.0.1 (2020-08-22)

* Fix Battle.net toast position
* Fix some icon textures being squished

## 1.0.0 (2020-08-22)

* Initial release
