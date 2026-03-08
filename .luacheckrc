std = "lua51"
max_line_length = false
codes = true
self = false
exclude_files = {
    "libs/",
}

globals = {
    -- SavedVariables
    "MajesticBeastTrackerDB",

    -- Slash commands
    "SLASH_MAJESTICBEASTTRACKER1",
    "SLASH_MAJESTICBEASTTRACKER2",
    "SLASH_MAJESTICBEASTTRACKER3",
    "SlashCmdList",

    -- Settings mixins (assigned in InitSettings)
    "LureTracker_SettingsTextMixin",
    "LureTracker_SettingsExpandMixin",

    -- Static popups
    "StaticPopupDialogs",
}

read_globals = {
    -- Lua globals
    "strsplit",
    "wipe",
    "format",
    "tinsert",
    "tremove",
    "unpack",
    "select",
    "type",
    "pairs",
    "ipairs",
    "tonumber",
    "tostring",
    "pcall",
    "string",
    "math",
    "table",

    -- WoW API
    "CreateFrame",
    "CreateColor",
    "CreateFromMixins",
    "UIParent",
    "GetTime",
    "GetServerTime",
    "GetRealmName",
    "GetProfessions",
    "GetProfessionInfo",
    "UnitName",
    "UnitClass",
    "UnitGUID",
    "GetScreenWidth",
    "GetScreenHeight",
    "IsMouseButtonDown",
    "IsControlKeyDown",
    "GameTooltip",
    "StaticPopup_Show",

    -- WoW API namespaces
    "C_AddOns",
    "C_DateAndTime",
    "C_Item",
    "C_Map",
    "C_ProfSpecs",
    "C_SuperTrack",
    "C_Timer",
    "C_TradeSkillUI",
    "C_Traits",
    "C_KeyBindings",
    "UiMapPoint",

    -- WoW constants & tables
    "CLOSE",
    "YES",
    "NO",
    "RAID_CLASS_COLORS",
    "TextureKitConstants",

    -- WoW Frames & Templates
    "Settings",
    "SettingsInbound",
    "SettingsExpandableSectionMixin",
    "SettingsExpandableSectionInitializer",
    "ScrollBoxFactoryInitializerMixin",
    "MinimalSliderWithSteppersMixin",
    "CreateSettingsButtonInitializer",
    "CreateSettingsListSectionHeaderInitializer",
    "CreateKeybindingEntryInitializer",

    -- Libraries
    "LibStub",
}
