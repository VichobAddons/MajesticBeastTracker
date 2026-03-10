# MajesticBeastTracker - WoW Addon

Tracks daily Majestic Lure beast skinning cooldowns across all characters.

## Architecture

- `Core.lua` — Data, events, profession/talent detection, slash commands
- `UI.lua` — Visual tracker frame, dropdown menus, settings panel
- `Templates.xml` — Settings panel XML templates (text rows, expandable sections)
- `MajesticBeastTracker.toc` — Addon metadata
- SavedVariables: `MajesticBeastTrackerDB` (account-wide)

## Key Technical Constraints

### Midnight 12.0 Restrictions
- **NO `COMBAT_LOG_EVENT_UNFILTERED`** — Removed for addons in 12.0. Causes `ADDON_ACTION_FORBIDDEN` taint error if registered.
- Kill/skinning detection uses `LOOT_OPENED` + target NPC ID check instead.
- Secret values may affect API returns in instanced content — use `issecretvalue()` checks.

### Taint Prevention
- No `MenuUtil.CreateContextMenu` (use custom dropdown frames)
- `BackdropTemplate` and `UIPanelCloseButton` are safe — taint was caused by CLEU, not these
- All inter-file communication via addon namespace `ns.*`, no global writes before RegisterEvent

### Cooldown System
- Cooldowns reset at daily server reset, NOT 24h from kill
- Uses `C_DateAndTime.GetSecondsUntilDailyReset()` for timing
- Kill timestamps stored as `GetServerTime()` values

### Profession Detection
- Skinning base skillLineID: `393`
- Midnight Skinning skillLineID: `2917`
- Talented Tracker detection: `C_ProfSpecs` + `C_Traits` APIs with pcall wrapping
- Tab name search for "Tracker" to find the correct subtree

### Settings Panel
- `CreateSettingsButtonInitializer` requires 5th param `true` to avoid assertion error
- Expandable sections need XML template inheriting `SettingsExpandableSectionTemplate`
- Custom text rows need XML template with `LeftText`/`RightText` FontStrings

## Mechanic Integration

This project uses the Mechanic MCP server for development tooling.

### Reload Loop (MANDATORY)
After ANY code change:
1. Ask user to `/reload` in WoW
2. Wait for user confirmation
3. Use `addon.output` MCP tool (agent_mode=true) to get errors and logs

### Available MCP Tools
- `addon.output` — Get errors, tests, console logs after reload
- `addon.lint` — Luacheck linting (`{"addon": "MajesticBeastTracker"}`)
- `addon.validate` — Validate TOC structure
- `api.search` — Search WoW APIs offline (`{"query": "*Spell*"}`)

### Example Workflow
```
# After user reloads:
addon.output with agent_mode=true

# Lint before committing:
addon.lint with {"addon": "MajesticBeastTracker"}

# Search for API usage:
api.search with {"query": "*ProfSpecs*"}
```
