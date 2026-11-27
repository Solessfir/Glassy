# Glassy

An immersive, minimal chat UI for all World of Warcraft versions.<br>
It continues the original [Glass](https://www.curseforge.com/wow/addons/glass) design with Classic compatibility fixes, more customization, and new chat tools.

_Classic twist_
![Glassy Preview](https://i.imgur.com/rtOyJeW.gif)

_Same, but different…_
![Glassy Preview Two](https://i.imgur.com/sPsDhPV.gif)

## Install

**Downloads:** [GitHub Releases](https://github.com/Solessfir/Glassy/releases) · [CurseForge](https://www.curseforge.com/wow/addons/glassy) · [Wago Addons](https://addons.wago.io/addons/glassy).

1. Download the packaged addon ZIP from [GitHub Releases](https://github.com/Solessfir/Glassy/releases), not GitHub's **Source code** archives.
2. Extract the `Glassy` folder into your client's `Interface/AddOns` folder, with `Glassy.toc` directly inside `Interface/AddOns/Glassy`. Use `_classic_era_` for Era/Hardcore, `_anniversary_` for Burning Crusade Anniversary, `_classic_` for Mists of Pandaria Classic, `_forever_` for WoW Forever, or `_retail_` for Retail.
3. Restart WoW or reload after replacing an existing installation, then enter `/gl`.
4. Open **About → Compatibility** if you use another chat addon.

### Upgrading from Glass

Close WoW before migrating. Install Glassy, then copy `WTF/Account/<account>/SavedVariables/Glass.lua` to `Glassy.lua` in the same folder and change the top-level `GlassDB =` assignment to `GlassyDB =`. Only do this if you have no existing Glassy settings to preserve. Keep the original file as a backup and remove or disable the old Glass addon so both do not load together.

## Features

- Chat fades until you hover or type. Optional top-edge fade.
- Adjustable fonts, colors, spacing, opacity, and animations.
- Seven tab styles, flexible alignment, class accents, and unread counts.
- Optional Guild and Party tab presets.
- Detach tabs or group them into a second window.
- Optional Social, Channels, Voice, and chat menu buttons with Blizzard or Glassy styling.
- Restore, search, copy, and filter chat. Optional clickable timestamps.
- Customize channel labels, player names, levels, and link icons.
- Copy URLs, track linked recipes, and Alt-click names to invite.
- Separate whisper windows with an unread inbox.
- Edit-box styles, an emote picker, slash aliases, and command history.
- Move chat and alerts in Blizzard Edit Mode on supported clients.
- Integrates with EllesmereUI and Details! Chat Tab Embed.
- Supports current WoW clients and ten interface languages.

## Commands

`/gl` opens the Glassy section in EllesmereUI when available. Use `/gl standalone` for Glassy's separate window, or **Options → AddOns → Glassy** for the embedded game settings. `/glassy` and `/glass` work as aliases for all commands.

| Command | Action |
| --- | --- |
| `/gl` | Open settings. |
| `/gl standalone` | Open Glassy's separate settings window. |
| `/gl lock` | Toggle the chat-frame mover. |
| `/gl debug` | Open a copyable layout report for troubleshooting. |
| `/gl news` | Open the version history. |
| `/gl demo` | Toggle demo mode: sample chat to preview styles and animations. |
| `/alias rld /reload` | Create a shortcut so `/rld` reloads the UI. |
| `/unalias rld` | Remove the `/rld` shortcut. |
| `/listaliases` | List saved shortcuts. |
| `/tt` or `/tt message` | Open a whisper draft for your player target when enabled under **Messages → Chat utilities**. |

Saved aliases are listed under **Edit box → Behavior**. Select an alias to edit or remove it, or choose **New alias** to add one. For example, enter `/rld = /reload` in **Alias definition** and accept it. Aliases can include arguments and respect WoW's command restrictions. Use `/gl alias`, `/gl unalias`, and `/gl listaliases` if another addon owns the standalone commands.

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
| Tab | Complete a unique player name from recent chat, where the client supports addon completion. |
| Alt + key | Use your WoW keybinding. Release Alt to resume typing. |
| Shift-click a quest or item | Insert its link while chat is active. |

Ctrl+U, Ctrl+K, and Ctrl+Y are unavailable during Blizzard's chat messaging lockdown.

Enable **Edit box → Typing → Save slash-command history** to keep up to 32 recent commands per character across reloads. Recall them with Alt+Up or Alt+Down. Turning the setting off clears the saved list. Sent chat and protected commands stay in the game's own session history.

Keys for switching the channel (Say, Yell, Party, Raid, Instance, Guild, Officer, Reply and channels 1-5) can be set under **Options → Keybindings → Glassy**. They are unbound by default. While typing, they keep the text you have written; otherwise they open chat in that channel. Pressing the key of the channel you are already in closes an empty chat box, like Escape.

### Chat tabs and history

| Action | Result |
| --- | --- |
| Hover over chat | Reveal faded chat and tabs. |
| Click a tab | Switch chat windows. |
| Drag a tab | Reorder it, including General and Combat Log. |
| Unlock a non-primary tab | Detach it into its own Glassy chat window; Blizzard retains that window's position and dimensions. |
| Right-click a detached tab and choose **Move to secondary window** | Put the tab beside the tabs in another detached window. |
| Right-click a tab | Open its menu, including Channels, Search messages, Settings, and the frame mover. |
| Shift-click a tab | Open that tab's contents for copying; press Ctrl+C to copy to the clipboard. |
| Mouse wheel over chat | Scroll through retained messages one message at a time. |
| Shift + mouse wheel over chat | Scroll within a long message. |
| Click the return-to-bottom arrow | Return to the newest messages. |
| Click a timestamp | Copy the message when **Clickable timestamps** is enabled. Shift-click to insert it in the chat edit box. |
| Hover over an item link | Show its tooltip. |
| Alt-click a player name | Invite that character to your group. |
| Right-click a linked recipe | Track or untrack it (Retail and WoW Forever). |
| Right-click a channel name, then **Move to New Window** | Move that channel into its own tab. |
| Right-click a player name, then **Copy Character Name** | Open the name in Glassy's copy window; press Ctrl+C to copy it. |
| Right-click a player name, then **Move to Whisper Window** | Move that conversation, with its messages, into its own whisper tab. |

See [latest release notes](LATEST.md) and the [changelog](CHANGELOG.md) for details. In-game notes are available through **What's new** in settings.

## Customization

Open Blizzard Edit Mode to move chat, Battle.net notifications, chat alerts, and voice indicators where the client provides them. Click **Glassy settings** on the chat mover to adjust size, fonts, and fading within Edit Mode. Positions are saved to your Glassy profile. Turn off the integration under **General → Frame** or change notification skins under **General → Notifications**. The manual chat mover is also available with `/gl lock`.

Open **Tabs → Presets** to create a dedicated Guild or Party tab. General keeps its current filters.

Enable **Tabs → Chat buttons → Show chat buttons** to place the game's Social, Channels, Voice, and chat menu buttons beside the tabs where available. **Button style** defaults to **Glassy**; choose **Blizzard** for the game's artwork. The button color and hover color default to the corresponding tab label colors. Set their position and offsets in the same section.

Under **Profiles → New profile**, use **Start from** to copy appearance and behavior settings into a separate profile. Chat history and native tab filters stay with the character. Tab order, the selected tab, and per-tab timestamps start at their defaults. Choose **Use existing profile** to share future changes across characters.

To group tabs, detach them first, then move one into the other window from its tab menu. Use **Separate tab** to return a tab to its own window or **Ungroup secondary window** on the original tab to separate the group. Groups of regular chat tabs are saved per character. Temporary tabs can join a group for the current session.

Enable **Tabs → Whispers → Dedicated whisper windows** in Glassy or EllesmereUI. Click the whisper icon in the chat tab bar to open the inbox, or use the game's **Whisper** action to start typing in a dedicated window when available. Right-click a conversation for player actions and **Close conversation**. Optional bubbles and a notification sound are in the same settings section. **Open on incoming whisper** shows the window without taking keyboard focus.

Use **Inbox button color** and **Inbox button hover color** in the same section to change the icon and unread count color and opacity, including the unread highlight. Unread conversations stay in the inbox until you read or close them. **Save chat history** keeps character conversations and their unread counts across reloads. Battle.net conversations are session-only, and restricted or censored whispers stay in regular chat.

Use `/gl` to configure:

- Frame dimensions and position, shared or per-character profiles, and portable profile import and export.
- Fonts, sizes, outlines, message spacing, indentation, and inline-icon alignment.
- Header, message, and input backgrounds with color and opacity controls, plus optional gradient separators.
- Message hold time, optional reveal while typing, fade durations, slide movement, and easing.
- Edit-box style and position. Find **Emote picker** and player-name completion under **Edit box → Typing**.
- Tab appearance and position, class-color accents, optional native chat buttons, unread counts, kept whisper tabs, and Combat Log layout.
- Timestamp format, color, clicks, and per-window controls under **Messages → Timestamps**.
- Name brackets, levels, raid subgroup numbers, and separate name and guild highlights under **Messages → Chat formatting**.
- **Date separators** under **Messages → History**. They appear after Glassy restores history on login or reload.
- **Messages → Chat alerts and sounds** offers alerts for your name or custom words, an on-screen popup, and sounds by chat type or numbered channel. These apply to live messages.
- **Messages → Chat rules** supports alt-to-main labels, text substitutions, and ordered chat filters. Enter one rule per line, such as `Alt = Main`, `old => new`, or `hide|plain|blocked phrase`. Rules also support a limited set of Lua patterns.
- Use **Messages → Chat utilities** to set sticky chat types, remember public channel colors by name, enable `/tt`, or start and stop Blizzard's chat and combat logs. Disk logging controls change the game's logging state directly.

Glassy keeps its visible renderer bounded to 128 messages; the separate **Scrollback lines** setting controls retained history available for copying.

## Compatibility setup

### Details!

Turn on **Details! Chat Tab Embed** under **Tabs → Integrations**, then enable **Chat Tab Embed** in Details! and choose a dedicated tab in the main chat dock. Glassy shows the meters when that tab is selected. This integration is off by default.

### Prat 3.0

Prat 3.0 is compatible and optional. **About → Compatibility** shows active overlaps and chat history migration steps. If Prat History saves slash commands, it takes precedence over Glassy's command history.

### ElvUI

Disable **ElvUI → Chat → Enable**, then reload, so Glassy can manage chat. The rest of ElvUI works alongside Glassy.

### EllesmereUI

`/gl` opens Glassy in EllesmereUI's own options panel with native controls and search, and brings the selected Glassy entry into view in the sidebar. Both settings panels edit the same profile. EllesmereUI's **Reset** button restores the defaults of the Glassy section you are viewing.

EllesmereUI can skin Glassy's separate windows and supply the default font and accent colors. Colors and fonts you set in Glassy still take priority. Change the window skin under **EllesmereUI → Blizzard Skins+ → Window Skins → Third-Party Addons**. [EllesmereUI](https://www.curseforge.com/projects/1477613)

Disable the **EllesmereUI Chat** addon: it restyles the same chat frames as Glassy. The **Compatibility** section under **About** warns while both are enabled.

### Leatrix Plus and other chat addons

Disable features that move, resize, fade, or replace the same chat frames. In Leatrix Plus, features such as **Recent chat window** and **Use easy resizing** can conflict with Glassy.

## Reporting problems

Include your WoW version, the error message, and steps to reproduce. For layout issues, include a screenshot and the output of `/gl debug`. Check the **Compatibility** section under **About** for conflicting modules first. Review any copied report before sharing it publicly.

## Development and releases

See [Development and releases](DEVELOPMENT.md).

## Credits and license

Original Glass by mixxorz (Mitchel Cabuloy). Fork maintained by Solessfir. Recipe tracking, chat search, tab styles, and several fixes are adapted from Glass Forever by Nelson Abrantes (Rethz).

[MIT License](LICENSE). Original copyright notices retained. Prat and ElvUI are separate projects and are not bundled with this fork.

Color emotes are [Twemoji](https://github.com/jdecked/twemoji) graphics, copyright Twitter, Inc. and other contributors, licensed under [CC-BY 4.0](https://creativecommons.org/licenses/by/4.0/) and resized for WoW.
