local Session = MythicPlus.Module("Session")

function Session.OnPlayerLogin(event, player)
    local guid = player:GetGUIDLow()
    MythicPlus.Rating.LoadPlayerCache(guid)
    MythicPlus.Vault.LoadPlayerVaultCache(guid)
    MythicPlus.Leaderboard.SetPlayerName(guid, player:GetName())
    MythicPlus.WithPlayer(guid, 2000, MythicPlus.Handlers.RequestVaultStatus)
end

function Session.OnPlayerLogout(event, player)
    local guid = player:GetGUIDLow()
    if MythicPlus.Rating.Cache[guid] then
        MythicPlus.Rating.SavePlayerRatingCache(guid)
    end
end
