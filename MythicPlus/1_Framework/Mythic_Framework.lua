local AIO = AIO or require("AIO")
local unpack = unpack or table.unpack

MythicPlus = MythicPlus or {}
MythicPlus.Locale = MythicPlus.Locale or {}
MythicPlus.Handlers = AIO.AddHandlers("AIO_Mythic", {})

MythicPlus.State = {
    ActiveRuns = {},
    RunFlags = {},
    BossKills = {},
    EnemyForces = {},
    LoopHandlers = {},
    AffixedCreatures = {}
}

MythicPlus.LocaleNames = {
    [0] = "enUS",
    [1] = "koKR",
    [2] = "frFR",
    [3] = "deDE",
    [4] = "zhCN",
    [5] = "zhTW",
    [6] = "esES",
    [7] = "esMX",
    [8] = "ruRU"
}

function MythicPlus.Module(name)
    MythicPlus[name] = MythicPlus[name] or {}
    return MythicPlus[name]
end

function MythicPlus.Text(player, category, key)
    local entries = MythicPlus.Locale[category]
    if not entries or not entries[key] then
        return key
    end

    local localeIndex = player:GetDbLocaleIndex()
    if not entries[key][localeIndex] then
        return entries[key][0]
    end

    return entries[key][localeIndex]
end

function MythicPlus.GetLocaleName(player)
    return MythicPlus.LocaleNames[player:GetDbLocaleIndex()] or "enUS"
end

function MythicPlus.SendMessage(player, key, ...)
    local text = MythicPlus.Text(player, "UI", key)
    if select("#", ...) > 0 then
        text = text:format(...)
    end
    player:SendBroadcastMessage("[Mythic+] " .. text)
end

function MythicPlus.Handle(player, handler, ...)
    AIO.Handle(player, "AIO_Mythic", handler, ...)
end

function MythicPlus.GetGroupMembers(player)
    local group = player:GetGroup()
    return group and group:GetMembers() or { player }
end

function MythicPlus.ForEachMemberInMap(player, mapId, callback)
    for _, member in ipairs(MythicPlus.GetGroupMembers(player)) do
        if member:IsInWorld() and member:GetMapId() == mapId then
            callback(member)
        end
    end
end

function MythicPlus.HandleMembersInMap(player, mapId, handler, ...)
    local args = { ... }
    local count = select("#", ...)
    MythicPlus.ForEachMemberInMap(player, mapId, function(member)
        AIO.Handle(member, "AIO_Mythic", handler, unpack(args, 1, count))
    end)
end

function MythicPlus.WithPlayer(guid, delay, callback)
    CreateLuaEvent(function()
        local player = GetPlayerByGUID(guid)
        if player then
            callback(player)
        end
    end, delay, 1)
end

function MythicPlus.GetFaction(player)
    return player:GetTeam() == 67 and "A" or (player:GetTeam() == 469 and "H" or "N")
end

function MythicPlus.IsIgnoredFaction(faction)
    return MythicPlus.Config.IgnoredFactions[faction] == true
end

function MythicPlus.MatchesBracket(brackets, bracket, tier)
    if brackets[bracket] then
        local bracketData = brackets[bracket]
        if bracketData == "all" then
            return true
        elseif type(bracketData) == "table" then
            for _, validTier in ipairs(bracketData) do
                if validTier == tier then
                    return true
                end
            end
            return false
        end
    end

    if bracket == "all" then
        return true
    end

    local singleTier = tonumber(bracket)
    if singleTier then
        return tier == singleTier
    end

    local rangeStart, rangeEnd = bracket:match("^(%d+)-(%d+)$")
    if rangeStart and rangeEnd then
        rangeStart, rangeEnd = tonumber(rangeStart), tonumber(rangeEnd)
        return tier >= rangeStart and tier <= rangeEnd
    end

    local minTier = bracket:match("^(%d+)%+$")
    if minTier then
        minTier = tonumber(minTier)
        return tier >= minTier
    end

    local maxTier = bracket:match("^(%d+)-$")
    if maxTier then
        maxTier = tonumber(maxTier)
        return tier <= maxTier
    end

    return false
end

function MythicPlus.Handlers.RequestLocaleData(player, category)
    if category and MythicPlus.Locale[category] and type(MythicPlus.Locale[category]) == "table" then
        AIO.Handle(player, "AIO_Mythic", "ReceiveLocaleData", category, MythicPlus.Locale[category])
    end
end
