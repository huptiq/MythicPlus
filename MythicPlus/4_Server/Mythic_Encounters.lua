local Encounters = MythicPlus.Module("Encounters")
local Progress = MythicPlus.Module("Progress")

local function CompleteBoss(player, instanceId, mapId, entry)
    MythicPlus.ForEachMemberInMap(player, mapId, function(member)
        member:KilledMonsterCredit(entry)
    end)
    Progress.MarkBossKilled(player, instanceId, mapId, entry)
end

function Encounters.CheckLocationBoss(player, mapId)
    local dungeon = MythicPlus.Dungeons[mapId]
    local point = dungeon and dungeon.completeAt
    if not point then return end
    if player:GetMapId() ~= mapId then return end

    local instanceId = player:GetMap():GetInstanceId()
    if not MythicPlus.Run.IsRunActive(instanceId) then return end
    if not Progress.IsBossRemaining(instanceId, point.entry) then return end

    local distance = math.sqrt((player:GetX() - point.x)^2 + (player:GetY() - point.y)^2)
    if distance <= point.radius then
        CompleteBoss(player, instanceId, mapId, point.entry)
        Progress.CheckRunCompletion(instanceId, mapId)
    end
end

function Encounters.CheckEvadeBoss(event, creature)
    local map = creature:GetMap()
    if not map then return end
    local mapId = map:GetMapId()
    local dungeon = MythicPlus.Dungeons[mapId]
    local boss = dungeon and dungeon.completeOnEvade
    if not boss or creature:GetEntry() ~= boss.entry then return end

    local instanceId = map:GetInstanceId()
    if not MythicPlus.Run.IsRunActive(instanceId) then return end
    if not creature:IsInEvadeMode() then return end

    for _, player in ipairs(creature:GetPlayersInRange(boss.range)) do
        if player:IsInWorld() and player:GetMapId() == mapId then
            player:KilledMonsterCredit(boss.entry)
            if MythicPlus.State.BossKills[instanceId] then
                Progress.MarkBossKilled(player, instanceId, mapId, boss.entry)
                if Progress.AllBossesKilled(instanceId) then
                    Progress.CheckRunCompletion(instanceId, mapId)
                end
            end
        end
    end
end
