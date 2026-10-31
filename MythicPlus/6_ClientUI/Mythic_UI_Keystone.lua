local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local lastKeystoneLink = nil
local lastMapName = nil
local lastTierLevel = nil

local function IsKeystoneName(name)
    return name and (string.find(name, "Mythic Keystone") or string.find(name, MythicGetText("Items", "Mythic Keystone")))
end

function MythicPlus.Handlers.ReceiveMapNameAndTier(_, mapName, tier)
    for _, dungeon in ipairs(MythicPlus.DungeonList) do
        if dungeon.name == mapName then
            mapName = MythicGetText("Dungeons", dungeon.name)
            break
        end
    end

    lastMapName = mapName
    lastTierLevel = tier

    if GameTooltip:IsShown() then
        local name, link = GameTooltip:GetItem()
        if link and IsKeystoneName(name) then
            GameTooltip:Hide()
            GameTooltip:SetOwner(UIParent, "ANCHOR_CURSOR")
            GameTooltip:SetHyperlink(link)
        end
    end
end

local function OnTooltipSetItem(tooltip)
    local name, link = tooltip:GetItem()
    if not IsKeystoneName(name) then
        return
    end

    if link ~= lastKeystoneLink then
        lastKeystoneLink = link
        lastMapName = "Loading..."
        lastTierLevel = "Loading..."
        AIO.Handle("AIO_Mythic", "RequestMapNameAndTier")
    end
    local line = _G[tooltip:GetName() .. "TextLeft2"]
    if line then
        local tierText = lastTierLevel and lastTierLevel ~= "Loading..." and ("+" .. lastTierLevel) or ""
        line:SetText("|cffa335ee" .. MythicGetText("UI", "Mythic") .. tierText .. " |r" .. (lastMapName or "Loading..."))
        line:Show()
        tooltip:Show()
    end
end

GameTooltip:HookScript("OnTooltipSetItem", OnTooltipSetItem)
