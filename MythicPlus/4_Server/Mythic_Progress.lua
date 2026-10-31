local Progress = MythicPlus.Module("Progress")
local State = MythicPlus.State

function Progress.CreateBossTracker(instanceId, mapId, tier)
    local dungeon = MythicPlus.Dungeons[mapId]
    if not dungeon or not dungeon.bosses then
        print("[Mythic+][Error] No boss data for mapId: " .. mapId)
        return
    end

    local tracker = { remaining = {}, indexMap = {}, tier = tier }
    for idx, entry in ipairs(dungeon.bosses) do
        table.insert(tracker.remaining, entry)
        tracker.indexMap[entry] = idx
    end
    State.BossKills[instanceId] = tracker
end

function Progress.IsBossRemaining(instanceId, entry)
    local tracker = State.BossKills[instanceId]
    if not tracker then return false end
    for _, bossEntry in ipairs(tracker.remaining) do
        if bossEntry == entry then
            return true
        end
    end
    return false
end

function Progress.MarkBossKilled(player, instanceId, mapId, entry)
    local tracker = State.BossKills[instanceId]
    if not tracker then return end
    for i, bossEntry in ipairs(tracker.remaining) do
        if bossEntry == entry then
            table.remove(tracker.remaining, i)
            MythicPlus.HandleMembersInMap(player, mapId, "MarkBossKilled", mapId, tracker.indexMap[entry])
            return
        end
    end
end

function Progress.AllBossesKilled(instanceId)
    local tracker = State.BossKills[instanceId]
    return tracker ~= nil and #tracker.remaining == 0
end

function Progress.MythicBossKillCheck(event, player, killed)
    local map = player:GetMap()
    if not map then return end
    local mapId      = map:GetMapId()
    local instanceId = map:GetInstanceId()

    if not MythicPlus.Run.IsRunActive(instanceId) then return end
    if not State.BossKills[instanceId] then return end

    local entry = killed:GetEntry()
    if not MythicPlus.Config.KeepCorpseCreatures[entry] then
        killed:RemoveCorpse()
    end

    Progress.MarkBossKilled(player, instanceId, mapId, entry)

    if Progress.AllBossesKilled(instanceId) then
        Progress.CheckRunCompletion(instanceId, mapId)
    end
end

function Progress.MythicEnemyKillCheck(event, player, killed)
    local map = player:GetMap()
    if not map then return end
    local mapId = map:GetMapId()
    local instanceId = map:GetInstanceId()
    if not MythicPlus.Run.IsRunActive(instanceId) then return end
    local dungeon = MythicPlus.Dungeons[mapId]
    if not dungeon then return end
    if not dungeon.enemies or dungeon.enemies == 0 then
        return
    end

    local entry = killed:GetEntry()
    for _, bossEntry in ipairs(dungeon.bosses) do
        if bossEntry == entry then
            return
        end
    end

    if MythicPlus.IsIgnoredFaction(killed:GetFaction()) then
        return
    end

    if not State.EnemyForces[instanceId] then
        State.EnemyForces[instanceId] = {
            current = 0,
            required = dungeon.enemies or 50,
            completed = false
        }
    end

    local tracker = State.EnemyForces[instanceId]
    tracker.current = tracker.current + 1
    local percentage = math.min((tracker.current / tracker.required) * 100, 100)
    if tracker.current >= tracker.required and not tracker.completed then
        tracker.completed = true
    end

    MythicPlus.HandleMembersInMap(player, mapId, "UpdateEnemyForces", tracker.current, tracker.required, percentage, tracker.completed)
    Progress.CheckRunCompletion(instanceId, mapId)
end

function Progress.CheckRunCompletion(instanceId, mapId)
    local bossTracker = State.BossKills[instanceId]
    local enemyTracker = State.EnemyForces[instanceId]
    local dungeon = MythicPlus.Dungeons[mapId]
    local bossesComplete = bossTracker and #bossTracker.remaining == 0
    local enemyForcesComplete = true
    if dungeon and dungeon.enemies and dungeon.enemies > 0 then
        enemyForcesComplete = enemyTracker and enemyTracker.completed
    end

    if not bossesComplete or not enemyForcesComplete then
        return
    end

    local runData = State.ActiveRuns[instanceId]
    if not runData then return end

    local player = GetPlayerByGUID(runData.guid)
    if not player then return end
    if not runData.start_time then return end

    local now = os.time()
    local timerTotal = dungeon and dungeon.timer or 900
    local deaths = runData.deaths or 0
    local duration = math.max(0, now - runData.start_time)
    local remainingTime = math.max(0, timerTotal - duration)
    local wasOvertime = runData.overtime_started or false

    if runData.run_id and runData.run_id > 0 then
        MythicPlus.Run.FinishHistory(runData.run_id, 1, runData.start_time, now)
    end

    MythicPlus.ForEachMemberInMap(player, mapId, function(member)
        if wasOvertime then
            MythicPlus.Rewards.AwardOvertimeLoot(member, bossTracker.tier)
        else
            MythicPlus.Rewards.AwardMythicPoints(member, bossTracker.tier, duration, deaths, remainingTime)
        end
        MythicPlus.Run.SetEndOfRunUnitFlags(member)
    end)

    MythicPlus.Run.ClearRun(instanceId)
end
