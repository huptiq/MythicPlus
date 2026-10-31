local Items = MythicPlus.Module("Items")

local ItemCache = {}

local CLASS_ARMOR_TYPES = {
    [1] = 4,  -- Warrior -> Plate
    [2] = 4,  -- Paladin -> Plate
    [3] = 3,  -- Hunter -> Mail
    [4] = 2,  -- Rogue -> Leather
    [5] = 1,  -- Priest -> Cloth
    [6] = 4,  -- Death Knight -> Plate
    [7] = 3,  -- Shaman -> Mail
    [8] = 1,  -- Mage -> Cloth
    [9] = 1,  -- Warlock -> Cloth
    [11] = 2, -- Druid -> Leather
}

local WEAPON_PROFICIENCY = {
    [176] = {[3] = true, [4] = true, [1] = true}, -- Thrown
    [172] = {[6] = true, [3] = true, [2] = true, [7] = true, [1] = true}, -- Two-Handed Axes
    [43] = {[6] = true, [3] = true, [8] = true, [2] = true, [4] = true, [9] = true, [1] = true}, -- Swords
    [44] = {[6] = true, [3] = true, [2] = true, [7] = true, [1] = true}, -- Axes
    [136] = {[11] = true, [3] = true, [8] = true, [5] = true, [7] = true, [9] = true, [1] = true}, -- Staves
    [160] = {[6] = true, [11] = true, [2] = true, [7] = true, [1] = true}, -- Two-Handed Maces
    [46] = {[3] = true, [4] = true, [1] = true}, -- Guns
    [229] = {[6] = true, [3] = true, [2] = true, [1] = true}, -- Polearms
    [473] = {[11] = true, [3] = true, [4] = true, [7] = true, [1] = true}, -- Fist Weapons
    [54] = {[6] = true, [11] = true, [2] = true, [5] = true, [4] = true, [7] = true, [1] = true}, -- Maces
    [226] = {[3] = true, [4] = true, [1] = true}, -- Crossbows
    [45] = {[3] = true, [4] = true, [1] = true}, -- Bows
    [55] = {[6] = true, [3] = true, [2] = true, [1] = true}, -- Two-Handed Swords
    [228] = {[8] = true, [5] = true, [9] = true}, -- Wands
    [173] = {[11] = true, [3] = true, [8] = true, [5] = true, [4] = true, [7] = true, [9] = true, [1] = true}, -- Daggers
}

local WEAPON_SUBCLASS_TO_SKILL = {
    [0] = 44,
    [1] = 172,
    [2] = 45,
    [3] = 46,
    [4] = 54,
    [5] = 160,
    [6] = 229,
    [7] = 43,
    [8] = 55,
    [10] = 136,
    [13] = 473,
    [15] = 173,
    [16] = 176,
    [18] = 226,
    [19] = 228,
}

local CLASS_FLAGS = {
    [1] = 1,     -- Warrior
    [2] = 2,     -- Paladin
    [3] = 4,     -- Hunter
    [4] = 8,     -- Rogue
    [5] = 16,    -- Priest
    [6] = 32,    -- Death Knight
    [7] = 64,    -- Shaman
    [8] = 128,   -- Mage
    [9] = 256,   -- Warlock
    [11] = 1024  -- Druid
}

local RACE_FLAGS = {
    [1] = 1,     -- Human
    [2] = 2,     -- Orc
    [3] = 4,     -- Dwarf
    [4] = 8,     -- Night Elf
    [5] = 16,    -- Undead
    [6] = 32,    -- Tauren
    [7] = 64,    -- Gnome
    [8] = 128,   -- Troll
    [10] = 512,  -- Blood Elf
    [11] = 1024  -- Draenei
}

local function HasFlag(allowed, flags, value)
    if allowed == 0 then return true end

    local flag = flags[value]
    if not flag then return false end

    return math.floor(allowed / flag) % 2 == 1
end

function Items.CacheItemTemplate(itemId)
    if ItemCache[itemId] then
        return ItemCache[itemId]
    end
    local item = GetItemTemplate(itemId)
    if not item then
        return nil
    end
    ItemCache[itemId] = {
        allowableClass = item:GetAllowableClass(),
        allowableRace = item:GetAllowableRace(),
        class = item:GetClass(),
        subClass = item:GetSubClass(),
        inventoryType = item:GetInventoryType(),
        name = item:GetName(),
        itemLevel = item:GetItemLevel()
    }

    return ItemCache[itemId]
end

function Items.GetItemName(itemId)
    local itemData = Items.CacheItemTemplate(itemId)
    return itemData and itemData.name or "Unknown Item"
end

function Items.CanPlayerUseItem(player, itemId)
    local itemData = Items.CacheItemTemplate(itemId)
    if not itemData then return false end
    local playerClass = player:GetClass()
    local playerRace = player:GetRace()
    if not HasFlag(itemData.allowableClass, CLASS_FLAGS, playerClass) then
        return false
    end
    if not HasFlag(itemData.allowableRace, RACE_FLAGS, playerRace) then
        return false
    end
    if itemData.class == 4 then
        local playerArmorType = CLASS_ARMOR_TYPES[playerClass]
        if playerArmorType and itemData.subClass > 0 then
            if itemData.subClass > playerArmorType then
                return false
            end
        end
    end
    if itemData.class == 2 then
        local skillId = WEAPON_SUBCLASS_TO_SKILL[itemData.subClass]
        if skillId and WEAPON_PROFICIENCY[skillId] then
            if not WEAPON_PROFICIENCY[skillId][playerClass] then
                return false
            end
        end
    end
    return true
end
