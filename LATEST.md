# 1.9.14 (unreleased)

## What's new

- Restore chat after logging in or reloading. Set the line limit under **Messages → History**.
- New chat survives a reload during history restoration. A new message with the same text as a saved line does not erase the saved occurrence when their timestamps differ.
- **Messages** includes channel labels, player formatting, icons, links, and timestamps. Find player-name completion under **Edit box → Typing**.
- Customize short labels or restore the game's label per channel under **Messages → Channel abbreviations**.
- See saved slash aliases directly under **Edit box → Behavior**, and select one to edit or remove it. Try `/rld = /reload` in the alias editor or `/alias rld /reload` in chat.
- Turn on **Save slash-command history** under **Edit box → Typing** to recall recent commands with Alt+Up or Alt+Down after reloading.
- Resetting **Edit box** in EllesmereUI clears saved slash commands for the current character.
- Party chat shows available player levels for full character names in WoW Forever. Alt-click a player name to invite them.
- **Messages → Chat formatting** adds separate name and guild highlights, name brackets, player levels, and raid subgroup numbers.
- Turn on **Clickable timestamps** to copy a message with a click or insert it into chat with Shift-click.
- **Messages** adds optional name and keyword alerts, mention popups, and channel sounds.
- Map alts to mains, substitute chat text, or use ordered plain-text and Lua-pattern filters under **Messages**.
- **Messages** also adds sticky chat types, channel color memory, `/tt` to whisper your player target, and controls for Blizzard's chat and combat log files.
- Choose from seven tab styles under **Tabs → Appearance**. Set the selected highlight to Slide, Grow, or Off. Classic uses the game's tab artwork.
- Styled tabs now have balanced label padding, with extra room for rounded Pill tabs and space above the underline.
- Place or align the tab bar under **Tabs → Layout**. Use your class color as the selected accent under **Tabs → Appearance**.
- Create Guild or Party tabs from **Tabs → Presets**. General keeps its filters.
- Create an independent profile from an existing setup under **Profiles → New profile → Start from**.
- **Tabs → Chat buttons** can show the game's Social, Channels, Voice, and chat menu buttons alongside the dock. Choose **Glassy** (default) or **Blizzard** under **Button style**.
- **Edit box → Appearance** adds Solid, Minimal, and Framed styles. Enable the emote picker under **Edit box → Typing**. The input stays visible in controller mode and while typing with ForeverImmersion.
- Move chat, notifications, and voice indicators in Blizzard Edit Mode where available. Adjust chat size, fonts, and fades from the Glassy mover.
- Optional Battle.net notification and game alert skins are under **General → Notifications**.
- **Messages** adds **First names only** for multi-word player names and optional **Date separators** in restored history.
- **Fade at the top** under **Messages → Visibility** softens the top edge of live chat. It is off by default and keeps scrollback fully readable.
- Detached chat windows can now hold multiple tabs. Right-click a detached tab and choose **Move to secondary window**. Regular tab groups are saved per character.
- Repeating **Move to New Window** for a channel already moved keeps its existing window.
- Details! can display its damage meters in a docked Glassy tab. Turn it on under **Tabs → Integrations**, then enable Chat Tab Embed in Details! and choose the tab there. This integration is off by default.
- **Tabs → Whispers** adds an optional inbox and separate windows for character and Battle.net conversations. Enable **Open on incoming whisper** to show the window without taking keyboard focus.
- Open the inbox from the whisper icon in the tab bar. It shows the unread count. Start a reply with the game's **Whisper** action, right-click for player actions, or enable optional bubbles and a sound.
- The inbox and replies use EllesmereUI's window styling when enabled. An empty inbox shows how to start a whisper.
- New whispers stay unread while you scroll back in a conversation, and your place is preserved.
- Prat is optional. **About → Compatibility** shows which enabled Prat modules take precedence and how to move your chat history over.
- Glassy's native EllesmereUI settings use the panel's text and input styling. `/gl` opens the settings and reveals the selected Glassy entry in the sidebar. Use `/gl standalone` for the separate settings window.
- Profile selectors show short names, with character assignments in tooltips. **About → Compatibility** shows detected addons and active conflicts.
