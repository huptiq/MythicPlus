local AIO = AIO or require("AIO")
AIO.AddAddon()

MythicPlus = MythicPlus or {}

function MythicPlus.GetDeathLimit(tier)
    return (tier == 1) and 6 or 4
end

function MythicPlus.GetAffixCount(tier)
    return math.min(tier, 4)
end
