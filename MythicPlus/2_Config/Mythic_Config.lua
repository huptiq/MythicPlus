MythicPlus = MythicPlus or {}

MythicPlus.Config = {
    KeystoneItem = 900100,
    PedestalNpc = 900001,
    VaultGameObject = 900000,

    CountdownSeconds = 10,
    AuraInterval = 6000,
    AuraScanRadius = 240,
    AffixAuraDuration = 86400000,
    DeathPenalty = 10,
    LeaderboardCacheDuration = 900,
    VaultCloseDistance = 6,

    ScalingAura = 58549,
    ScalingAuraTier = 5,

    RewardTypes = {
        pets      = true,
        mounts    = true,
        equipment = false,
        spells    = false,
    },

    LootBrackets = {
        ["low_tier"] = {1, 2, 3},
        ["mid_tier"] = {4, 5, 6, 7},
        ["high_tier"] = {8, 9, 10, 11, 12},
        ["endgame"] = {15, 16, 17, 18, 19, 20},
        ["pets"] = {5, 6, 7, 8, 9},
        ["all"] = "all"
    },

    VaultLootBrackets = {
        ["vault_low"] = {1, 2, 3, 4, 5},
        ["vault_mid"] = {6, 7, 8, 9, 10},
        ["vault_high"] = {11, 12, 13, 14, 15},
        ["vault_legendary"] = {16, 17, 18, 19, 20},
        ["all"] = "all"
    },

    AffixExcludedCreatures = {
        29830,      -- Living Mojo, Gundrak Boss Drakkari Colossus // would break its boss script
        24849       -- Proto-Drake Rider, Utgarde Keep
    },

    KeepCorpseCreatures = {
        [26692] = true, -- 'Ymirjar Harpooner' in Utgarde Pinnacle // would not spawn harpoons otherwise
        [28585] = true, -- 'Slag' in Halls of Lightning // respawn would be too fast
    },

    IgnoredFactions = {
        [1] = true, [2] = true, [3] = true, [4] = true, [31] = true,
        [35] = true, [114] = true, [115] = true, [188] = true, [1629] = true
    }
}
