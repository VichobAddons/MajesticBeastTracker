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

### Cooldown Tracking
- **Multi-character tracking** — See all your skinners' cooldowns in one grid
- **Quest-based kill detection** — Uses hidden quest flags for 100% reliable kill tracking, syncs across sessions
- **Click to mark/clear** — Manually mark kills as a fallback
- **Locked lure display** — Lures greyed out for characters without enough talent points

### Loot Tracking & Economy
- **Automatic loot tracking** — Tracks skinning reagents from beast kills per character (daily + all-time)
- **Loot editor** — Click goblin icon to view/edit loot counts with quality tier icons, manual input via EditBox
- **TSM price integration** — Loot values snapshotted at loot time using TradeSkillMaster prices
- **Total reagent cost** — Shows how much gold you need to craft remaining lures

### Warband Bank Deposit
- **Auto-deposit on bank open** — Automatically deposits tracked reagents when you open the Warband Bank
- **Manual deposit button** — Click to deposit all tracked skinning loot and/or lure reagents (fish)
- **Configurable** — Separate toggles for beast rewards and lure reagents

### Reagents & Crafting
- **Reagent icons** — See reagent needs per lure with have/need counts, includes Warbank items
- **Show Missing Count** — Toggle to show missing reagents (e.g. "-56") instead of have/need (e.g. "16/72")
- **Craftable count** — Shows how many lures you can craft from all sources (bags + bank + warband bank)
- **Weekly knowledge tracking** — Track Midnight Skinning weekly KP quests (Trainer, Drops, Treatise, DMF) per character

### Auction House Integration
- **Autofill AH Quantity** — Automatically fills the buy quantity when browsing reagents or consumables in the Auction House
- **Auctionator Shopping List** — One-click button creates an "MBT Reagents" shopping list in Auctionator with all missing reagents and consumables
- **Consumable Stock Targets** — Per-item stock sliders in settings to define how many consumables to keep on hand

### Consumables
- **Consumable tracking** — Track Sanguithorn Tea, Haranir Phial of Perception, and Root Crab with live buff timers
- **Stackable buff support** — Root Crab shows remaining time + bag count, can keep clicking to stack
- **Real-time timers** — Buff countdowns update every second

### Travel & Shortcuts
- **Travel buttons** — Quick-access Hearthstone, Arcantina Key, and Wormhole Generator (Engineering) with cooldowns
- **Lure shortcuts** — Click to use lure, Shift-click to open recipe/craft, Right-click to set waypoint
- **Map waypoints** — Right-click lure icon to set a waypoint to the beast location (Works great with [WaypointUI](https://www.curseforge.com/wow/addons/waypointui))

### Profession Info
- **Gear popup** — Click a character's name to see their equipped skinning tools, accessories, profession stats, and weekly quest status
- **Profession stats** — Per-character Skill, Perception, Finesse, and Deftness (base + talents + gear + buffs)
- **Profession talent detection** — Automatically reads your Talented Tracker points to show only available lures

### Route Planning
- **Per-beast skip** — Skip individual beasts from your daily route
- **Harandar min level** — Auto-skip Harandar for characters below a set level (80-90)
- **Hide Skipped Columns** — Remove skipped columns for a cleaner view
- **Custom route order** — Reorder beasts with up/down arrows in Settings to match your preferred route
- **Auto-Waypoint** — After a kill, automatically pins the next beast in your route on the map

### Character Management
- **Hide characters** — Right-click to hide a character from the tracker without deleting data
- **Show Hidden Characters** — Toggle to temporarily reveal hidden characters
- **Remove characters** — Right-click to permanently remove a character

### UI & Settings
- **Auto-hide** — Tracker fades out when mouse leaves, fades back in on hover
- **Compact bottom bar** — Consumables, travel icons, and profession stats in a single row
- **Adaptive stats layout** — Stats wrap to two rows when the tracker is narrow
- **Golden hover highlights** — Border highlights on lure icons, travel buttons, and consumable icons
- **Zone labels** — Color-coded zone names below each lure column
- **Minimap button** — Left-click toggles window, right-click opens settings
- **Non-skinner auto-hide** — Tracker stays hidden on characters without Midnight Skinning
- **Hide in combat** — Optionally hide the tracker during combat
- **Expandable settings** — Collapsible sections: Route, Reagents & AH, Loot Goblin, Warband Bank, Display, Data Management, Slash Commands

## Lure Locations

| Lure        | Zone           | Beast        | Talent Points |
| ----------- | -------------- | ------------ | ------------- |
| Eversong    | Eversong Woods | Gloomclaw    | 1             |
| Zul'Aman    | Zul'Aman       | Silverscale  | 10            |
| Harandar    | Harandar       | Lumenfin     | 20            |
| Voidstorm   | Voidstorm      | Umbrafang    | 30            |
| Grand Beast | Voidstorm      | Netherscythe | 40            |

## Slash Commands

| Command                  | Action                           |
| ------------------------ | -------------------------------- |
| `/mbt`                   | Show tracker                     |
| `/mbt hide`              | Hide tracker                     |
| `/mbt lock`              | Toggle frame lock                |
| `/mbt settings`          | Open settings                    |
| `/mbt talent N`          | Override talent points (0-40)    |
| `/mbt remove Name-Realm` | Remove a character               |
| `/mbt nuke`              | Clear current character data     |
| `/mbt nuke all`          | Clear ALL data                   |
| `/mbt debug stats`       | Show profession stat breakdown   |
| `/mbt debug gear`        | Show skinning gear detection     |
| `/mbt debug calc`        | Show stat calculation details    |

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
