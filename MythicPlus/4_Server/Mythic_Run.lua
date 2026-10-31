local Run = MythicPlus.Module("Run")
local State = MythicPlus.State

function Run.IsRunActive(instanceId)
    return State.RunFlags[instanceId] == true
end

function Run.ClearRun(instanceId)
    State.ActiveRuns[instanceId] = nil
    State.RunFlags[instanceId] = nil
    State.BossKills[instanceId] = nil
    State.EnemyForces[instanceId] = nil
    State.AffixedCreatures[instanceId] = nil
    if State.LoopHandlers[instanceId] then
        RemoveEventById(State.LoopHandlers[instanceId])
        State.LoopHandlers[instanceId] = nil
    end
end

function Run.FinishHistory(runId, completed, startTime, now)
    now = now or os.time()
    local duration = math.max(0, now - startTime)
    CharDBQuery(string.format([[
        UPDATE character_mythic_history
        SET completed = %d,
            end_time = FROM_UNIXTIME(%d),
            duration = %d
        WHERE run_id = %d
    ]], completed, now, duration, runId))
    return duration
end

function Run.SetEndOfRunUnitFlags(player)
    if not player or not player:IsInWorld() then return end
    local map = player:GetMap()
    if not map then return end
    local instanceId = map:GetInstanceId()

    local UNIT_FLAG_NOT_SELECTABLE = 33554432
    local UNIT_FLAG_NON_ATTACKABLE = 2
    local UNIT_FLAG_IMMUNE_TO_PC = 256
    local UNIT_FLAG_IMMUNE_TO_NPC = 512

    local flagsToAdd = UNIT_FLAG_NOT_SELECTABLE + UNIT_FLAG_NON_ATTACKABLE + UNIT_FLAG_IMMUNE_TO_PC + UNIT_FLAG_IMMUNE_TO_NPC

    local function bitwise_or(a, b)
        local result, bitval = 0, 1
        while a > 0 or b > 0 do
            if (a % 2 == 1) or (b % 2 == 1) then
                result = result + bitval
            end
            a = math.floor(a / 2)
            b = math.floor(b / 2)
            bitval = bitval * 2
        end
        return result
    end

    local creatures = player:GetCreaturesInRange(2000, nil, 1, 1)
    for _, creature in ipairs(creatures) do
        local cMap = creature:GetMap()
        if cMap and cMap:GetInstanceId() == instanceId then
            local currentFlags = creature:GetUnitFlags() or 0
            local newFlags = bitwise_or(currentFlags, flagsToAdd)
            if newFlags ~= currentFlags then
                creature:SetUnitFlags(newFlags)
            end
        end
    end
end

local function AbandonRun(player, instanceId)
    local runData = State.ActiveRuns[instanceId]
    if runData and runData.run_id then
        Run.FinishHistory(runData.run_id, 2, runData.start_time)
        MythicPlus.SendMessage(player, "You left the dungeon. The run is over.")
        Run.SetEndOfRunUnitFlags(player)
        MythicPlus.Keystone.DowngradeKeystoneOnFail(player, runData.tier)
    end
    MythicPlus.Handle(player, "KillMythicTimerGUI")
    Run.ClearRun(instanceId)
end

local function CheckOvertime(player, instanceId, mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    local runData = State.ActiveRuns[instanceId]
    if not dungeon or not runData or runData.overtime_started then
        return
    end

    local now = os.time()
    if now - runData.start_time < (dungeon.timer or 900) then
        return
    end

    runData.overtime_started = true
    runData.overtime_start_time = now

    MythicPlus.ForEachMemberInMap(player, mapId, function(member)
        MythicPlus.Handle(member, "StartOvertimeMode")
        MythicPlus.Keystone.DowngradeKeystoneOnFail(member, runData.tier)
        MythicPlus.SendMessage(member, "Time expired! Tier %d failed. You can continue in overtime for the chance of loot.", runData.tier)
    end)

    CharDBQuery(string.format([[
        UPDATE character_mythic_history
        SET completed = 3
        WHERE run_id = %d
    ]], runData.run_id))
end

function Run.StartAuraLoop(player, instanceId, mapId, affixes, interval, tier)
    local guid = player:GetGUIDLow()
    if State.LoopHandlers[instanceId] then
        RemoveEventById(State.LoopHandlers[instanceId])
    end
    State.LoopHandlers[instanceId] = CreateLuaEvent(function()
        local p = GetPlayerByGUID(guid)
        if not p then return end
        if not State.RunFlags[instanceId] then return end
        if p:GetMapId() ~= mapId then
            if p:HasAura(8326) then
                return
            end
            AbandonRun(p, instanceId)
            return
        end

        CheckOvertime(p, instanceId, mapId)
        MythicPlus.Affix.ApplyAuraToNearbyCreatures(p, affixes, tier)
        MythicPlus.Encounters.CheckLocationBoss(p, mapId)
    end, interval, 0)
end

function Run.LeaveDungeonMap(event, player)
    if not MythicPlus.Dungeons[player:GetMapId()] then
        MythicPlus.Handle(player, "KillMythicTimerGUI")
    end
end

function Run.MythicPlayerDeath(event, killer, killed)
    local map = killed:GetMap()
    if not map or map:GetDifficulty() == 0 then return end

    local instanceId = map:GetInstanceId()
    local mapId = map:GetMapId()
    local runData = State.ActiveRuns[instanceId]
    if not runData then return end

    runData.deaths = runData.deaths + 1
    local deaths = runData.deaths
    local tier = runData.tier
    CharDBQuery("UPDATE character_mythic_history SET deaths = " .. deaths .. " WHERE run_id = " .. runData.run_id)
    MythicPlus.HandleMembersInMap(killed, mapId, "UpdateMythicScore", deaths * MythicPlus.Config.DeathPenalty, deaths)

    if deaths < MythicPlus.GetDeathLimit(tier) then
        return
    end
    if not runData.start_time then return end

    Run.FinishHistory(runData.run_id, 2, runData.start_time)

    MythicPlus.ForEachMemberInMap(killed, mapId, function(member)
        MythicPlus.Rating.AddToStat(member:GetGUIDLow(), "too_many_death_runs")
        MythicPlus.Handle(member, "StopMythicTimerGUI", 0)
        MythicPlus.Keystone.DowngradeKeystoneOnFail(member, tier)
    end)

    Run.ClearRun(instanceId)
end

function MythicPlus.Handlers.RequestRunState(player)
    local map = player:GetMap()
    if not map then return end

    local mapId = map:GetMapId()
    local instanceId = map:GetInstanceId()
    local runData = State.ActiveRuns[instanceId]
    local dungeon = MythicPlus.Dungeons[mapId]

    if not Run.IsRunActive(instanceId) or not runData or not dungeon then
        MythicPlus.Handle(player, "ClearRunState")
        return
    end

    local bossTracker = State.BossKills[instanceId]
    local enemyTracker = State.EnemyForces[instanceId]

    local killedBosses = {}
    if bossTracker then
        for idx, entry in ipairs(dungeon.bosses) do
            local killed = true
            for _, remaining in ipairs(bossTracker.remaining) do
                if remaining == entry then
                    killed = false
                    break
                end
            end
            if killed then
                table.insert(killedBosses, idx)
            end
        end
    end

    local enemyForces = {
        current = 0,
        required = dungeon.enemies or 0,
        percentage = 0,
        completed = false
    }

    if enemyTracker then
        enemyForces.current = enemyTracker.current
        enemyForces.required = enemyTracker.required
        enemyForces.percentage = math.min((enemyTracker.current / enemyTracker.required) * 100, 100)
        enemyForces.completed = enemyTracker.completed
    end

    MythicPlus.Handle(player, "RestoreRunState", {
        active = true,
        mapId = mapId,
        tier = runData.tier,
        duration = dungeon.timer or 900,
        elapsed = os.time() - runData.start_time,
        bossNames = MythicPlus.Names.GetLocalizedBossNames(player, mapId),
        killedBosses = killedBosses,
        potentialGain = MythicPlus.Rating.CalculateMythicRating(runData.tier, 0),
        penalty = runData.deaths * MythicPlus.Config.DeathPenalty,
        deaths = runData.deaths,
        maxDeaths = MythicPlus.GetDeathLimit(runData.tier),
        enemyForces = enemyForces,
        overtime = runData.overtime_started or false
    })
end
