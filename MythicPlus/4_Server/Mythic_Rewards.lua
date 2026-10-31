local Rewards = MythicPlus.Module("Rewards")

function Rewards.AwardMythicPoints(player, tier, duration, deaths, remainingTime)
    local map = player:GetMap()
    if not map then return end
    local mapId = map:GetMapId()
    local guid = player:GetGUIDLow()
    local Rating = MythicPlus.Rating

    local cache = Rating.Cache[guid]
    if not cache then
        cache = {
            total_points = 0, total_runs = 0, completed_runs = 0, out_of_time_runs = 0, too_many_death_runs = 0,
            [mapId] = 0
        }
        Rating.Cache[guid] = cache
    end

    local previous = cache[mapId] or 0
    local dungeon = MythicPlus.Dungeons[mapId]
    local timerTotal = dungeon and dungeon.timer or 900
    local timeRemainingPercent = (remainingTime / timerTotal) * 100
    local gainedRating = Rating.CalculateMythicRating(tier, timeRemainingPercent)
    local deathPenalty = deaths * MythicPlus.Config.DeathPenalty
    local finalRating = math.max(0, gainedRating - deathPenalty)
    local newRating = math.max(previous, finalRating)

    cache[mapId] = newRating
    cache.completed_runs = cache.completed_runs + 1
    cache.total_runs = cache.total_runs + 1

    Rating.SavePlayerRatingCache(guid)
    Rating.RecalculateTotalPoints(guid)

    local upgradeLevel = Rating.CalculateKeystoneUpgrade(timeRemainingPercent, true)

    MythicPlus.Handle(player, "StopMythicTimerGUI", remainingTime)
    MythicPlus.Handle(player, "FinalizeMythicScore", deathPenalty, deaths, finalRating - gainedRating + deathPenalty)

    local dfmt = string.format("%02d:%02d", math.floor(duration/60), duration%60)

    local upgradeText = ""
    if upgradeLevel > 0 then
        upgradeText = string.format(" (Key +%d)", upgradeLevel)
    elseif upgradeLevel < 0 then
        upgradeText = " (Key -1)"
    end

    player:SendBroadcastMessage(string.format(
        "[Mythic+] %s\n%s",
        MythicPlus.Text(player, "UI", "Tier %d completed in %s%s."):format(tier, dfmt, upgradeText),
        MythicPlus.Text(player, "UI", "Rating: %d (+%d gained, -%d death penalty)"):format(newRating, gainedRating, deathPenalty)
    ))

    if not MythicPlus.Keystone.PlayerHasAnyKeystone(player) then
        MythicPlus.Keystone.GrantKeystone(player, math.max(1, tier + upgradeLevel), "You received a Tier %d Mythic Keystone!")
    end

    MythicPlus.Loot.TryRewardMythicLoot(player, tier, upgradeLevel)
    MythicPlus.Vault.UpdateVaultProgress(player, tier, true)
    MythicPlus.Leaderboard.Invalidate()
end

function Rewards.AwardOvertimeLoot(player, tier)
    local map = player:GetMap()
    if not map then return end

    MythicPlus.Rating.AddToStat(player:GetGUIDLow(), "completed_runs")
    MythicPlus.Handle(player, "StopMythicTimerGUI", 0)
    MythicPlus.SendMessage(player, "Tier %d completed in overtime.", tier)

    MythicPlus.Loot.TryRewardMythicLoot(player, tier, 0)
    MythicPlus.Leaderboard.Invalidate()
end
