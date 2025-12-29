--==================================================
-- CONFIG
--==================================================

local logger = require '@qbx_core.modules.logger'
Config = {}

Config.MaxLevel = 50
Config.BaseXP = 100
Config.GrowthRate = 1.15

-- Only define categories; XP is given manually
Config.Categories = {
    "delivery",
    "garbage",
    "farming",
    "criminal",
    "electric",
    "crafting",
    "driving",
    "fishing",
}

-- Generate XP per level for each category
function Config.GenerateXPLevels(maxLevel, baseXP, growthRate)
    local levels = {}
    for lvl = 1, maxLevel do
        levels[lvl] = math.floor(baseXP * (growthRate ^ (lvl - 1)))
    end
    return levels
end

Config.CategoryLevels = {}
for _, category in ipairs(Config.Categories) do
    Config.CategoryLevels[category] = Config.GenerateXPLevels(Config.MaxLevel, Config.BaseXP, Config.GrowthRate)
end

--==================================================
-- VARIABLES
--==================================================

PlayerData = {} -- PlayerData[playerID] = { categories = { police = {level=1, xp=0}, ... } }

--==================================================
-- DATABASE AUTO-CREATE
--==================================================

CreateThread(function()
    local query = [[
        CREATE TABLE IF NOT EXISTS meiku_levels (
            identifier VARCHAR(50) NOT NULL PRIMARY KEY,
            categories JSON NOT NULL
        )
    ]]
    MySQL.execute(query, {})
    print("^2[Generic Leveling] Database table 'meiku_levels' ensured.^7")
end)

--==================================================
-- HELPER FUNCTIONS
--==================================================

local function GetPlayerIdentifier(playerID)
    local Player = exports.qbx_core:GetPlayer(playerID)
    if Player then
        return Player.PlayerData.citizenid
    end
    return nil
end

--==================================================
-- PLAYER CONNECT / DISCONNECT
--==================================================

AddEventHandler('playerSpawned', function()
    local playerID = source
    local citizenid = GetPlayerIdentifier(playerID)
    if not citizenid then return end

    -- Initialize PlayerData
    PlayerData[playerID] = PlayerData[playerID] or { categories = {} }

    -- Check if player exists in DB
    local result = MySQL.scalar.await("SELECT categories FROM meiku_levels WHERE identifier = ?", {citizenid})

    if not result then
        -- Player not in DB, create default categories
        local categories = {}
        for _, category in ipairs(Config.Categories) do
            categories[category] = { level = 1, xp = 0 }
        end
        PlayerData[playerID].categories = categories

        -- Insert into DB
        MySQL.insert.await(
            "INSERT INTO meiku_levels (identifier, categories) VALUES (?, ?)",
            { citizenid, json.encode(categories) }
        )
    else
        -- Player exists, decode JSON
        local categories = json.decode(result)
        PlayerData[playerID].categories = categories

        -- Ensure all categories exist (in case you added new ones)
        for _, category in ipairs(Config.Categories) do
            if not PlayerData[playerID].categories[category] then
                PlayerData[playerID].categories[category] = { level = 1, xp = 0 }
            end
        end

        -- Update DB if new categories added
        MySQL.insert.await(
            "INSERT INTO meiku_levels (identifier, categories) VALUES (?, ?) ON DUPLICATE KEY UPDATE categories = ?",
            { citizenid, json.encode(PlayerData[playerID].categories), json.encode(PlayerData[playerID].categories) }
        )
    end
end)

AddEventHandler('playerDropped', function(reason)
    local playerID = source
    local citizenid = GetPlayerIdentifier(playerID)
    if not citizenid or not PlayerData[playerID] then return end

    MySQL.insert.await(
        "INSERT INTO meiku_levels (identifier, categories) VALUES (?, ?) ON DUPLICATE KEY UPDATE categories = ?",
        {citizenid, json.encode(PlayerData[playerID].categories), json.encode(PlayerData[playerID].categories)}
    )

    PlayerData[playerID] = nil
end)

--==================================================
-- XP FUNCTIONS
--==================================================
function AddXP(playerID, category, xpAmount)
    if not xpAmount or xpAmount <= 0 then return end

    -- Ensure PlayerData exists
    PlayerData[playerID] = PlayerData[playerID] or { categories = {} }

    -- Try to load DB categories for this player and merge (do not overwrite existing in-memory data)
    local citizenid = GetPlayerIdentifier(playerID)
    if citizenid then
        local result = MySQL.scalar.await("SELECT categories FROM meiku_levels WHERE identifier = ?", {citizenid})
        if result then
            local dbCategories = json.decode(result) or {}
            for k, v in pairs(dbCategories) do
                if not PlayerData[playerID].categories[k] then
                    PlayerData[playerID].categories[k] = v
                end
            end
        end
    end

    -- Ensure category table exists locally
    if not PlayerData[playerID].categories[category] then
        PlayerData[playerID].categories[category] = { level = 1, xp = 0 }
    end
    if not Config.CategoryLevels[category] then
        Config.CategoryLevels[category] = Config.GenerateXPLevels(Config.MaxLevel, Config.BaseXP, Config.GrowthRate)
    end

    local data = PlayerData[playerID].categories[category]

    if data.level >= Config.MaxLevel then
        data.xp = math.min((data.xp or 0) + xpAmount, Config.CategoryLevels[category][Config.MaxLevel] or 0)
    else
        data.xp = (data.xp or 0) + xpAmount
        local nextXP = Config.CategoryLevels[category] and Config.CategoryLevels[category][data.level] or nil
        while nextXP and data.xp >= nextXP and data.level < Config.MaxLevel do
            data.xp = data.xp - nextXP
            data.level = data.level + 1
            nextXP = Config.CategoryLevels[category] and Config.CategoryLevels[category][data.level] or nil
        end
    end

    logger.log({
        source = playerID,
        event = 'stressy-levels:AddXP',
        message = citizenid .. " Triggered AddedXP to " .. category .. " with Amount " .. xpAmount,
    })
    -- Save back to DB (use await to reduce race conditions)
    if citizenid then
        MySQL.insert.await(
            "INSERT INTO meiku_levels (identifier, categories) VALUES (?, ?) ON DUPLICATE KEY UPDATE categories = ?",
            { citizenid, json.encode(PlayerData[playerID].categories), json.encode(PlayerData[playerID].categories) }
        )
    end
end

function GetCategoryData(playerID, category)
    if PlayerData[playerID] and PlayerData[playerID].categories[category] then
        return PlayerData[playerID].categories[category]
    else
        return { level = 1, xp = 0 }
    end
end

local function GetAllXP(playerID)
    local allXP = {}

    -- Ensure PlayerData exists
    if not PlayerData[playerID] then
        PlayerData[playerID] = { categories = {} }

        local citizenid = GetPlayerIdentifier(playerID)
        if citizenid then
            local result = MySQL.scalar.await("SELECT categories FROM meiku_levels WHERE identifier = ?", {citizenid})
            if result then
                local categories = json.decode(result)
                PlayerData[playerID].categories = categories
            else
                -- If nothing in DB, create default categories with 0 XP
                for _, category in ipairs(Config.Categories) do
                    PlayerData[playerID].categories[category] = { level = 1, xp = 0 }
                end
            end
        end
    end

    -- Build allXP table with defaults
    for _, category in ipairs(Config.Categories) do
        local data = { level = 1, xp = 0 }  -- default

        if PlayerData[playerID].categories[category] then
            data = PlayerData[playerID].categories[category]
        end

        local nextXP = Config.CategoryLevels[category] and Config.CategoryLevels[category][data.level] or 0

        allXP[category] = {
            level = data.level or 1,
            xp = data.xp or 0,
            nextLevelXP = nextXP
        }
    end

    return allXP
end

-- New export: fetch only the level for a category, with DB JSON fallback
function GetCategoryLevel(playerID, category)
    local citizenid = GetPlayerIdentifier(playerID)
    if not citizenid then return 1 end
    local result = MySQL.scalar.await("SELECT categories FROM meiku_levels WHERE identifier = ?", {citizenid})
    if result then
        local categories = json.decode(result)
        if categories and categories[category] and categories[category].level then
            return categories[category].level
        end
    end
    return 1
end



--==================================================
-- CALLBACKS
--==================================================

lib.callback.register('stressy-levels:getCategoryData', function(source, category)
    return GetCategoryData(source, category)
end)

lib.callback.register('stressy-levels:getNextLevelXP', function(source, category)
    local data = GetCategoryData(source, category)
    local nextXP = Config.CategoryLevels[category] and Config.CategoryLevels[category][data.level] or 0
    return nextXP
end)

lib.callback.register('stressy-levels:getAllXP', function(source)
    return GetAllXP(source)
end)

lib.callback.register('stressy-levels:getCategoryLevel', function(source, category)
    return GetCategoryLevel(source,category)
end)

--==================================================
-- EXPORTS
--==================================================

exports('AddXP', AddXP)
exports('GetCategoryData', GetCategoryData)
exports('GetAllXP', GetAllXP)
exports('GetCategoryLevel', GetCategoryLevel)



--==================================================
-- COMMANDS
--==================================================

-- -- Show your XP
-- RegisterCommand("myxp", function(source, args, rawCommand)
--     local allXP = GetAllXP(source)
--     if not allXP or next(allXP) == nil then
--         TriggerClientEvent('chat:addMessage', source, { color = {255,0,0}, args = {"XP System", "No XP data found."} })
--         return
--     end

--     local msg = ""
--     for category, data in pairs(allXP) do
--         msg = msg .. string.format("%s: Level %d | XP: %d / %d\n", category, data.level, data.xp, data.nextLevelXP)
--     end

--     TriggerClientEvent('chat:addMessage', source, { color = {0,150,255}, multiline = true, args = {"XP System", msg} })
-- end, false)


-- -- Add XP manually for testing
-- RegisterCommand("addxp", function(source, args, rawCommand)
--     local targetID = tonumber(args[1]) or source
--     if args[1] == "0" then targetID = source end

--     local category = args[2]
--     local amount = tonumber(args[3])
--     if not category or not amount then
--         TriggerClientEvent('chat:addMessage', source, { color={255,0,0}, args={"XP System","Usage: /addxp [playerID or 0] [category] [amount]"}})
--         return
--     end

--     if not Config.Categories[category] and not Config.CategoryLevels[category] then
--         TriggerClientEvent('chat:addMessage', source, { color={255,0,0}, args={"XP System","Invalid category: "..category}})
--         return
--     end

--     AddXP(targetID, category, amount)

--     TriggerClientEvent('chat:addMessage', source, { color={0,255,0}, args={"XP System","Added "..amount.." XP to player "..targetID.." ("..category..")"}})
--     if targetID ~= source then
--         TriggerClientEvent('chat:addMessage', targetID, { color={0,150,255}, args={"XP System","You received "..amount.." XP in "..category}})
--     end
-- end, true)
