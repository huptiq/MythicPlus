local AIO = AIO or require("AIO")
AIO.AddAddon()

MythicPlus = MythicPlus or {}

MythicPlus.DungeonList = {
    { mapId = 574, name = "Utgarde Keep", icon = "Interface\\Icons\\achievement_boss_svalasorrowgrave",
      bosses = {23953, 24200, 24201, 23954}, final = 23954, timer = 1500, enemies = 45 },
    { mapId = 575, name = "Utgarde Pinnacle", icon = "Interface\\Icons\\achievement_boss_kingymiron",
      bosses = {26668, 26687, 26693, 26861}, final = 26861, timer = 1500, enemies = 52 },
    { mapId = 576, name = "The Nexus", icon = "Interface\\Icons\\spell_frost_frozencore",
      bosses = {26731, 26763, 26794, 26723}, final = 26723, timer = 1500, enemies = 38 },
    { mapId = 578, name = "The Oculus", icon = "Interface\\Icons\\achievement_boss_eregos",
      bosses = {27654, 27447, 27655, 27656}, final = 27656, timer = 1500, enemies = 35 },
    { mapId = 595, name = "The Culling of Stratholme", icon = "Interface\\Icons\\achievement_dungeon_cotstratholme_normal",
      bosses = {26529, 26530, 26532, 26533}, final = 26533, timer = 1500, enemies = 58,
      completeOnEvade = { entry = 26533, range = 100 } },
    { mapId = 599, name = "Halls of Stone", icon = "Interface\\Icons\\achievement_boss_sjonnir",
      bosses = {27977, 27975, 27978}, final = 27978, timer = 1500, enemies = 41 },
    { mapId = 600, name = "Drak'Tharon Keep", icon = "Interface\\Icons\\inv_bone_skull_04",
      bosses = {26630, 26631, 27483, 26632}, final = 26632, timer = 1500, enemies = 48 },
    { mapId = 601, name = "Azjol-Nerub", icon = "Interface\\Icons\\inv_misc_head_nerubian_01",
      bosses = {28684, 28921, 29120}, final = 29120, timer = 1500, enemies = 33 },
    { mapId = 602, name = "Halls of Lightning", icon = "Interface\\Icons\\achievement_boss_archaedas",
      bosses = {28586, 28587, 28546, 28923}, final = 28923, timer = 1500, enemies = 42 },
    { mapId = 604, name = "Gundrak", icon = "Interface\\Icons\\achievement_boss_galdarah",
      bosses = {29304, 29573, 29305, 29932, 29306}, final = 29306, timer = 1500, enemies = 55 },
    { mapId = 608, name = "The Violet Hold", icon = "Interface\\Icons\\achievement_reputation_kirintor",
      bosses = {31134}, final = 31134, timer = 1500, enemies = 0 },
    { mapId = 619, name = "Ahn'kahet: The Old Kingdom", icon = "Interface\\Icons\\achievement_boss_yoggsaron_01",
      bosses = {29309, 29308, 29310, 30258, 29311}, final = 29311, timer = 1500, enemies = 46 },
    { mapId = 632, name = "The Forge of Souls", icon = "Interface\\Icons\\achievement_boss_devourerofsouls",
      bosses = {36497, 36502}, final = 36502, timer = 1500, enemies = 32 },
    { mapId = 650, name = "Trial of the Champion", icon = "Interface\\Icons\\achievement_reputation_argentcrusader",
      bosses = {35451}, final = 35451, timer = 1500, enemies = 0 },
    { mapId = 658, name = "Pit of Saron", icon = "Interface\\Icons\\achievement_boss_scourgelordtyrannus",
      bosses = {36494, 36476, 36658}, final = 36658, timer = 1500, enemies = 44 },
    { mapId = 668, name = "Halls of Reflection", icon = "Interface\\Icons\\achievement_dungeon_icecrown_frostmourne",
      bosses = {38112, 38113, 36954}, final = 36954, timer = 1500, enemies = 0,
      completeAt = { entry = 36954, x = 5265.987, y = 1682.8047, radius = 15 } },
}

MythicPlus.Dungeons = {}
MythicPlus.DungeonOrder = {}
for _, dungeon in ipairs(MythicPlus.DungeonList) do
    MythicPlus.Dungeons[dungeon.mapId] = dungeon
    table.insert(MythicPlus.DungeonOrder, dungeon.mapId)
end
