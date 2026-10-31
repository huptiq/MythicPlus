local Pedestal = MythicPlus.Module("Pedestal")
local State = MythicPlus.State
local Config = MythicPlus.Config

local GOSSIP_INSERT = 100
local GOSSIP_CLOSE = 999

local function Refuse(player, key)
    MythicPlus.SendMessage(player, key)
    player:GossipComplete()
end

function Pedestal.OnGossipHello(_, player, creature)
    if not player:HasItem(Config.KeystoneItem) then
        return Refuse(player, "You do not have a Mythic Keystone.")
    end

    if not MythicPlus.Keystone.HasValidKeyForCurrentDungeon(player) then
        return Refuse(player, "Your keystone does not appear to fit.")
    end

    player:GossipClearMenu()

    local tier = MythicPlus.Keystone.GetTier(player:GetGUIDLow())

    player:GossipMenuAddItem(5, MythicPlus.Text(player, "UI", "Insert Keystone (Tier %d)"):format(tier), 0, GOSSIP_INSERT, false, "", 0)
    player:GossipMenuAddItem(2, MythicPlus.Text(player, "UI", "Step away"), 0, GOSSIP_CLOSE)
    player:GossipSendMenu(1, creature)
end

function Pedestal.OnGossipSelect(_, player, _, _, intid)
    if not MythicPlus.Keystone.HasValidKeyForCurrentDungeon(player) then
        return Refuse(player, "This keystone is not for this dungeon.")
    end

    if intid == GOSSIP_CLOSE then
        player:GossipComplete()
        return
    end

    if intid == GOSSIP_INSERT then
        if not player:HasItem(Config.KeystoneItem) then
            return Refuse(player, "You do not have a Mythic Keystone.")
        end

        local map = player:GetMap()
        if not map or map:GetDifficulty() == 0 then
            return Refuse(player, "Keystones cannot be used in Normal mode dungeons.")
        end

        Pedestal.StartRun(player, map)
        player:GossipComplete()
    end
end

local function CountRunForMembers(members, mapId)
    local Rating = MythicPlus.Rating
    for _, member in ipairs(members) do
        if member:IsInWorld() and member:GetMapId() == mapId then
            local mguid = member:GetGUIDLow()
            if not Rating.Cache[mguid] then
                Rating.LoadPlayerCache(mguid)
            end
            Rating.AddToStat(mguid, "total_runs")
        end
    end
end

local function CreateHistoryEntry(members, mapId, instanceId, tier)
    local guids = {}
    for i = 1, 5 do guids[i] = 0 end
    for i, member in ipairs(members) do
        if i > 5 then break end
        guids[i] = member:GetGUIDLow()
    end

    local safeAffixNames = table.concat(MythicPlus.Affix.GetAffixNames(tier), ", "):gsub("'", "''")

    CharDBQuery(string.format([[
        INSERT INTO character_mythic_history (member_1, member_2, member_3, member_4, member_5, date, mapId, instanceId, tier, completed, deaths, affixes)
        VALUES (%d, %d, %d, %d, %d, '%s', %d, %d, %d, 0, 0, '%s');
    ]], guids[1], guids[2], guids[3], guids[4], guids[5], os.date("%Y-%m-%d"), mapId, instanceId, tier, safeAffixNames))

    local runIdQuery = CharDBQuery("SELECT LAST_INSERT_ID()")
    return runIdQuery and runIdQuery:GetUInt32(0) or 0
end

local function ForEachMemberGuid(memberGuids, mapId, callback)
    for _, guid in ipairs(memberGuids) do
        local member = GetPlayerByGUID(guid)
        if member and member:IsInWorld() and member:GetMapId() == mapId then
            callback(member)
        end
    end
end

local function BeginRun(starter, instanceId, mapId, tier, affixes, memberGuids)
    ForEachMemberGuid(memberGuids, mapId, function(member)
        member:SetRooted(false)
    end)

    State.RunFlags[instanceId] = true
    MythicPlus.Affix.ApplyAuraToNearbyCreatures(starter, affixes, tier)
    MythicPlus.Run.StartAuraLoop(starter, instanceId, mapId, affixes, Config.AuraInterval, tier)
    MythicPlus.Progress.CreateBossTracker(instanceId, mapId, tier)

    local dungeon = MythicPlus.Dungeons[mapId]
    if not dungeon then return end

    local runData = State.ActiveRuns[instanceId]
    if runData then
        runData.start_time = os.time()
        CharDBQuery(string.format([[
            UPDATE character_mythic_history
            SET start_time = FROM_UNIXTIME(%d)
            WHERE run_id = %d
        ]], runData.start_time, runData.run_id))
    end

    local potentialGain = MythicPlus.Rating.CalculateMythicRating(tier, 0)
    ForEachMemberGuid(memberGuids, mapId, function(member)
        MythicPlus.Handle(member, "StartMythicTimerGUI", mapId, tier, dungeon.timer or 900, MythicPlus.Names.GetLocalizedBossNames(member, mapId), potentialGain, dungeon.enemies or 50)
    end)
end

function Pedestal.StartRun(player, map)
    local guid = player:GetGUIDLow()
    local tier = MythicPlus.Keystone.GetTier(guid)
    local mapId = player:GetMapId()
    local instanceId = map:GetInstanceId()
    local members = MythicPlus.GetGroupMembers(player)
    local affixes = MythicPlus.Affix.GetAffixSet(tier)

    CountRunForMembers(members, mapId)

    State.ActiveRuns[instanceId] = {
        guid = guid,
        mapId = mapId,
        tier = tier,
        start_time = nil,
        deaths = 0,
        run_id = CreateHistoryEntry(members, mapId, instanceId, tier),
        members = {}
    }

    for _, member in ipairs(members) do
        if member:IsInWorld() and member:GetMapId() == mapId then
            table.insert(State.ActiveRuns[instanceId].members, member:GetGUIDLow())
        end
    end

    State.RunFlags[instanceId] = false

    player:RemoveItem(Config.KeystoneItem, 1)
    MythicPlus.Keystone.RemoveKey(guid)

    local map_x, map_y, map_z, map_o = GetMapEntrance(mapId)
    local memberGuids = {}
    for _, member in ipairs(members) do
        if member:IsInWorld() and member:GetMapId() == mapId then
            table.insert(memberGuids, member:GetGUID())
            member:NearTeleport(map_x, map_y, map_z, map_o)
            member:SetRooted(true)
        end
    end

    for _, creature in ipairs(player:GetCreaturesInRange(2000, nil, 0, 2)) do
        creature:Respawn()
    end

    ForEachMemberGuid(memberGuids, mapId, function(member)
        MythicPlus.Handle(member, "StartCountdown", Config.CountdownSeconds)
    end)

    local starterGuid = player:GetGUID()
    CreateLuaEvent(function()
        local starter = GetPlayerByGUID(starterGuid)
        if starter then
            BeginRun(starter, instanceId, mapId, tier, affixes, memberGuids)
        end
    end, Config.CountdownSeconds * 1000, 1)
end
