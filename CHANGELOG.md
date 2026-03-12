# Majestic Beast Tracker

## [v1.3.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.3.0) (2026-03-12)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.2.0...v1.3.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Major feature update: reagent tracking, weekly knowledge quests, quest-based kill detection, and UI overhaul

### Kill Detection Overhaul
- Kill detection completely rewritten using hidden quest flags per beast
- Each beast has a daily quest ID that Blizzard flags on kill - 100% reliable
- Real-time tracking via QUEST_TURNED_IN event
- Quest flags sync on login, catching kills from other sessions or addons
- Removed old LOOT_OPENED + target GUID system which could miss kills when target changed
- Ready status shown with proper green checkmark icon instead of UTF-8 character

### Reagent Icons
- Reagent icons displayed above each lure column header
- Shows have/need count (e.g., 4/48) when materials are missing
- "Ready" centered across the column when all reagents are sufficient
- "Done" when all characters have already killed that beast
- Only counts characters that still need the lure (excludes already-killed)
- Includes Warbank/Account Bank in item counts
- Shift-click any reagent icon to link item to chat
- Tooltip shows per-lure cost, total need, and missing count
- Fish toggle button next to close button to quickly show/hide reagent icons
- New "Show Reagent Icons" setting
- New "Reagent Count: All Characters" setting to toggle between total need vs single lure need

### Weekly Knowledge Quest Tracking
- Tracks Midnight Skinning weekly knowledge quests per character:
  - Trainer Quest (3 KP, weekly rotation)
  - Skinning Drop / Fine Void-Tempered Hide (5 KP, each tracked individually)
  - Bonus Drop / Mana-Infused Bone (3 KP)
  - Treatise (1 KP, only triggers when consumed, not when in bags)
  - Darkmoon Faire (3 KP, only shown during DMF week)
- Gear popup shows full weekly status for each character
- Main tracker shows only incomplete quests below stats (disappears when all done)
- Real-time updates via BAG_UPDATE_DELAYED and QUEST_TURNED_IN
- Resets automatically on weekly server reset
- New "Show Weekly Knowledge" setting (controls main window only)

### Zone Labels
- Zone names shown below lure icons (Eversong, Zul'Aman, Harandar, Voidstorm, Grand Beast)
- Color-coded to match each lure's theme color

### Lure Column Borders
- Each lure column has a colored border box matching the lure's theme color
- Visual separation between lure columns for better readability

### Profession Stats in Gear Popup
- Gear popup shows per-character stats: Skill, Perception, Finesse, Deftness
- Stats saved to DB per character (base + talents + gear, excluding buffs)
- Updates on login, talent changes, skill changes, and gear swaps
- Item names colored by rarity (green/blue/purple)

### Non-Skinner Auto-Hide
- Tracker no longer opens automatically on characters without Skinning
- Minimap icon always available, frame can still be opened manually
- New "Hide on Non-Skinners" setting

### Layout Improvements
- Column width increased for better reagent count readability
- Two-reagent lures: count texts spread outward for clear separation
- 8px gap between reagent icons on multi-reagent lures

## [v1.2.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.2.0) (2026-03-10)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.1.1...v1.2.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Profession stats display showing Skill, Perception, Finesse, and Deftness

### Profession Stats
- Shows your total Skill, Perception, Finesse, and Deftness at the bottom of the tracker
- Combines stats from talent tree perks, per-point bonuses, equipped gear, and active buffs
- Updates automatically when you drink consumables, change gear, or apply talent points
- Color-coded labels: Skill (gold), Perception (green), Finesse (blue), Deftness (orange)

### Debug Commands
- New `/mbt debug calc` command to see detailed stats breakdown
- New `/mbt debug stats` and `/mbt debug gear` for advanced troubleshooting

## [v1.1.1](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.1.1) (2026-03-10)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.1.0...v1.1.1) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Settings improvements and UI polish

### New Settings
- **Chat Notifications** toggle - disable [MBT] messages in chat
- **Hide in Combat** toggle - automatically hide the tracker during combat

### Improvements
- Logout button moved to bottom-right corner with text label
- Wormhole Generator now correctly detected as a toy
- Removed debug messages from chat output

## [v1.1.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.1.0) (2026-03-09)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.0.5...v1.1.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Consumables, travel buttons, lure enhancements, gear popup

### Consumable Tracking
- Track Sanguithorn Tea and Haranir Phial of Perception with icons at the top of the frame
- Shows remaining buff duration or bag count
- Click to use, Shift-click to search in Auction House
- Golden glow when item is in bags but buff is not active
- Won't accidentally consume if buff still has over 20% duration left

### Lure Improvements
- Click a lure icon to use it directly
- Shift-click to open recipe, press Shift-click again while recipe window is open to start crafting
- Right-click to set a waypoint to the lure's location
- Shows craftable count (including materials in Warbound bank)
- Yellow glow when a lure is ready to use

### Travel Buttons
- Quick-access buttons below the tracker: Hearthstone, Arcantina Key, and Wormhole Generator (Engineering only)
- Shows cooldown timers on each button

### Gear Popup
- Click a character's name to see their equipped skinning tools and accessories

### Logout Button
- Quick logout/character switch button next to the close button
