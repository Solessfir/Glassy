# Glassy

An immersive, minimal chat UI for all World of Warcraft versions.<br>
It continues the original [Glass](https://www.curseforge.com/wow/addons/glass) design with Classic compatibility fixes, more customization, and new chat tools.

![Glassy Preview](https://i.imgur.com/iw2bgve.gif)

## Required addons for the full experience

- **[Prat 3.0](https://www.curseforge.com/wow/addons/prat-3-0) is mandatory for player class icons, item-link icons, and restoring chat history after a reload or login.** Enable Prat's **LinkInfoIcons** module for icons and **History** for saved chat. Prat also supplies advanced name/channel formatting, substitutions, URL links, filters, and highlights.

  **Required setup:** Open `/prat` → **Module Control** → set **Editbox** to **Don't load**, then `/reload`. Leaving it enabled breaks Glassy's input layout: the typing box can appear far below chat, look missing, and stretch the mover outline. Keep Prat itself enabled for icons and history.

- **[ElvUI](https://tukui.org/elvui) is mandatory for emojis.** Glassy uses ElvUI's existing emoji textures. Keep ElvUI enabled, but disable its **Chat** module so Glassy can manage chat. Enable **Emoji shortcodes** in Glassy's Messages settings. Without ElvUI, shortcodes such as `:smile:` remain text.

These are feature requirements, not addon-loading requirements: Glassy can run on its own, but it does not generate those icons, save chat history between sessions, or bundle emoji textures. Its own scrolling, retained session history, timestamps, and copy window work without Prat.

Custom fonts require an addon that registers them with LibSharedMedia, such as SharedMedia or your own media pack. Fonts and personal settings shown in previews are not bundled with Glassy.

## Install

**Downloads:** [GitHub Releases](https://github.com/Solessfir/Glassy/releases) · [CurseForge](https://www.curseforge.com/wow/addons/glassy) · [Wago Addons](https://addons.wago.io/addons/glassy).

1. Download the packaged addon ZIP from [GitHub Releases](https://github.com/Solessfir/Glassy/releases), not GitHub's **Source code** archives.
2. Extract the `Glassy` folder into your client's `Interface/AddOns` folder, with `Glassy.toc` directly inside `Interface/AddOns/Glassy`. Use `_classic_era_` for Era/Hardcore, `_anniversary_` for Burning Crusade Anniversary, `_classic_` for Mists of Pandaria Classic, or `_retail_` for Retail.
3. Install Prat and ElvUI if you want the features listed above.
4. Restart WoW or reload after replacing an existing installation, then enter `/gl`.
5. Open **About** and check its **Compatibility** section for detected addons and conflicting Prat modules.

The current TOC accepts Classic Era and Hardcore `11509`, Classic Forever `16001`, Burning Crusade Anniversary `20506`, Mists of Pandaria Classic `50504`, and Retail `120100`. These clients have been tested in game, including Retail Combat Log tab switching and filter buttons. Future clients will need validation when available.

The interface is localized for English, German, Spanish (EU and Latin America), French, Italian, Korean, Brazilian Portuguese, Russian, Simplified Chinese, and Traditional Chinese. WoW selects the language automatically from the game client locale. The archived release-note prose in **What's new** remains in its original English rather than being partially translated.

On Retail, protected message text is passed directly to Blizzard's text renderer without applying Glassy timestamps or emojis. Protected contents are represented as `<protected>` in copied chat. Blizzard's chat messaging restrictions still apply.

Retail keeps Blizzard's selected tab at login. Dragging a tab changes its position without selecting it; click the tab to select it. This keeps Combat Log filter updates in Blizzard's secure click handler.

When using a Git checkout, note that `libs/` is ignored by Git. Release packaging fetches the libraries listed in `.pkgmeta`; a source ZIP alone is not a complete, ready-to-install addon.

### Upgrading from Glass

Close WoW before migrating. Install Glassy, then copy `WTF/Account/<account>/SavedVariables/Glass.lua` to `Glassy.lua` in the same folder and change the top-level `GlassDB =` assignment to `GlassyDB =`. Only do this if you have no existing Glassy settings to preserve. Keep the original file as a backup and remove or disable the old Glass addon so both do not load together.

## Commands

Use `/gl` to open Glassy. `/glassy` and `/glass` work as aliases for all commands.

| Command | Action |
| --- | --- |
| `/gl` | Open settings. |
| `/gl lock` | Toggle the chat-frame mover. |
| `/gl debug` | Open a copyable layout report for troubleshooting. |
| `/gl news` | Open the version history. |

## Shortcuts

The same reference is available in the **Shortcuts** section under **/gl → About**.

### While typing

| Shortcut | Action |
| --- | --- |
| Left / Right | Move the cursor. |
| Home / End | Jump to the beginning / end. |
| Ctrl+Left / Right | Move by word. |
| Ctrl+E | Jump to the end. |
| Ctrl+W | Delete the previous word. |
| Ctrl+U | Delete from the cursor to the beginning. |
| Ctrl+K | Delete from the cursor to the end. |
| Ctrl+Y | Insert the text last removed by Ctrl+U or Ctrl+K. |
| Ctrl+A / C / X / V | Select all / copy / cut / paste. |
| Alt+Up / Down | Browse older / newer sent messages and commands. |
| Alt + key | Use your WoW keybinding. Release Alt to resume typing. |
| Shift-click a quest or item | Insert its link while chat is active. |

Ctrl+U, Ctrl+K, and Ctrl+Y are unavailable during Blizzard's chat messaging lockdown.

### Chat tabs and history

| Action | Result |
| --- | --- |
| Hover over chat | Reveal faded chat and tabs. |
| Click a tab | Switch chat windows. |
| Drag a tab | Reorder it, including General and Combat Log. |
| Unlock a non-primary tab | Detach it into its own Glassy chat window; Blizzard retains that window's position and dimensions. |
| Right-click a tab | Open its menu, including Channels, Settings, and the frame mover. |
| Shift-click a tab | Open that tab's contents for copying; press Ctrl+C to copy to the clipboard. |
| Mouse wheel over chat | Scroll through retained messages. |
| Click the return-to-bottom arrow | Return to the newest messages. |
| Hover over an item link | Show its tooltip. |

## What's new in 1.9.3

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
- Removed gaps, overlaps, and dark seams between tabs, Combat Log filters, messages, the unread-message row, and the input box.
- Made tab vertical offsets reduce the message area instead of pushing messages off-screen.
- Smoothed input-box transitions and return-to-latest scrolling while preserving the latest-message position.
- Prevented profile resets and switches from exhausting the script budget during large layout refreshes.
- Improved normal, temporary, and detached chat-window setup, cleanup, redocking, resizing, and reopening across supported clients.
- Split large UI responsibilities into focused components and expanded regression coverage for chat-window and configuration behavior.
- Centralized shared settings limits, separated edit-box appearance from native input hooks, and separated release-note data from the news window.
- Centered the unread-message arrow, hid its separator by default, and extended its background through negative input-box offsets.

## What's new in 1.9.2

- Detached chat windows now use Glassy styling and behavior while keeping their Blizzard-managed position and size.
- Profiles can be exported and imported, either into a new profile or over the current one after confirmation.
- An optional message blacklist hides messages containing configured phrases, including restored Prat history.
- The complete interface is localized into ten languages.
- New controls cover reveal while typing, tab hover highlighting, gradient separators, message spacing, edit-box padding, and unread-message appearance.
- Settings now have dedicated Shortcuts and About pages, with `/gl news` available for reopening the in-game release notes.
- Compatibility and performance fixes improve startup visibility, history restoration, frame bounds, Combat Log tabs, and Classic Forever support.

## What's new in this fork

- **Chat copying:** a per-tab copy window and configurable retained history.
- **Message blacklist:** optionally hide messages containing configured plain-text phrases, including restored Prat history.
- **Combat Log:** Glassy-styled entries, adjustable filter-bar position and appearance, and an option to hide the log while retaining recent events.
- **Timestamps:** Glassy-owned formatting, optional custom color, and per-tab controls.
- **Backgrounds:** independent colors and opacity, plus adjustable left/right fades.
- **Animations:** separate fade and slide easing, an animation preview, and improved interrupted transitions.
- **Dynamic input space:** messages use the closed edit box's space, with separate movement and background-fade controls.
- **Tabs:** drag to reorder, optional active-tab highlighting, and improved overflow and unread-message feedback.
- **Chat editing:** terminal-style shortcuts and Alt keybindings while typing.
- **Channels:** open Blizzard's Channels window from a tab's right-click menu.
- **Emojis:** optional shortcode rendering using ElvUI textures, even with ElvUI Chat disabled.
- **Compatibility:** detected Prat/ElvUI versions and guidance for conflicting Prat modules.
- **Reliability:** Classic Era fixes for temporary windows, Combat Log controls, fonts, layout updates, and chat editing; bounded rendering and reduced idle work.

See [latest release notes](LATEST.md) and the [changelog](CHANGELOG.md) for details. In-game notes are available through **What's new** in settings.

## Customization

Use `/gl` to configure:

- Frame dimensions and position, shared or per-character profiles, and portable profile import and export.
- Fonts, sizes, outlines, message spacing, indentation, and inline-icon alignment.
- Header, message, and input backgrounds with color and opacity controls, plus optional gradient separators.
- Message hold time, optional reveal while typing, fade durations, slide movement, and easing.
- Edit-box position and dynamic message-space movement.
- Tab appearance, Combat Log visibility, and filter-bar layout.
- Timestamp formats, colors, and enabled chat windows.
- Scrollback limits and emoji rendering.

Glassy keeps its visible renderer bounded to 128 messages; the separate **Scrollback lines** setting controls retained history available for copying.

## Compatibility setup

### Prat 3.0

Use Prat for message content and persistent history. Let Glassy handle the chat interface.

Recommended Prat modules: **ChannelNames, Highlight, History, Invites, LinkInfoIcons, PlayerNames, and UrlCopy**.

Disable these Prat UI modules to avoid overlapping controls: **Buttons, ChatTabs, CopyChat, Editbox, Fading, Font, Frames, HoverTips, OriginalButtons, Paragraph, Scroll, Search, and SideTabs**.

Disable Prat **Timestamps** and configure timestamps in Glassy instead. Leave Prat **History** enabled if you want restored messages after reload/login. Glassy's **Scrollback lines** setting controls its retained line limit; Prat's **Set Chat Lines** value is not used.

### ElvUI

Disable **ElvUI → Chat → Enable**, then reload. Keep ElvUI itself enabled for emoji textures. Enable emoji rendering in Glassy if wanted.

### Leatrix Plus and other chat addons

Disable features that move, resize, fade, or replace the same chat frames. In Leatrix Plus, features such as **Recent chat window** and **Use easy resizing** can conflict with Glassy.

## Reporting problems

Include your WoW version, the error message, and steps to reproduce. For layout issues, include a screenshot and the output of `/gl debug`. Check the **Compatibility** section under **About** for conflicting modules first. Review any copied report before sharing it publicly.

## Development and releases

`Tests/` contains Lua 5.1 regression tests. With the libraries available in `libs/`, run each test in a separate Lua process. `.luacheckrc` configures optional source linting with `luacheck Glassy`.

GitHub Actions checks branch pushes and pull requests by checking generated release notes, building a package without uploading, validating its contents, compiling the Lua files, and running the regression tests. Tests and development files are excluded from the addon ZIP.

To release:

1. Write the complete release notes in `LATEST.md`. This is the source of truth for the current release; do not edit its generated copies separately.
2. Run `python Tests/prepare-release.py VERSION --date YYYY-MM-DD`, replacing the placeholders with the release version and date. Omitting `--date` uses today's date. The command updates all root TOC versions, the latest README and CHANGELOG sections, and the in-game news while preserving older releases.
3. Run `python Tests/prepare-release.py --check` and `python Tests/test-prepare-release.py`. Commit and push; wait for the checks to pass.
4. Create an annotated tag with `git tag -a vVERSION -m "Glassy VERSION"`, then push it with `git push origin vVERSION`, using the same version as step 2.

For development notes, use `--date unreleased`, then rerun with the release date before tagging. CI rejects stale generated notes and mismatched versions or dates; release tags also reject undated notes. The command does not commit, tag, publish, or copy files into game clients. Desktop previews and store descriptions remain manual editorial tasks.

The tag workflow publishes one multi-client ZIP to [CurseForge](https://www.curseforge.com/wow/addons/glassy) and [Wago Addons](https://addons.wago.io/addons/glassy), then attaches it to GitHub Releases. It uses the repository's `CF_API_KEY` and `WAGO_API_TOKEN` secrets plus GitHub's automatic token. No separate packaging webhook is needed; enabling one could upload duplicate releases. Branch pushes and manual check runs do not publish.

## Credits and license

Original Glass by mixxorz (Mitchel Cabuloy). Fork maintained by Solessfir.

[MIT License](LICENSE). Original copyright notice retained. Prat and ElvUI are separate projects and are not bundled with this fork.
