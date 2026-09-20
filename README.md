# Glassy

An immersive, minimal chat UI for all World of Warcraft versions.<br>
It continues the original [Glass](https://www.curseforge.com/wow/addons/glass) design with Classic compatibility fixes, more customization, and new chat tools.

![Glassy Preview](https://i.imgur.com/FjysGWP.gif)

## Required addons for the full experience

- **[Prat 3.0](https://www.curseforge.com/wow/addons/prat-3-0) is mandatory for player class icons, item-link icons, and restoring chat history after a reload or login.** Enable Prat's **LinkInfoIcons** module for icons and **History** for saved chat. Prat also supplies advanced name/channel formatting, substitutions, URL links, filters, and highlights.

  **Required setup:** Open `/prat` → **Module Control** → set **Editbox** to **Don't load**, then `/reload`. Leaving it enabled breaks Glassy's input layout: the typing box can appear far below chat, look missing, and stretch the mover outline. Keep Prat itself enabled for icons and history.

- **[ElvUI](https://tukui.org/elvui) is mandatory for emojis.** Glassy uses ElvUI's existing emoji textures. Keep ElvUI enabled, but disable its **Chat** module so Glassy can manage chat. Enable **Emoji shortcodes** in Glassy's Messages settings. Without ElvUI, shortcodes such as `:smile:` remain text.

These are feature requirements, not addon-loading requirements: Glassy can run on its own, but it does not generate those icons, save chat history between sessions, or bundle emoji textures. Its own scrolling, retained session history, timestamps, and copy window work without Prat.

## Install

**Downloads:** [GitHub Releases](https://github.com/Solessfir/Glassy/releases) · [CurseForge](https://www.curseforge.com/wow/addons/glassy) · [Wago Addons](https://addons.wago.io/addons/glassy).

1. Download the packaged addon ZIP from [GitHub Releases](https://github.com/Solessfir/Glassy/releases), not GitHub's **Source code** archives.
2. Extract the `Glassy` folder into your client's `Interface/AddOns` folder, with `Glassy.toc` directly inside `Interface/AddOns/Glassy`. Use `_classic_era_` for Era/Hardcore, `_anniversary_` for Burning Crusade Anniversary, `_classic_` for Mists of Pandaria Classic, or `_retail_` for Retail.
3. Install Prat and ElvUI if you want the features listed above.
4. Restart WoW or reload after replacing an existing installation, then enter `/gl`.
5. Open **About** and check its **Compatibility** section for detected addons and conflicting Prat modules.

### Upgrading from Glass

Close WoW before migrating. Install Glassy, then copy `WTF/Account/<account>/SavedVariables/Glass.lua` to `Glassy.lua` in the same folder and change the top-level `GlassDB =` assignment to `GlassyDB =`. Only do this if you have no existing Glassy settings to preserve. Keep the original file as a backup and remove or disable the old Glass addon so both do not load together.

## Features

- Keep chat out of the way until you need it. Messages fade smoothly and return when you hover or start typing.
- Make it fit your UI with separate fonts and outlines for tabs, messages, and the edit box, plus colors, backgrounds, spacing, opacity, and animations.
- Background edge fades use a percentage of chat width, so they stay proportional when resized.
- Keep tabs and the Combat Log organized with reordering, highlighting, and customizable text colors and font size.
- Find and share conversations with retained history, timestamps, phrase filtering, and per-tab copying.
- Type without giving up familiar shortcuts or your WoW keybindings.
- Adjust edit-box fade-in and fade-out timing separately from message fades.
- Use the same addon across current WoW clients, with ten interface languages included.

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

See [Development and releases](DEVELOPMENT.md).

## Credits and license

Original Glass by mixxorz (Mitchel Cabuloy). Fork maintained by Solessfir.

[MIT License](LICENSE). Original copyright notice retained. Prat and ElvUI are separate projects and are not bundled with this fork.
