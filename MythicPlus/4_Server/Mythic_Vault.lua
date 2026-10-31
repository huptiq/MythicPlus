local Vault = MythicPlus.Module("Vault")
local Config = MythicPlus.Config

Vault.LootTable = {}
Vault.Cache = {}

local VaultGenerationTracker = {
    lastProcessedDate = nil,
    eventId = nil
}

function Vault.LoadVaultLootTable()
    local q = WorldDBQuery("SELECT itemid, loot_bracket, chancePercent, faction FROM world_vault_loot")
    if q then
        repeat
            table.insert(Vault.LootTable, {
                itemid = q:GetUInt32(0),
                loot_bracket = q:GetString(1),
                chancePercent = q:GetFloat(2),
                faction = q:GetString(3)
            })
        until not q:NextRow()
    end
    print("[Mythic+] Loaded " .. #Vault.LootTable .. " vault loot entries.")
end

local function GetCurrentVaultWeek()
    local now = os.time()
    local t = os.date("*t", now)

    local daysToSubtract = (t.wday + 3) % 7
    if t.wday == 4 and t.hour < 8 then
        daysToSubtract = daysToSubtract + 7
    end

    t.day = t.day - daysToSubtract
    t.hour = 8
    t.min = 0
    t.sec = 0

    return os.date("%Y-%m-%d", os.time(t))
end

local VAULT_COLUMNS = [[highest_tier_1, highest_tier_2, highest_tier_3, successful_runs,
               item_1_id, item_2_id, item_3_id, items_generated, has_collected, can_collect, week_start]]

function Vault.LoadPlayerVaultCache(guid)
    local currentWeek = GetCurrentVaultWeek()
    local query = CharDBQuery(string.format([[
        SELECT %s
        FROM character_mythic_vault
        WHERE guid = %d AND week_start = '%s'
    ]], VAULT_COLUMNS, guid, currentWeek))

    if not query or (query and query:GetUInt32(9) == 0) then
        query = CharDBQuery(string.format([[
            SELECT %s
            FROM character_mythic_vault
            WHERE guid = %d AND can_collect = 1 AND has_collected = 0
            ORDER BY week_start DESC
            LIMIT 1
        ]], VAULT_COLUMNS, guid))
    end

    if query then
        Vault.Cache[guid] = {
            week_start = query:GetString(10) or currentWeek,
            highest_tier_1 = query:IsNull(0) and nil or query:GetUInt32(0),
            highest_tier_2 = query:IsNull(1) and nil or query:GetUInt32(1),
            highest_tier_3 = query:IsNull(2) and nil or query:GetUInt32(2),
            successful_runs = query:GetUInt32(3),
            item_1_id = query:IsNull(4) and nil or query:GetUInt32(4),
            item_2_id = query:IsNull(5) and nil or query:GetUInt32(5),
            item_3_id = query:IsNull(6) and nil or query:GetUInt32(6),
            items_generated = query:GetUInt32(7) == 1,
            has_collected = query:GetUInt32(8) == 1,
            can_collect = query:GetUInt32(9) == 1
        }
    else
        Vault.Cache[guid] = {
            week_start = currentWeek,
            highest_tier_1 = nil,
            highest_tier_2 = nil,
            highest_tier_3 = nil,
            successful_runs = 0,
            item_1_id = nil,
            item_2_id = nil,
            item_3_id = nil,
            items_generated = false,
            has_collected = false,
            can_collect = false
        }
    end
end

function Vault.GetPlayerVaultCache(guid)
    if not Vault.Cache[guid] then
        Vault.LoadPlayerVaultCache(guid)
    end
    return Vault.Cache[guid]
end

function Vault.SavePlayerVaultCache(guid)
    local cache = Vault.Cache[guid]
    if not cache then return end

    CharDBQuery(string.format([[
        INSERT INTO character_mythic_vault
        (guid, week_start, highest_tier_1, highest_tier_2, highest_tier_3, successful_runs,
         item_1_id, item_2_id, item_3_id, items_generated, has_collected, can_collect)
        VALUES (%d, '%s', %s, %s, %s, %d, %s, %s, %s, %d, %d, %d)
        ON DUPLICATE KEY UPDATE
        highest_tier_1 = %s, highest_tier_2 = %s, highest_tier_3 = %s, successful_runs = %d,
        item_1_id = %s, item_2_id = %s, item_3_id = %s, items_generated = %d, has_collected = %d, can_collect = %d
    ]],
    guid, cache.week_start,
    cache.highest_tier_1 or "NULL", cache.highest_tier_2 or "NULL", cache.highest_tier_3 or "NULL", cache.successful_runs,
    cache.item_1_id or "NULL", cache.item_2_id or "NULL", cache.item_3_id or "NULL",
    cache.items_generated and 1 or 0, cache.has_collected and 1 or 0, cache.can_collect and 1 or 0,
    cache.highest_tier_1 or "NULL", cache.highest_tier_2 or "NULL", cache.highest_tier_3 or "NULL", cache.successful_runs,
    cache.item_1_id or "NULL", cache.item_2_id or "NULL", cache.item_3_id or "NULL",
    cache.items_generated and 1 or 0, cache.has_collected and 1 or 0, cache.can_collect and 1 or 0))
end

local function GetEligibleVaultLoot(player, tier, faction)
    local eligible = {}
    for _, loot in ipairs(Vault.LootTable) do
        if (loot.faction == "N" or loot.faction == faction)
            and MythicPlus.MatchesBracket(Config.VaultLootBrackets, loot.loot_bracket, tier)
            and MythicPlus.Items.CanPlayerUseItem(player, loot.itemid)
        then
            table.insert(eligible, loot)
        end
    end
    return eligible
end

local function RollVaultItem(eligible, usedItems)
    local availableItems = {}
    for _, loot in ipairs(eligible) do
        if not usedItems[loot.itemid] then
            table.insert(availableItems, loot)
        end
    end

    if #availableItems == 0 then
        availableItems = eligible
    end

    local totalWeight = 0
    for _, loot in ipairs(availableItems) do
        totalWeight = totalWeight + loot.chancePercent
    end

    if totalWeight <= 0 then
        return nil
    end

    local roll = math.random() * totalWeight
    local currentWeight = 0
    for _, loot in ipairs(availableItems) do
        currentWeight = currentWeight + loot.chancePercent
        if roll <= currentWeight then
            return loot.itemid
        end
    end
    return nil
end

function Vault.GenerateVaultItemsForPlayer(player)
    local guid = player:GetGUIDLow()
    local cache = Vault.Cache[guid]

    if not cache or cache.items_generated or cache.successful_runs == 0 then
        return
    end
    if not player or not player:IsInWorld() then
        return
    end

    local faction = MythicPlus.GetFaction(player)
    local tiers = {cache.highest_tier_1, cache.highest_tier_2, cache.highest_tier_3}
    local usedItems = {}

    for i, tier in ipairs(tiers) do
        if tier then
            local eligible = GetEligibleVaultLoot(player, tier, faction)
            if #eligible > 0 then
                local itemId = RollVaultItem(eligible, usedItems)
                if itemId then
                    usedItems[itemId] = true
                    cache["item_" .. i .. "_id"] = itemId
                end
            end
        end
    end
    cache.items_generated = true
    cache.can_collect = (cache.item_1_id or cache.item_2_id or cache.item_3_id) and true or false
    Vault.SavePlayerVaultCache(guid)
end

function Vault.UpdateVaultProgress(player, tier, wasSuccessful)
    local guid = player:GetGUIDLow()
    local cache = Vault.GetPlayerVaultCache(guid)

    if wasSuccessful then
        cache.successful_runs = cache.successful_runs + 1
        local tiers = {cache.highest_tier_1, cache.highest_tier_2, cache.highest_tier_3}
        table.insert(tiers, tier)
        table.sort(tiers, function(a, b) return (a or 0) > (b or 0) end)

        cache.highest_tier_1 = tiers[1]
        cache.highest_tier_2 = tiers[2]
        cache.highest_tier_3 = tiers[3]

        Vault.SavePlayerVaultCache(guid)
    end
end

local function WatchVaultDistance(player, go)
    local playerGUID = player:GetGUID()
    local goX, goY, goZ = go:GetX(), go:GetY(), go:GetZ()
    local goMapId = go:GetMapId()
    CreateLuaEvent(function()
        local p = GetPlayerByGUID(playerGUID)

        if not p then
            return false
        end

        if p:GetMapId() ~= goMapId then
            MythicPlus.Handle(p, "CloseVaultGUI")
            return false
        end

        local pX, pY, pZ = p:GetX(), p:GetY(), p:GetZ()
        local distance = math.sqrt((pX - goX)^2 + (pY - goY)^2 + (pZ - goZ)^2)

        if distance > Config.VaultCloseDistance then
            MythicPlus.Handle(p, "CloseVaultGUI")
            return false
        end

        return true
    end, 1000, 0)
end

function Vault.WeeklyVaultInteract(event, go, player)
    local guid = player:GetGUIDLow()
    local cache = Vault.GetPlayerVaultCache(guid)

    if not cache.can_collect or cache.has_collected then
        MythicPlus.SendMessage(player, "No loot available in your vault this week.")
        return
    end

    if not cache.items_generated then
        Vault.GenerateVaultItemsForPlayer(player)
    end

    local tiers = {cache.highest_tier_1, cache.highest_tier_2, cache.highest_tier_3}
    local items = {cache.item_1_id or 0, cache.item_2_id or 0, cache.item_3_id or 0}

    local itemLevels = {0, 0, 0}
    for i, itemId in ipairs(items) do
        if itemId and itemId > 0 then
            local itemData = MythicPlus.Items.CacheItemTemplate(itemId)
            itemLevels[i] = itemData and itemData.itemLevel or 0
        end
    end

    MythicPlus.Handle(player, "QueryItemData", items[1], items[2], items[3])
    MythicPlus.Handle(player, "ShowVaultGUI", items[1], items[2], items[3], tiers[1] or 0, tiers[2] or 0, tiers[3] or 0, itemLevels[1], itemLevels[2], itemLevels[3])

    WatchVaultDistance(player, go)
end

function MythicPlus.Handlers.SelectVaultItem(player, itemIndex)
    local guid = player:GetGUIDLow()
    local cache = Vault.Cache[guid]

    if not cache or not cache.can_collect or cache.has_collected then
        MythicPlus.SendMessage(player, "No loot available to collect.")
        return
    end

    local itemId = nil
    if itemIndex == 1 or itemIndex == 2 or itemIndex == 3 then
        itemId = cache["item_" .. itemIndex .. "_id"]
    end

    if itemId then
        player:AddItem(itemId, 1)
        cache.has_collected = true
        Vault.SavePlayerVaultCache(guid)
        MythicPlus.Handle(player, "UpdateVaultStatus", false)
    end
end

function MythicPlus.Handlers.RequestVaultStatus(player)
    if not player or not player:IsInWorld() then
        return
    end

    local cache = Vault.GetPlayerVaultCache(player:GetGUIDLow())

    if cache.successful_runs > 0 and not cache.items_generated and not cache.has_collected then
        Vault.GenerateVaultItemsForPlayer(player)
    end

    MythicPlus.Handle(player, "UpdateVaultStatus", cache.can_collect and not cache.has_collected)
end

local function ProcessWeeklyVaultGeneration()
    local currentWeek = GetCurrentVaultWeek()
    local query = CharDBQuery(string.format([[
        SELECT DISTINCT guid FROM character_mythic_vault
        WHERE week_start = '%s' AND successful_runs > 0 AND NOT items_generated
    ]], currentWeek))

    if query then
        repeat
            local guid = query:GetUInt32(0)
            local player = GetPlayerByGUID(guid)

            if player then
                Vault.GenerateVaultItemsForPlayer(player)
            else
                local cache = Vault.GetPlayerVaultCache(guid)
                if cache then
                    cache.can_collect = true
                    Vault.SavePlayerVaultCache(guid)
                end
            end
        until not query:NextRow()
    end
end

local function ProcessVaultIfDue(message)
    local t = os.date("*t")
    local currentDate = os.date("%Y-%m-%d")

    if t.wday == 4 and t.hour >= 8 and
       VaultGenerationTracker.lastProcessedDate ~= currentDate then

        VaultGenerationTracker.lastProcessedDate = currentDate
        ProcessWeeklyVaultGeneration()
        print(message .. currentDate)
    end
end

local function ScheduleVaultGeneration()
    if VaultGenerationTracker.eventId then
        RemoveEventById(VaultGenerationTracker.eventId)
    end

    local now = os.time()
    local t = os.date("*t", now)

    local daysUntilWednesday = (11 - t.wday) % 7
    if daysUntilWednesday == 0 and t.hour >= 8 then
        daysUntilWednesday = 7
    end

    local wednesdayTable = os.date("*t", now + (daysUntilWednesday * 24 * 60 * 60))
    wednesdayTable.hour = 8
    wednesdayTable.min = 0
    wednesdayTable.sec = 0

    local delayMs = (os.time(wednesdayTable) - now) * 1000

    VaultGenerationTracker.eventId = CreateLuaEvent(function()
        ProcessVaultIfDue("[Mythic+] Weekly vault generation processed for ")
        ScheduleVaultGeneration()
    end, delayMs, 1)
end

function Vault.CheckAndProcessVaultOnStartup()
    ProcessVaultIfDue("[Mythic+] Weekly vault generation processed on startup for ")
    ScheduleVaultGeneration()
end
