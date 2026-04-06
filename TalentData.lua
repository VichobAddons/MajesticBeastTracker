------------------------------------------------------
-- MajesticBeastTracker Talent Data
-- Locale-safe talent detection via numeric pathNode IDs
-- All IDs from Midnight Skinning profession tree
------------------------------------------------------

local addonName, ns = ...

-- Midnight Skinning skill line
local MIDNIGHT_SKILL_LINE = 2917

------------------------------------------------------
-- PathNode IDs (universal, locale-safe)
------------------------------------------------------

-- Tree roots (3 main specializations)
local TREE_THOROUGH_TANNING = 106089   -- +1 Perception per point (root)
local TREE_GAINFUL_GATHERING = 106059  -- +1 Deftness per point (root)
local TREE_TALENTED_TRACKER = 106119   -- +1 Skill per point (root), lure unlocks

-- Sub-specializations of Thorough Tanning
local PATH_SUPERB_SCALES = 106087     -- +1 Skill per point (scaled creatures)
local PATH_LASTING_LEATHER = 106088   -- +1 Skill per point (leathery creatures)

-- Sub-specializations of Gainful Gathering
local PATH_DEDICATED_DIFFUSER = 106056  -- +1 Deftness per point (essence creatures)
local PATH_TROPHY_TAKER = 106057       -- +1 Perception per point (bone creatures)
local PATH_CAREFUL_CARVING = 106058    -- +1 Perception per point (plating creatures)

-- Sub-specializations of Talented Tracker
local PATH_COMPONENT_COLLECTOR = 106117  -- +1 Finesse per point (renowned beasts)
local PATH_MAJESTIC_MATERIALS = 106118   -- +1 Perception per point (renowned beasts)

-- All paths in display order
local ALL_PATHS = {
    -- Thorough Tanning
    { id = TREE_THOROUGH_TANNING,  name = "Thorough Tanning",   isRoot = true,  tree = "tanning",  perPoint = "Perception" },
    { id = PATH_SUPERB_SCALES,     name = "Superb Scales",      isRoot = false, tree = "tanning",  perPoint = "Skill" },
    { id = PATH_LASTING_LEATHER,   name = "Lasting Leather",     isRoot = false, tree = "tanning",  perPoint = "Skill" },
    -- Gainful Gathering
    { id = TREE_GAINFUL_GATHERING, name = "Gainful Gathering",  isRoot = true,  tree = "gathering", perPoint = "Deftness" },
    { id = PATH_DEDICATED_DIFFUSER, name = "Dedicated Diffuser", isRoot = false, tree = "gathering", perPoint = "Deftness" },
    { id = PATH_TROPHY_TAKER,      name = "Trophy Taker",       isRoot = false, tree = "gathering", perPoint = "Perception" },
    { id = PATH_CAREFUL_CARVING,    name = "Careful Carving",    isRoot = false, tree = "gathering", perPoint = "Perception" },
    -- Talented Tracker
    { id = TREE_TALENTED_TRACKER,  name = "Talented Tracker",   isRoot = true,  tree = "tracker",  perPoint = "Skill" },
    { id = PATH_COMPONENT_COLLECTOR, name = "Component Collector", isRoot = false, tree = "tracker", perPoint = "Finesse" },
    { id = PATH_MAJESTIC_MATERIALS,  name = "Majestic Materials",  isRoot = false, tree = "tracker", perPoint = "Perception" },
}

------------------------------------------------------
-- API: Get invested points for a single node
------------------------------------------------------

local function GetNodePoints(configID, nodeID)
    local ok, info = pcall(C_Traits.GetNodeInfo, configID, nodeID)
    if ok and info and info.activeRank and info.activeRank > 0 then
        return math.max(info.activeRank - 1, 0)  -- -1: "learned" counts as rank 1
    end
    return 0
end

------------------------------------------------------
-- API: Get configID for Midnight Skinning
------------------------------------------------------

local function GetConfigID()
    if not C_ProfSpecs then return nil end
    local ok, configID = pcall(C_ProfSpecs.GetConfigIDForSkillLine, MIDNIGHT_SKILL_LINE)
    if ok and configID and configID > 0 then return configID end
    return nil
end

------------------------------------------------------
-- Get invested points for a tree (root + all children recursively)
------------------------------------------------------

local function GetTreePoints(configID, rootNodeID)
    local ok, total = pcall(function()
        local todo = { rootNodeID }
        local points = 0
        while #todo > 0 do
            local nodeID = table.remove(todo)
            local children = C_ProfSpecs.GetChildrenForPath(nodeID)
            if children then
                for _, childID in ipairs(children) do
                    table.insert(todo, childID)
                end
            end
            local info = C_Traits.GetNodeInfo(configID, nodeID)
            if info and info.activeRank and info.activeRank > 0 then
                points = points + info.activeRank
            end
        end
        return points
    end)
    return ok and total or 0
end

------------------------------------------------------
-- PUBLIC API: Get full talent breakdown for current character
-- Returns: { paths = { [pathName] = points, ... }, tracker = N, totalPoints = N }
------------------------------------------------------

function ns.GetTalentBreakdown()
    local configID = GetConfigID()
    if not configID then return nil end

    local result = {
        paths = {},
        trees = { tanning = 0, gathering = 0, tracker = 0 },
        tracker = 0,
        totalPoints = 0,
    }

    for _, path in ipairs(ALL_PATHS) do
        local points
        if path.isRoot then
            points = GetTreePoints(configID, path.id)
        else
            points = GetNodePoints(configID, path.id)
        end
        result.paths[path.name] = points
        if path.isRoot then
            result.trees[path.tree] = points
        end
        result.totalPoints = result.totalPoints + (path.isRoot and 0 or points)  -- avoid double-counting
    end

    result.tracker = result.trees.tracker
    return result
end

------------------------------------------------------
-- PUBLIC API: Get Talented Tracker points (replaces old DetectTalentedTrackerPoints)
------------------------------------------------------

function ns.GetTrackerPoints()
    local configID = GetConfigID()
    if not configID then return 0 end
    return GetTreePoints(configID, TREE_TALENTED_TRACKER)
end

------------------------------------------------------
-- PUBLIC API: Save talent data to charData
------------------------------------------------------

function ns.SaveTalentData(charData)
    if not charData then return end
    local breakdown = ns.GetTalentBreakdown()
    if not breakdown then return end

    charData.talentPoints = breakdown.tracker
    charData.talents = {}
    for _, path in ipairs(ALL_PATHS) do
        charData.talents[path.name] = breakdown.paths[path.name] or 0
    end
end

------------------------------------------------------
-- PUBLIC API: Get path info table for UI display
------------------------------------------------------

function ns.GetTalentPaths()
    return ALL_PATHS
end

ns.TREE_TALENTED_TRACKER = TREE_TALENTED_TRACKER
ns.TREE_THOROUGH_TANNING = TREE_THOROUGH_TANNING
ns.TREE_GAINFUL_GATHERING = TREE_GAINFUL_GATHERING
