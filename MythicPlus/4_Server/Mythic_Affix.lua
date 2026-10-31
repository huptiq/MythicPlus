local Affix = MythicPlus.Module("Affix")
local Config = MythicPlus.Config

local WeeklyAffixesCache = nil

local function GetCurrentMythicResetDate()
    local now = os.time()
    local t = os.date("*t", now)
    local daysToSubtract = (t.wday - 4) % 7
    t.day = t.day - daysToSubtract
    t.hour = 6
    t.min = 0
    t.sec = 0
    return os.date("%Y-%m-%d", os.time(t))
end

function Affix.LoadOrRollWeeklyAffixes()
    if WeeklyAffixesCache then return end
    local resetDate = GetCurrentMythicResetDate()
    local result = CharDBQuery(string.format("SELECT affix1, affix2, affix3 FROM character_mythic_weekly_affixes WHERE week_start = '%s'", resetDate))
    if result then
        local names = { result:GetString(0), result:GetString(1), result:GetString(2) }
        WeeklyAffixesCache = {}
        for _, name in ipairs(names) do
            local affix = MythicPlus.AffixByName[name]
            if affix then
                table.insert(WeeklyAffixesCache, affix)
            end
        end
    else
        local shuffled = {}
        for i = 1, #MythicPlus.Affixes do shuffled[i] = MythicPlus.Affixes[i] end
        for i = #shuffled, 2, -1 do
            local j = math.random(i)
            shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
        end
        local affix1, affix2, affix3 = shuffled[1], shuffled[2], shuffled[3]
        WeeklyAffixesCache = { affix1, affix2, affix3 }
        CharDBQuery(string.format([[
            INSERT INTO character_mythic_weekly_affixes (week_start, affix1, affix2, affix3)
            VALUES ('%s', '%s', '%s', '%s')
        ]], resetDate, affix1.name, affix2.name, affix3.name))
    end
end

function Affix.GetAffixSet(tier)
    local affixes = {}
    for i = 1, MythicPlus.GetAffixCount(tier) do
        local affix = WeeklyAffixesCache[i]
        if affix then
            if type(affix.spell) == "table" then
                for _, s in ipairs(affix.spell) do
                    table.insert(affixes, s)
                end
            else
                table.insert(affixes, affix.spell)
            end
        end
    end

    if tier >= Config.ScalingAuraTier then
        table.insert(affixes, Config.ScalingAura)
    end

    return affixes
end

function Affix.GetAffixNames(tier)
    local names = {}
    for i = 1, MythicPlus.GetAffixCount(tier) do
        local affix = WeeklyAffixesCache[i]
        if affix then
            table.insert(names, affix.name)
        end
    end
    return names
end

local function IsExcludedCreature(entry)
    for _, excludeId in ipairs(Config.AffixExcludedCreatures) do
        if entry == excludeId then
            return true
        end
    end
    return false
end

local function ApplyAffixAura(creature, spellId, stacks)
    local aura = creature:GetAura(spellId) or creature:AddAura(spellId, creature)
    if not aura then
        return
    end

    aura:SetMaxDuration(Config.AffixAuraDuration)
    aura:SetDuration(Config.AffixAuraDuration)
    if stacks and aura:GetStackAmount() ~= stacks then
        aura:SetStackAmount(stacks)
    end
end

local function IsAffixTarget(creature)
    return creature:IsAlive()
        and creature:IsInWorld()
        and not creature:IsPlayer()
        and creature:IsElite()
        and not IsExcludedCreature(creature:GetEntry())
        and not MythicPlus.IsIgnoredFaction(creature:GetFaction())
end

function Affix.ApplyAuraToNearbyCreatures(player, affixes, tier)
    local map = player:GetMap()
    if not map then
        return
    end

    local instanceId = map:GetInstanceId()
    local affixed = MythicPlus.State.AffixedCreatures[instanceId] or {}
    MythicPlus.State.AffixedCreatures[instanceId] = affixed

    local creatures = player:GetCreaturesInRange(Config.AuraScanRadius, nil, 1, 1)
    for _, creature in ipairs(creatures) do
        local guid = creature:GetGUIDLow()

        if not affixed[guid] and IsAffixTarget(creature) then
            affixed[guid] = true

            for _, spellId in ipairs(affixes) do
                if spellId == Config.ScalingAura then
                    if tier >= Config.ScalingAuraTier then
                        ApplyAffixAura(creature, spellId, tier - (Config.ScalingAuraTier - 1))
                    end
                else
                    ApplyAffixAura(creature, spellId)
                end
            end
        end
    end
end

function Affix.OnCreatureKilled(event, player, killed)
    local map = killed:GetMap()
    local affixed = map and MythicPlus.State.AffixedCreatures[map:GetInstanceId()]
    if affixed then
        affixed[killed:GetGUIDLow()] = nil
    end
end

function MythicPlus.Handlers.RequestWeeklyAffixes(player)
    if WeeklyAffixesCache and #WeeklyAffixesCache >= 3 then
        local affix1 = WeeklyAffixesCache[1].name
        local affix2 = WeeklyAffixesCache[2].name or "-"
        local affix3 = WeeklyAffixesCache[3].name or "-"
        MythicPlus.Handle(player, "ReceiveWeeklyAffixes", affix1, affix2, affix3)
    else
        MythicPlus.Handle(player, "ReceiveWeeklyAffixes", "?", "?", "?")
    end
end
