local Loot = MythicPlus.Module("Loot")
local Config = MythicPlus.Config

local MythicLootTable = {}

local RewardTypeEnabled = {
    pet = "pets",
    mount = "mounts",
    gear = "equipment",
    spell = "spells"
}

function Loot.LoadMythicLootTable()
    MythicLootTable = {}
    local q = WorldDBQuery("SELECT itemid, itemname, amount, type, faction, loot_bracket, chancePercent, additionalID, additionalType FROM world_mythic_loot")
    if q then
        repeat
            table.insert(MythicLootTable, {
                itemid         = q:GetUInt32(0),
                itemname       = q:GetString(1),
                amount         = q:GetUInt32(2),
                type           = q:GetString(3),
                faction        = q:GetString(4),
                loot_bracket   = q:GetString(5),
                chancePercent  = q:GetFloat(6),
                additionalID   = q:IsNull(7) and nil or q:GetUInt32(7),
                additionalType = q:IsNull(8) and nil or q:GetString(8),
            })
        until not q:NextRow()
    end
    print("[Mythic+] Loaded " .. #MythicLootTable .. " mythic+ loot entries.")
end

function Loot.CalculateLootBonus(upgradeLevel)
    local chanceMultiplier = 1.0
    local maxItems = 1

    if upgradeLevel == 2 then
        chanceMultiplier = 1.25
        maxItems = 1
    elseif upgradeLevel >= 3 then
        chanceMultiplier = 1.5
        maxItems = 2
    end

    return chanceMultiplier, maxItems
end

local function IsEligible(player, loot, tier, faction)
    local configKey = RewardTypeEnabled[loot.type]
    if configKey and not Config.RewardTypes[configKey] then return false end
    if not MythicPlus.MatchesBracket(Config.LootBrackets, loot.loot_bracket, tier) then return false end
    if loot.faction ~= "N" and loot.faction ~= faction then return false end
    if loot.type == "gear" and not MythicPlus.Items.CanPlayerUseItem(player, loot.itemid) then return false end
    return true
end

local function GiveReward(player, reward)
    if reward.type == "gear" or reward.type == "pet" or reward.type == "mount" then
        player:AddItem(reward.itemid, reward.amount)
        player:SendBroadcastMessage("[Mythic+] " .. MythicPlus.Text(player, "UI", "Reward:") .. " " .. MythicPlus.Items.GetItemName(reward.itemid))
    elseif reward.type == "spell" then
        player:LearnSpell(reward.itemid)
        MythicPlus.SendMessage(player, "Reward: Spell learned!")
    end
    if reward.additionalID and reward.additionalType then
        if reward.additionalType == "item" then
            player:AddItem(reward.additionalID, 1)
        elseif reward.additionalType == "spell" then
            player:LearnSpell(reward.additionalID)
        elseif reward.additionalType == "skill" then
            player:AdvanceSkill(reward.additionalID, 1)
        end
    end
end

function Loot.TryRewardMythicLoot(player, tier, upgradeLevel)
    local faction = MythicPlus.GetFaction(player)
    local eligible = {}
    local chanceMultiplier, maxItems = Loot.CalculateLootBonus(upgradeLevel)

    for _, loot in ipairs(MythicLootTable) do
        if IsEligible(player, loot, tier, faction) then
            table.insert(eligible, loot)
        end
    end

    if #eligible == 0 then return end

    local rewardsGiven = 0
    local awardedItems = {}

    for attempt = 1, maxItems do
        if rewardsGiven >= maxItems then break end

        local availableItems = {}
        for _, loot in ipairs(eligible) do
            if not awardedItems[loot.itemid] then
                table.insert(availableItems, loot)
            end
        end

        if #availableItems == 0 then break end

        local reward = availableItems[math.random(1, #availableItems)]
        local adjustedChance = reward.chancePercent * chanceMultiplier
        if math.random() * 100 <= adjustedChance then
            GiveReward(player, reward)
            awardedItems[reward.itemid] = true
            rewardsGiven = rewardsGiven + 1
        end
    end

    if upgradeLevel >= 2 then
        local upgradeText = upgradeLevel == 2 and MythicPlus.Text(player, "UI", "+2 Performance") or MythicPlus.Text(player, "UI", "+3 Performance")
        player:SendBroadcastMessage("[Mythic+] " .. upgradeText .. " - " .. MythicPlus.Text(player, "UI", "Enhanced loot chances applied!"))
    end
end
