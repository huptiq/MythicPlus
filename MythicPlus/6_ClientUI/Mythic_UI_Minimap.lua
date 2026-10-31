local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local mythicMiniButton = CreateFrame("Button", "MythicPlusMiniButton", Minimap)
mythicMiniButton:SetSize(24, 24)
mythicMiniButton:SetFrameStrata("MEDIUM")
mythicMiniButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

mythicMiniButton:SetNormalTexture("Interface\\AddOns\\Blizzard_AchievementUI\\UI-Achievement-MinimapButton")
mythicMiniButton:SetPushedTexture("Interface\\AddOns\\Blizzard_AchievementUI\\UI-Achievement-MinimapButton-Down")

local icon = mythicMiniButton:CreateTexture(nil, "ARTWORK")
icon:SetTexture("Interface\\Icons\\achievement_bg_wineos_underxminutes")
icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
icon:SetAllPoints(mythicMiniButton)

local border = mythicMiniButton:CreateTexture(nil, "OVERLAY")
border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
border:SetSize(64, 64)
border:SetPoint("CENTER", mythicMiniButton, "CENTER", 12, -12)

mythicMiniButton:SetPoint("TOPLEFT", Minimap, "BOTTOMLEFT", -20, 70)

mythicMiniButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:SetText(MythicGetText("UI", "Mythic+"))
    if self.hasVaultLoot then
        GameTooltip:AddLine(MythicGetText("UI", "There is loot in your Vault in Dalaran City"), 1, 1, 0)
    end
    GameTooltip:Show()
end)
mythicMiniButton:SetScript("OnLeave", GameTooltip_Hide)

mythicMiniButton:SetScript("OnClick", function()
    if MythicPlusFrame:IsShown() then
        PlaySound("igCharacterInfoClose")
        MythicPlusFrame:Hide()
    else
        PlaySound("igCharacterInfoOpen")
        MythicPlusFrame:Show()
    end
end)

function MythicPlus.Handlers.UpdateVaultStatus(_, hasLoot)
    mythicMiniButton.hasVaultLoot = hasLoot and true or false
    if hasLoot then
        if not mythicMiniButton.glowTexture then
            mythicMiniButton.glowTexture = mythicMiniButton:CreateTexture(nil, "OVERLAY")
            mythicMiniButton.glowTexture:SetTexture("Interface\\SpellActivationOverlay\\IconAlert")
            mythicMiniButton.glowTexture:SetSize(48, 48)
            mythicMiniButton.glowTexture:SetPoint("CENTER")
            mythicMiniButton.glowTexture:SetBlendMode("ADD")
        end
        mythicMiniButton.glowTexture:Show()
    elseif mythicMiniButton.glowTexture then
        mythicMiniButton.glowTexture:Hide()
    end
end
