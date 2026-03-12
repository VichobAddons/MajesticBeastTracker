# Majestic Beast Tracker


<img width="700" height="379" alt="wLP5w86jvg" src="https://github.com/user-attachments/assets/7de2232c-dc59-4589-9341-d8e3f7da5eea" />

WoW Midnight (12.0) addon that tracks daily Majestic Lure beast cooldowns across all your skinning characters.

## The Problem

Majestic Lures have a daily cooldown that resets with the daily server reset (same as daily quests). Blizzard provides **no in-game indicator** for these cooldowns:

- `GetItemCooldown()` returns nothing useful
- No tooltip cooldown text
- No spell cooldown via API
- The only in-game hint is the "Sixth Sense" buff which only appears when you're physically at the lure spot AND the cooldown is ready

If you have multiple skinners, it's impossible to remember which character has used which lure today.

## Features

- **Multi-character tracking** - See all your skinners' cooldowns in one grid
- **Quest-based kill detection** - Uses hidden quest flags for 100% reliable kill tracking, syncs across sessions
- **Click to mark/clear** - Manually mark kills as a fallback
- **Reagent icons** - See reagent needs per lure with have/need counts, includes Warbank items
- **Weekly knowledge tracking** - Track Midnight Skinning weekly KP quests (Trainer, Drops, Treatise, DMF) per character
- **Lure shortcuts** - Click to use lure, Shift-click to open recipe/craft, Right-click to set waypoint
- **Craftable count** - Shows how many lures you can craft, including materials in Warbound bank
- **Consumable tracking** - Track Sanguithorn Tea and Haranir Phial of Perception with buff timers and bag count
- **Travel buttons** - Quick-access Hearthstone, Arcantina Key, and Wormhole Generator (Engineering) with cooldowns
- **Gear popup** - Click a character's name to see their equipped skinning tools, accessories, profession stats, and weekly quest status
- **Zone labels** - Color-coded zone names below each lure column
- **Lure column borders** - Colored border boxes for visual separation between lure columns
- **Map waypoints** - Right-click lure icon to set a waypoint to the beast location (Works great with [WaypointUI](https://www.curseforge.com/wow/addons/waypointui))
- **Minimap button** - Left-click toggles window, right-click opens settings
- **Non-skinner auto-hide** - Tracker stays hidden on characters without Skinning
- **Hide in combat** - Optionally hide the tracker during combat
- **Settings panel** - Full Interface > AddOns settings page with chat notifications, combat hide, scale, and more
- **Profession stats** - Per-character Skill, Perception, Finesse, and Deftness in gear popup (base + talents + gear)
- **Profession talent detection** - Automatically reads your Talented Tracker points to show only available lures

## Lure Locations

| Lure        | Zone           | Beast        | Talent Points |
| ----------- | -------------- | ------------ | ------------- |
| Eversong    | Eversong Woods | Gloomclaw    | 1             |
| Zul'Aman    | Zul'Aman       | Silverscale  | 10            |
| Harandar    | Harandar       | Lumenfin     | 20            |
| Voidstorm   | Voidstorm      | Umbrafang    | 30            |
| Grand Beast | Voidstorm      | Netherscythe | 40            |

## Slash Commands

| Command                  | Action                        |
| ------------------------ | ----------------------------- |
| `/mbt`                   | Show tracker                  |
| `/mbt hide`              | Hide tracker                  |
| `/mbt lock`              | Toggle frame lock             |
| `/mbt settings`          | Open settings                 |
| `/mbt talent N`          | Override talent points (0-40) |
| `/mbt remove Name-Realm` | Remove a character            |
| `/mbt nuke`              | Clear current character data  |
| `/mbt nuke all`          | Clear ALL data                |
| `/mbt debug calc`        | Show stats breakdown          |

Also available as `/beast` and `/lure`.

## Cooldown Mechanics

- Each lure has an independent daily cooldown
- You can use all 5 lures in the same day
- Cooldowns reset at the daily server reset (same as quest reset)
- The addon records kill timestamps and compares against `C_DateAndTime.GetSecondsUntilDailyReset()`

## Installation

1. Download from [CurseForge](https://www.curseforge.com/wow/addons/majestic-beast-tracker) or clone this repo
2. Place `MajesticBeastTracker` folder in `Interface/AddOns/`
3. Requires Skinning with Talented Tracker specialization points

## Technical Notes

- Kill detection uses hidden quest flags via `C_QuestLog.IsQuestFlaggedCompleted()` (CLEU was removed for addons in Midnight 12.0)
- Uses `BackdropTemplate` and `UIPanelCloseButton` (safe in 12.0)
- SavedVariables: `MajesticBeastTrackerDB` (account-wide)
- Dependencies: LibStub, CallbackHandler, LibDataBroker, LibDBIcon
