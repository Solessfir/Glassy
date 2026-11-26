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
- Optional Social, Channels, Voice, and chat menu buttons.
- Restore, search, copy, filter, and timestamp chat.
- Customize channel labels, player names, levels, and link icons.
- Copy URLs, track linked recipes, and Alt-click names to invite.
- Separate whisper windows with an unread inbox.
- Three edit-box styles, an emote picker, and slash aliases.
- Move Glassy in Blizzard Edit Mode on supported clients.
- Integrates with EllesmereUI and Details! Chat Tab Embed.
- Supports current WoW clients and ten interface languages.

## Commands

Open Glassy through `/gl` or **Options → AddOns → Glassy**. Both show the same settings. `/glassy` and `/glass` work as aliases for all commands.

| Command | Action |
| --- | --- |
| `/gl` | Open settings. |
| `/gl lock` | Toggle the chat-frame mover. |
| `/gl debug` | Open a copyable layout report for troubleshooting. |
| `/gl news` | Open the version history. |
| `/gl demo` | Toggle demo mode: sample chat to preview styles and animations. |
| `/alias rld /reload` | Create a shortcut so `/rld` reloads the UI. |
| `/unalias rld` | Remove the `/rld` shortcut. |
| `/listaliases` | List saved shortcuts. |

Create, edit, or remove aliases under **Edit box → Behavior**. For example, enter `/rld = /reload` in **Alias definition** and accept it. Aliases can include arguments and respect WoW's command restrictions. Use `/gl alias`, `/gl unalias`, and `/gl listaliases` if another addon owns the standalone commands.

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
| Hover over an item link | Show its tooltip. |
| Alt-click a player name | Invite that character to your group. |
| Right-click a linked recipe | Track or untrack it (Retail and WoW Forever). |
| Right-click a channel name, then **Move to New Window** | Move that channel into its own tab. |
| Right-click a player name, then **Copy Character Name** | Open the name in Glassy's copy window; press Ctrl+C to copy it. |
| Right-click a player name, then **Move to Whisper Window** | Move that conversation, with its messages, into its own whisper tab. |

See [latest release notes](LATEST.md) and the [changelog](CHANGELOG.md) for details. In-game notes are available through **What's new** in settings.

## Customization

Open Blizzard Edit Mode on supported clients to drag the Glassy chat frame. The position is saved to your Glassy profile, and the mover has a **Glassy settings** shortcut. Turn off the integration under **General → Frame**. The manual mover is also available with `/gl lock`.

Open **Tabs → Presets** to create a dedicated Guild or Party tab. General keeps its current filters.

Under **Profiles → New profile**, use **Start from** to copy appearance and behavior settings into a separate profile. Chat history and native tab filters stay with the character. Tab order, the selected tab, and per-tab timestamps start at their defaults. Choose **Use existing profile** to share future changes across characters.

To group tabs, detach them first, then move one into the other window from its tab menu. Use **Separate tab** to return a tab to its own window or **Ungroup secondary window** on the original tab to separate the group. Groups of regular chat tabs are saved per character. Temporary tabs can join a group for the current session.

Enable **Tabs → Whispers → Dedicated whisper windows** in Glassy or EllesmereUI, then click **Whispers** by the chat pane. Select a name to open its own movable window. Start a conversation with `/w Name-Realm` or the game's **Whisper** action. **Open on incoming whisper** shows the reply window without taking keyboard focus. With **Save chat history** enabled, character conversations survive reloads. Battle.net conversations in the inbox are session-only, and restricted or censored whispers stay in regular chat.

Use `/gl` to configure:

- Frame dimensions and position, shared or per-character profiles, and portable profile import and export.
- Fonts, sizes, outlines, message spacing, indentation, and inline-icon alignment.
- Header, message, and input backgrounds with color and opacity controls, plus optional gradient separators.
- Message hold time, optional reveal while typing, fade durations, slide movement, and easing.
- Edit-box style and position. Find **Emote picker** and player-name completion under **Edit box → Typing**.
- Tab appearance and position, class-color accents, optional native chat buttons, unread counts, kept whisper tabs, and Combat Log layout.
- Timestamp formats, colors, and per-window controls under **Messages → Timestamps**.
- **First names only** under **Messages → Chat formatting** and **Date separators** under **Messages → History**. Date separators appear after Glassy restores history on login or reload.

Glassy keeps its visible renderer bounded to 128 messages; the separate **Scrollback lines** setting controls retained history available for copying.

## Compatibility setup

### Details!

Enable **Chat Tab Embed** in Details! and choose a dedicated tab in the main chat dock. Glassy shows the meters when that tab is selected. Turn off this integration under **Tabs → Integrations**.

### Prat 3.0

Prat 3.0 is compatible and optional. **About → Compatibility** shows active overlaps and chat history migration steps.

### ElvUI

Disable **ElvUI → Chat → Enable**, then reload, so Glassy can manage chat. The rest of ElvUI works alongside Glassy.

### EllesmereUI

Glassy follows [EllesmereUI](https://www.curseforge.com/projects/1477613)'s look when it is installed: Glassy's windows (settings, copy, search, version history, and debug report) use EllesmereUI's window skin, label and separator colors use its accent color, and the default font becomes its UI font. Colors and fonts you set in Glassy still take priority. Turn this off under **EllesmereUI → Blizzard Skins+ → Window Skins → Third-Party Addons**.

All Glassy settings are also available in EllesmereUI's options panel, in a **Glassy** section built with EllesmereUI's own controls and included in its search. Both panels change the same settings. EllesmereUI's **Reset** button restores the defaults of the Glassy section you are viewing.

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
