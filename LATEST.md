# 1.9.1 (2026-09-14)

## What's new

- This fork is now **Glassy**. Use `/gl`, `/gl lock`, and `/gl debug`. `/glassy` and `/glass` remain aliases.
- Releases are available from GitHub, CurseForge, and Wago Addons.
- Support for Classic Era and Hardcore, Burning Crusade Anniversary, Mists of Pandaria Classic, and Retail.
- Updated installation instructions, compatibility notes, and [GitHub links](https://github.com/Solessfir/Glassy).

## Fixes

- Fixed hidden chat input and Prat TellTarget hook conflicts. Disable Prat's **Editbox** module and reload after changing it.
- Fixed missing Retail tabs, tab artwork, and repeated mouse-hover errors.
- Fixed Retail Combat Log protected-action errors when switching tabs and using filter buttons.
- Preserve protected Retail message text without parsing; copied chat replaces protected contents with `<protected>`.

## Upgrading

Close WoW before migrating from Glass. Install Glassy, copy your account's `SavedVariables/Glass.lua` to `Glassy.lua`, and change its top-level `GlassDB =` assignment to `GlassyDB =`. Do not overwrite existing Glassy settings. Keep the old settings file as a backup, and remove or disable the old Glass addon.

On Retail, Blizzard controls the initial tab selection. Dragging reorders a tab without selecting it; click to select.
