local Rating = MythicPlus.Module("Rating")

Rating.Cache = {}

local function GetDungeonColumns()
    local columns = {}
    for _, mapId in ipairs(MythicPlus.DungeonOrder) do
        table.insert(columns, "`" .. mapId .. "`")
    end
    return table.concat(columns, ", ")
end

function Rating.LoadPlayerCache(guid)
    if Rating.Cache[guid] then return end
    CharDBQueryAsync(string.format([[
        SELECT total_points, total_runs, completed_runs, out_of_time_runs, too_many_death_runs, %s
        FROM character_mythic_rating WHERE guid = %d
    ]], GetDungeonColumns(), guid), function(result)
        local cache = {
            total_points = 0,
            total_runs = 0,
            completed_runs = 0,
            out_of_time_runs = 0,
            too_many_death_runs = 0
        }
        if result then
            cache.total_points = result:GetDouble(0)
            cache.total_runs = result:GetUInt32(1)
            cache.completed_runs = result:GetUInt32(2)
            cache.out_of_time_runs = result:GetUInt32(3)
            cache.too_many_death_runs = result:GetUInt32(4)
        end
        for i, mapId in ipairs(MythicPlus.DungeonOrder) do
            cache[mapId] = result and result:GetUInt32(4 + i) or 0
        end
        Rating.Cache[guid] = cache
    end)
    MythicPlus.Keystone.LoadPlayerKey(guid)
end

function Rating.SavePlayerRatingCache(guid)
    local cache = Rating.Cache[guid]
    if not cache then return end

    local now = os.time()
    local fields = {
        { "total_runs", cache.total_runs },
        { "total_points", cache.total_points },
        { "completed_runs", cache.completed_runs },
        { "out_of_time_runs", cache.out_of_time_runs },
        { "too_many_death_runs", cache.too_many_death_runs }
    }
    for _, mapId in ipairs(MythicPlus.DungeonOrder) do
        table.insert(fields, { "`" .. mapId .. "`", cache[mapId] })
    end

    local columns, values, updates = {}, {}, {}
    for _, field in ipairs(fields) do
        local value = string.format("%d", field[2])
        table.insert(columns, field[1])
        table.insert(values, value)
        table.insert(updates, field[1] .. " = " .. value)
    end

    CharDBQuery(string.format([[
        INSERT INTO character_mythic_rating
        (guid, %s, last_updated)
        VALUES (%d, %s, FROM_UNIXTIME(%d))
        ON DUPLICATE KEY UPDATE
        %s, last_updated = FROM_UNIXTIME(%d)
    ]], table.concat(columns, ", "), guid, table.concat(values, ", "), now, table.concat(updates, ", "), now))
end

function Rating.AddToStat(guid, stat)
    local cache = Rating.Cache[guid]
    if cache then
        cache[stat] = cache[stat] + 1
        Rating.SavePlayerRatingCache(guid)
    end
end

function Rating.RecalculateTotalPoints(guid)
    local cache = Rating.Cache[guid]
    if not cache then return end

    local total = 0
    for _, mapId in ipairs(MythicPlus.DungeonOrder) do
        total = total + (cache[mapId] or 0)
    end

    cache.total_points = total / #MythicPlus.DungeonOrder

    Rating.SavePlayerRatingCache(guid)
end

function Rating.CalculateMythicRating(tier, timeRemainingPercent)
    -- https://www.wowhead.com/guide/blizzard-mythic-plus-rating-score-in-game
    -- base rating: 37.5 + (tier * 7.5) + (affixes * 7.5)
    local baseRating = 37.5 + (tier * 7.5)
    local affixCount = math.min(tier, 3)
    local affixBonus = affixCount * 7.5

    local totalBaseRating = baseRating + affixBonus

    local timeBonus = 0
    if timeRemainingPercent > 0 then
        local bonusPercent = math.min(timeRemainingPercent, 40) / 40
        timeBonus = bonusPercent * 7.5
    else
        local penaltyPercent = math.min(math.abs(timeRemainingPercent), 40) / 40
        timeBonus = -penaltyPercent * 15
    end

    return math.max(0, totalBaseRating + timeBonus)
end

function Rating.CalculateKeystoneUpgrade(timeRemainingPercent, completed)
    if not completed then
        return -1
    end

    if timeRemainingPercent >= 40 then
        return 3
    elseif timeRemainingPercent >= 20 then
        return 2
    elseif timeRemainingPercent > 0 then
        return 1
    else
        return -1
    end
end

function MythicPlus.Handlers.RequestTotalPoints(player)
    local guid = player:GetGUIDLow()
    local cache = Rating.Cache[guid]

    if not cache then
        Rating.LoadPlayerCache(guid)
        MythicPlus.Handle(player, "ReceiveTotalPoints", 0, {})
        return
    end

    local dungeonScores = {}
    for _, mapId in ipairs(MythicPlus.DungeonOrder) do
        dungeonScores[tostring(mapId)] = cache[mapId] or 0
    end

    MythicPlus.Handle(player, "ReceiveTotalPoints", cache.total_points, dungeonScores)
end
