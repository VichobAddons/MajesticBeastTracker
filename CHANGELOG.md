# Majestic Beast Tracker

## [v1.6.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.6.0) (2026-03-27)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.5.1...v1.6.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Route system with custom beast ordering, per-beast skip toggles, and auto-waypoint navigation

### Route System (NEW)
- **Per-beast skip** — Skip individual beasts from your daily route (e.g. skip Zul'Aman and Harandar)
- **Harandar min level** — Automatically skip Harandar for characters below a set level (80-90 slider) since the mobs are high level and slow to kill on lower characters
- **Hide Skipped Columns** — Completely remove skipped beast columns from the tracker for a cleaner view
- **Custom route order** — Reorder beasts in the Settings panel with up/down arrow buttons to match your preferred route
- **Auto-Waypoint** — After killing a beast, automatically sets a map waypoint to the next beast in your route. Skips beasts that are already killed, skipped, or locked. Clears waypoint when route is complete

### Hide Characters
- **Hide from tracker** — Right-click a character name and select "Hide character" to remove them from the tracker without deleting their data
- **Show Hidden Characters** — Toggle in Data Management to temporarily reveal hidden characters
- **Route-aware** — Hidden characters are excluded from reagent counts, costs, and AH calculations

### Auto-Hide
- **Fade on mouse leave** — Tracker fades out when your mouse leaves the frame, fades back in on hover
- **Toggle button** — Invisibility icon next to close button for quick toggle
- **Settings toggle** — "Auto-Hide on Mouse Leave" in Display section

### Per-Beast Loot Tracking
- **Loot breakdown by beast** — Hover the goblin icon to see loot per beast (e.g. how much you got from Voidstorm vs Grand Beast)
- **This Reset vs All Time** — Two-column tooltip showing daily and total loot with item quality colors

### Expandable Settings
- Settings panel reorganized into collapsible sections: Route, Reagents & AH, Loot Goblin, Warband Bank, Display, Data Management, and Slash Commands
- General settings (Minimap Icon, Chat Notifications, Hide on Non-Skinners) always visible at the top

### Improvements
- **Warband Bank deposit** — More reliable item deposits using UseContainerItem API instead of cursor manipulation
- **Stats layout** — Profession stats automatically wrap to two rows when the tracker is narrow (fewer columns)
- **Consumable stock fix** — AH autofill now correctly counts only items in your bags, not your warband bank

## [v1.5.1](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.5.1) (2026-03-18)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.5.0...v1.5.1) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Fixed version label showing "Dev" when MajesticBeastTrackerDev addon is installed but disabled

## [v1.5.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.5.0) (2026-03-18)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.4.1...v1.5.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

### Auction House Integration (NEW)
- **Autofill AH Quantity** — When browsing commodities in the Auction House, automatically fills the buy quantity with the number of missing reagents or consumables
  - Hooks into Blizzard's `CommoditiesBuyFrame` via `hooksecurefunc` using the native event system to avoid taint
  - Works with both lure reagents and consumables (based on stock targets)
  - Respects "Show Reagent Icons" toggle — disabled when reagents are hidden
  - New "Autofill AH Quantity" toggle in settings
- **Auctionator Shopping List** — New button (scroll icon) next to the loot goblin creates/updates an "MBT Reagents" shopping list in Auctionator
  - Includes all missing lure reagents with exact quantities needed
  - Includes consumables below their stock target (per-item configurable)
  - Uses `Auctionator.API.v1.CreateShoppingList` and `ConvertToSearchString` with quantity support
  - Button only visible when Auctionator addon is loaded
  - Automatically removes the list when all reagents are ready

### Reagent Display
- **Show Missing Count** — New toggle to show missing reagent counts (e.g. "-56") instead of have/need (e.g. "16/72")
  - Checkmark icon shown when all reagents are available
  - Per-reagent values centered under each icon

### Settings Overhaul
- New **Reagents** section grouping: Show Reagent Icons, Count for All Characters, Show Missing Count, Autofill AH Quantity, and per-consumable stock sliders
- New **Display** section for Show Weekly Knowledge, Hide in Combat, Lock Frame, Window Scale
- **Consumable Stock Targets** — Per-item sliders (0–200) for Sanguithorn Tea, Haranir Phial of Perception, and Root Crab
  - Controls how many of each consumable to include in the Auctionator shopping list
  - Also used by AH autofill when buying consumables

### Bugfixes
- Fixed all remaining ADDON_ACTION_BLOCKED taint errors — wrapped title, consumable box, travel buttons, stats, and all other layout operations in a single `InCombatLockdown()` guard
- Fixed title text overlapping character rows when reagent icons are hidden — adaptive 2-line/3-line title based on reagent toggle state
- Fixed version label showing CurseForge version instead of Dev version when running MajesticBeastTrackerDev
- Fixed dynamic button positioning — Auctionator and Warband Bank buttons chain correctly based on visibility

## [v1.4.1](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.4.1) (2026-03-14)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.4.0...v1.4.1) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Fixed ADDON_ACTION_BLOCKED error that could occur during combat, preventing loot tracking from updating

## [v1.4.0](https://github.com/VichobAddons/MajesticBeastTracker/tree/v1.4.0) (2026-03-14)
[Full Changelog](https://github.com/VichobAddons/MajesticBeastTracker/compare/v1.3.0...v1.4.0) [Previous Releases](https://github.com/VichobAddons/MajesticBeastTracker/releases)

- Major feature update with 1500+ lines of new code: loot tracking, TSM price integration, warband bank deposit, loot editor, craftable count, consumable overhaul, UI redesign, and numerous bugfixes

### Loot Tracking (NEW)
- Automatic loot tracking from Majestic Beast kills using pre-combat bag snapshots
- Tracks all skinning reagents per character with daily reset and all-time totals
- Pre-combat bag snapshot (`PLAYER_REGEN_DISABLED`) captures bag state before loot arrives
- Kill detection via `SyncKillsFromQuests` triggers loot diff with 5-second finalization window
- Per-character goblin icons — click to open loot editor, hover for loot summary tooltip
- Global loot summary goblin icon shows combined loot across all characters
- Loot data persists in SavedVariables with automatic daily reset

### TSM Price Integration (NEW)
- Loot values calculated using TSM `DBMinBuyout` prices snapshotted at loot time
- Prices stored per-item in SavedVariables — shows what you earned when you looted, not current market price
- Falls back to current TSM price for items without saved prices
- Toggle TSM integration via coin icon button or settings
- "Total needed" gold display shows reagent cost for remaining lure crafts
- `FormatGold` / `FormatGoldPositive` helpers for consistent gold formatting

### Loot Editor (NEW)
- Click goblin icon to open per-character loot editor panel
- Shows all tracked reagents with quality tier atlas icons (`Professions-ChatIcon-Quality-12-TierX`)
- Click count to type exact values via inline EditBox — Enter to confirm, Escape to cancel
- Plus/minus buttons for quick adjustments
- Item tooltips on hover (`GameTooltip:SetItemByID`)
- "Loot sync in progress..." overlay blocks editing during active sync
- Closes only via X button or when tracker closes (no accidental close on misclick)
- Item names preloaded asynchronously via `C_Item.RequestLoadItemDataByID` to prevent blank entries on first open

### Warband Bank Deposit (NEW)
- New "Warband Bank" settings section with four toggles:
  - "Enable Warband Bank Deposit" — shows deposit button on tracker when bank is open
  - "Automatically Deposit on Bank Open" — deposits tracked reagents when you open the bank
  - "Deposit Beast Rewards" — include skinning loot (hides, leather, plating, scales)
  - "Deposit Lure Reagents" — include fish used to craft lures
- Primary method: clicks Blizzard's built-in "Deposit All Warband Items" button (no taint)
- Fallback: pcall-wrapped cursor-based item transfer for individual deposits
- Finds partial stacks first, then empty slots via `C_Bank.FetchPurchasedBankTabIDs`
- Deposit button appears on tracker only when Warband Bank is open (`BANKFRAME_OPENED`/`BANKFRAME_CLOSED`)

### Craftable Count (NEW)
- `GetCraftableCount(recipeID)` calculates how many lures you can craft from current reagents
- Counts reagents from bags + bank + warband bank via `C_Item.GetItemCount`
- Displayed in lure header tooltips and reagent icon tooltips

### Consumables (NEW + Enhanced)
- Added Root Crab (Midnight Perception buff) as third consumable alongside Tea and Phial
- Root Crab supports stackable buff — shows remaining time + bag count simultaneously (e.g. "30s 83x")
- Stackable buffs bypass the 20% duration block so you can keep stacking
- Real-time 1-second ticker updates consumable buff timers live (no more stale times)
- Time display shows seconds when under 60s (was always rounding up to 1m)
- Root Crab's Midnight Perception buff included in profession stat calculation

### Header Icon Buttons (NEW)
- Fish toggle button — show/hide reagent icons above lure headers
- Coin toggle button — enable/disable TSM price display
- Global goblin summary button — hover for all-character loot totals
- Warband deposit button — click to deposit tracked items (visible when bank open)
- All header buttons with icon textures, tooltips, and hover highlights

### UI Overhaul
- New branding: "Majestic Beast Tracker" multiline title with version number in the lure icon area
- Bottom bar redesign: consumable box, travel icons, and profession stats on a single compact row
- Golden hover border highlights on lure icons, travel buttons, and consumable icons (HIGHLIGHT layer)
- Zone labels below lure icons enlarged for readability (7pt → 9pt)
- Travel icon cooldown numbers scaled down (0.7x) for readability on smaller icons
- Divider line separates character rows from bottom bar
- Goblin icons stay visible when loot tracking is disabled (greyed out, no interaction)
- Frame width remains constant when toggling loot tracking on/off

### Midnight Skinning Detection
- Now requires actual Midnight Skinning specialization, not just base Skinning
- Uses `C_SpellBook.IsSpellKnown(471014)` for reliable detection
- Characters with only base Skinning are no longer shown in the tracker
- Real-time detection via `SKILL_LINES_CHANGED` — learns/unlearns update instantly without reload

### Quest Flag False Positive Fix
- Players without Talented Tracker had all 5 beast quest flags returning true (Blizzard API quirk)
- Added sanity check on login: if all 5 flags are true but no kills recorded, flags are ignored
- Real-time events (`LOOT_CLOSED`, `BAG_UPDATE_DELAYED`) bypass sanity check so actual kills are always recorded

### Skill Stat Calculation Fix
- Fixed Skill showing 11 instead of 1 for new Midnight Skinning learners
- `GetSkinningSkillLevel()` now verifies professionName contains "Midnight" before returning skill level
- Fixed perk counting: perks with unlockRank=0 no longer counted when player has 0 talent points

### Locked Lure Display
- Lure icons greyed out (desaturated + dimmed) for lures the character can't craft
- "Locked" label shown when no characters are eligible for a lure column
- Kill status still visible on locked lures (dimmed colors) so tracking works regardless of talent points

### Consumable Level Requirements
- Consumables now show level requirement when player is too low level
- Sanguithorn Tea requires level 80, Haranir Phial of Perception requires level 81, Root Crab requires level 80
- Icons greyed out with "Lv80"/"Lv81" label for ineligible characters

### Character Management
- Right-click a character name to open context menu with "Remove character" option
- Confirmation dialog before removal to prevent accidents

### Gear Popup Improvements
- Current character shows "No gear equipped" instead of generic message
- Other characters show "No gear data (login required)" for clarity

### New Slash Commands
- `/mbt debug stats` — show profession stat breakdown
- `/mbt debug gear` — show skinning gear detection
- `/mbt debug calc` — show stat calculation details

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
