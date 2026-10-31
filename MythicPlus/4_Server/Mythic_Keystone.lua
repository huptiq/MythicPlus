local Keystone = MythicPlus.Module("Keystone")
local Config = MythicPlus.Config

Keystone.Cache = {}

function Keystone.LoadPlayerKey(guid)
    if Keystone.Cache[guid] then return end
    local keyQuery = CharDBQuery(string.format("SELECT mapId, tier FROM character_mythic_keys WHERE guid = %d", guid))
    if keyQuery then
        Keystone.Cache[guid] = {
            mapId = keyQuery:GetUInt32(0),
            tier = keyQuery:GetUInt32(1)
        }
    end
end

function Keystone.SetKey(guid, mapId, tier)
    Keystone.Cache[guid] = {mapId = mapId, tier = tier}
    CharDBQuery(string.format("REPLACE INTO character_mythic_keys (guid, mapId, tier) VALUES (%d, %d, %d)", guid, mapId, tier))
end

function Keystone.RemoveKey(guid)
    Keystone.Cache[guid] = nil
    CharDBQuery(string.format("DELETE FROM character_mythic_keys WHERE guid = %d", guid))
end

function Keystone.GetTier(guid)
    local keyData = Keystone.Cache[guid]
    return keyData and keyData.tier or 1
end

function Keystone.PlayerHasAnyKeystone(player)
    return player:HasItem(Config.KeystoneItem)
end

function Keystone.HasValidKeyForCurrentDungeon(player)
    local keyData = Keystone.Cache[player:GetGUIDLow()]
    return keyData and keyData.mapId == player:GetMapId()
end

function Keystone.GetRandomMythicMapId()
    local ids = MythicPlus.DungeonOrder
    return ids[math.random(1, #ids)]
end

function Keystone.RefreshTooltip(guid, delay)
    MythicPlus.WithPlayer(guid, delay, MythicPlus.Handlers.RequestMapNameAndTier)
end

function Keystone.GrantKeystone(player, tier, messageKey)
    local guid = player:GetGUIDLow()
    Keystone.SetKey(guid, Keystone.GetRandomMythicMapId(), tier)
    player:AddItem(Config.KeystoneItem, 1)
    MythicPlus.SendMessage(player, messageKey, tier)
    Keystone.RefreshTooltip(guid, 500)
end

function Keystone.DowngradeKeystoneOnFail(player, tier)
    if Keystone.PlayerHasAnyKeystone(player) then
        return
    end

    if tier > 1 then
        Keystone.GrantKeystone(player, tier - 1, "Your keystone has been downgraded to Tier %d.")
    else
        MythicPlus.SendMessage(player, "Your keystone was destroyed.")
    end
end

function Keystone.BindKeystoneToDungeon(event, player, item, count)
    if item:GetEntry() ~= Config.KeystoneItem then
        return
    end

    local guid = player:GetGUIDLow()
    if not Keystone.Cache[guid] then
        Keystone.SetKey(guid, Keystone.GetRandomMythicMapId(), 1)
    end

    Keystone.RefreshTooltip(guid, 100)
end

function Keystone.HeroicEndbossKeyReward(event, player, killed)
    local map = player:GetMap()
    if not map then return end
    if map:GetDifficulty() ~= 1 then return end
    if MythicPlus.State.RunFlags[map:GetInstanceId()] then return end

    local dungeon = MythicPlus.Dungeons[map:GetMapId()]
    if dungeon and killed:GetEntry() == dungeon.final then
        if not Keystone.PlayerHasAnyKeystone(player) then
            player:AddItem(Config.KeystoneItem, 1)
            MythicPlus.SendMessage(player, "You received a Mythic Keystone!")
        end
    end
end

function MythicPlus.Handlers.RequestMapNameAndTier(player)
    local keyData = Keystone.Cache[player:GetGUIDLow()]

    if keyData then
        local mapName = MythicPlus.Names.GetLocalizedDungeonName(player, keyData.mapId)
        MythicPlus.Handle(player, "ReceiveMapNameAndTier", mapName, keyData.tier)
    else
        MythicPlus.Handle(player, "ReceiveMapNameAndTier", MythicPlus.Text(player, "UI", "No Keystone"), 0)
    end
end
