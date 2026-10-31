local Config = MythicPlus.Config
local Progress = MythicPlus.Progress
local Keystone = MythicPlus.Keystone
local Run = MythicPlus.Run
local Session = MythicPlus.Session

MythicPlus.Names.LoadBossNames()
MythicPlus.Affix.LoadOrRollWeeklyAffixes()
MythicPlus.Loot.LoadMythicLootTable()
MythicPlus.Vault.LoadVaultLootTable()

RegisterCreatureGossipEvent(Config.PedestalNpc, 1, MythicPlus.Pedestal.OnGossipHello)
RegisterCreatureGossipEvent(Config.PedestalNpc, 2, MythicPlus.Pedestal.OnGossipSelect)
RegisterPlayerEvent(7, Progress.MythicBossKillCheck)
RegisterPlayerEvent(7, Keystone.HeroicEndbossKeyReward)
RegisterPlayerEvent(7, Progress.MythicEnemyKillCheck)
RegisterPlayerEvent(7, MythicPlus.Affix.OnCreatureKilled)
RegisterPlayerEvent(8, Run.MythicPlayerDeath)
RegisterPlayerEvent(53, Keystone.BindKeystoneToDungeon)
RegisterPlayerEvent(28, Run.LeaveDungeonMap)
RegisterPlayerEvent(3, Session.OnPlayerLogin)
RegisterPlayerEvent(4, Session.OnPlayerLogout)

for _, dungeon in ipairs(MythicPlus.DungeonList) do
    if dungeon.completeOnEvade then
        RegisterCreatureEvent(dungeon.completeOnEvade.entry, 1, MythicPlus.Encounters.CheckEvadeBoss)
    end
end

RegisterGameObjectEvent(Config.VaultGameObject, 14, MythicPlus.Vault.WeeklyVaultInteract)
MythicPlus.Vault.CheckAndProcessVaultOnStartup()
