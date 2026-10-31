local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

MythicPlus = MythicPlus or {}
MythicPlus.Locale = {
    Items = {},
    Dungeons = {},
    UI = {}
}
MythicPlus.Handlers = AIO.AddHandlers("AIO_Mythic", {})
MythicPlus.LocalizeCallbacks = {}

local LocaleIndexes = {
    ["enUS"] = 0, ["enGB"] = 0,
    ["koKR"] = 1,
    ["frFR"] = 2,
    ["deDE"] = 3,
    ["zhCN"] = 4,
    ["zhTW"] = 5,
    ["esES"] = 6,
    ["esMX"] = 7,
    ["ruRU"] = 8
}

function MythicPlus.NewRunState()
    return {
        active = false,
        mapId = nil,
        tier = nil,
        duration = nil,
        elapsed = nil,
        bossNames = {},
        killedBosses = {},
        potentialGain = 0,
        penalty = 0,
        bonus = 0,
        deaths = 0,
        maxDeaths = 0,
        enemyForces = {
            current = 0,
            required = 0,
            percentage = 0,
            completed = false
        },
        saveTime = nil
    }
end

MythicPlusCharRunState = MythicPlus.NewRunState()
AIO.AddSavedVarChar("MythicPlusCharRunState")

function MythicGetLocaleIndex()
    return LocaleIndexes[GetLocale()] or 0
end

function MythicGetText(category, key)
    local entries = MythicPlus.Locale[category]
    if not entries or not entries[key] then
        return key
    end

    local localeIndex = GetLocale() and MythicGetLocaleIndex() or 0
    if not entries[key][localeIndex] then
        return entries[key][0]
    end

    return entries[key][localeIndex]
end

function MythicGetDungeonName(mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    if not dungeon then
        return "Map " .. mapId
    end
    return MythicGetText("Dungeons", dungeon.name)
end

function MythicPlus.OnLocalize(callback)
    table.insert(MythicPlus.LocalizeCallbacks, callback)
end

function UpdateLocalizedElements()
    for _, callback in ipairs(MythicPlus.LocalizeCallbacks) do
        callback()
    end

    if MythicPlusFrame and MythicPlusFrame:IsVisible() and MythicPlusFrame.currentTab then
        MythicPlus.SetActiveTab(MythicPlusFrame.currentTab)
    end
end

function MythicPlus.Handlers.ReceiveLocaleData(_, category, entries)
    if type(entries) == "table" then
        MythicPlus.Locale[category] = entries
        if MythicPlusFrame then
            UpdateLocalizedElements()
        end
    end
end

AIO.Handle("AIO_Mythic", "RequestLocaleData", "Items")
AIO.Handle("AIO_Mythic", "RequestLocaleData", "Dungeons")
AIO.Handle("AIO_Mythic", "RequestLocaleData", "UI")
AIO.Handle("AIO_Mythic", "RequestRunState")
