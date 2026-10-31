local AIO = AIO or require("AIO")
AIO.AddAddon()

MythicPlus = MythicPlus or {}

MythicPlus.Affixes = {
    { name = "Enrage", spell = 8599, icon = "Interface\\Icons\\spell_nature_shamanrage", color = "|cffff0000" },
    { name = "Rejuvenating", spell = {48441, 61301}, icon = "Interface\\Icons\\ability_druid_empoweredrejuvination", color = "|cff00ff00" },
    { name = "Turtling", spell = 871, icon = "Interface\\Icons\\ability_warrior_shieldmastery", color = "|cffffff00" },
    { name = "Shamanism", spell = {57662, 57621, 58738, 8515}, icon = "Interface\\Icons\\spell_fire_totemofwrath", color = "|cffa335ee" },
    { name = "Magus", spell = {43015, 43008, 43046, 57531, 12043}, icon = "Interface\\Icons\\ability_mage_hotstreak", color = "|cff3399ff" },
    { name = "Priest Empowered", spell = {48161, 48066, 6346, 48168, 15286}, icon = "Interface\\Icons\\spell_holy_searinglightpriest", color = "|cffcccccc" },
    { name = "Demonism", spell = {47893, 50589}, icon = "Interface\\Icons\\ability_warlock_demonicpower", color = "|cff8b0000" },
    { name = "Falling Stars", spell = 53201, icon = "Interface\\Icons\\ability_druid_starfall", color = "|cff66ccff" },
}

MythicPlus.AffixByName = {}
for _, affix in ipairs(MythicPlus.Affixes) do
    MythicPlus.AffixByName[affix.name] = affix
end
