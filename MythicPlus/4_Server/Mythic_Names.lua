local Names = MythicPlus.Module("Names")

local BossNameCache = {
    ["enUS"] = {},
    ["deDE"] = {},
    ["esES"] = {},
    ["esMX"] = {},
    ["frFR"] = {},
    ["koKR"] = {},
    ["ruRU"] = {},
    ["zhCN"] = {},
    ["zhTW"] = {}
}

function Names.LoadBossNames()
    local bossEntries = {}
    local entriesStr = ""

    for _, data in ipairs(MythicPlus.DungeonList) do
        if data.bosses then
            for _, entry in ipairs(data.bosses) do
                if not bossEntries[entry] then
                    bossEntries[entry] = true
                    if entriesStr ~= "" then
                        entriesStr = entriesStr .. ","
                    end
                    entriesStr = entriesStr .. entry
                end
            end
        end
    end

    if entriesStr == "" then
        print("[Mythic+] No boss entries found to load names for")
        return
    end

    local query = WorldDBQuery("SELECT entry, name FROM creature_template WHERE entry IN (" .. entriesStr .. ")")
    if query then
        repeat
            BossNameCache["enUS"][query:GetUInt32(0)] = query:GetString(1)
        until not query:NextRow()
    end

    local locales = {"deDE", "esES", "esMX", "frFR", "koKR", "ruRU", "zhCN", "zhTW"}

    for _, locale in ipairs(locales) do
        local localeQuery = WorldDBQuery(
            "SELECT entry, Name FROM creature_template_locale WHERE entry IN (" ..
            entriesStr .. ") AND locale = '" .. locale .. "'"
        )

        if localeQuery then
            repeat
                BossNameCache[locale][localeQuery:GetUInt32(0)] = localeQuery:GetString(1)
            until not localeQuery:NextRow()
        end
    end
end

function Names.GetLocalizedBossNames(player, mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    if not dungeon or not dungeon.bosses then
        return {}
    end

    local locale = MythicPlus.GetLocaleName(player)
    local bossNames = {}

    for _, bossId in ipairs(dungeon.bosses) do
        local name = BossNameCache[locale][bossId] or
                    BossNameCache["enUS"][bossId] or
                    ("Boss #" .. bossId)
        table.insert(bossNames, name)
    end

    return bossNames
end

function Names.GetLocalizedDungeonName(player, mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    if dungeon then
        return MythicPlus.Text(player, "Dungeons", dungeon.name)
    end
    return "Unknown (" .. mapId .. ")"
end
