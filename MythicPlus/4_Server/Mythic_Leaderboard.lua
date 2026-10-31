local Leaderboard = MythicPlus.Module("Leaderboard")
local Config = MythicPlus.Config

local PlayerNamesCache = {}
local LeaderboardCache = {
    topThree = {},
    dungeonTop = {},
    lastUpdate = 0
}

function Leaderboard.SetPlayerName(guid, name)
    PlayerNamesCache[guid] = name
end

local function GetPlayerName(guid)
    local name = PlayerNamesCache[guid]
    if not name then
        local nameQ = CharDBQuery("SELECT name FROM characters WHERE guid = " .. guid)
        if nameQ then
            name = nameQ:GetString(0)
            PlayerNamesCache[guid] = name
        else
            name = "Unknown"
        end
    end
    return name
end

local function LoadHighestKey(mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    local timerLimit = dungeon and dungeon.timer or 1500
    local keyQuery = CharDBQuery(string.format([[
        SELECT h.tier, h.member_1, h.member_2, h.member_3, h.member_4, h.member_5
        FROM character_mythic_history h
        WHERE h.mapId = %d
          AND h.completed = 1
          AND h.duration <= %d
          AND h.duration > 0
        ORDER BY h.tier DESC
        LIMIT 1
    ]], mapId, timerLimit))

    local highestKey = 0
    local keyHolderNames = {}
    if keyQuery then
        highestKey = keyQuery:GetUInt32(0) or 0
        for i = 1, 5 do
            local memberGuid = keyQuery:GetUInt32(i)
            if memberGuid and memberGuid > 0 then
                table.insert(keyHolderNames, GetPlayerName(memberGuid))
            end
        end
    end
    return highestKey, keyHolderNames
end

function Leaderboard.UpdateLeaderboardCache()
    local now = os.time()
    if now - LeaderboardCache.lastUpdate < Config.LeaderboardCacheDuration then
        return
    end

    local top3Query = CharDBQuery([[ SELECT guid, total_points FROM character_mythic_rating ORDER BY total_points DESC LIMIT 3 ]])
    LeaderboardCache.topThree = {}
    if top3Query then
        repeat
            local guid = top3Query:GetUInt32(0)
            local points = top3Query:GetDouble(1)
            table.insert(LeaderboardCache.topThree, { name = GetPlayerName(guid), points = points })
        until not top3Query:NextRow()
    end

    LeaderboardCache.dungeonTop = {}
    for _, mapId in ipairs(MythicPlus.DungeonOrder) do
        local scoreQuery = CharDBQuery("SELECT guid, `" .. mapId .. "` FROM character_mythic_rating ORDER BY `" .. mapId .. "` DESC LIMIT 1")
        if scoreQuery and scoreQuery:GetUInt32(1) > 0 then
            local guid = scoreQuery:GetUInt32(0)
            local score = scoreQuery:GetUInt32(1)
            local name = GetPlayerName(guid)
            local highestKey, keyHolderNames = LoadHighestKey(mapId)
            LeaderboardCache.dungeonTop[tostring(mapId)] = {
                name = name,
                score = score,
                highestKey = highestKey,
                keyHolderNames = keyHolderNames
            }
        end
    end

    LeaderboardCache.lastUpdate = now
end

function Leaderboard.Invalidate()
    LeaderboardCache.lastUpdate = 0
end

function MythicPlus.Handlers.RequestLeaderboard(player)
    Leaderboard.UpdateLeaderboardCache()
    MythicPlus.Handle(player, "ReceiveLeaderboard", LeaderboardCache.topThree, LeaderboardCache.dungeonTop)
end
