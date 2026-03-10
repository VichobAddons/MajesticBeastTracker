# Majestic Beast Tracker

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
