# Changelog

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
