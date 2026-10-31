local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local function RunAfter(delay, callback)
    local timer = CreateFrame("Frame")
    timer.elapsed = 0
    timer:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        if self.elapsed >= delay then
            self:SetScript("OnUpdate", nil)
            callback()
        end
    end)
end

function MythicPlus.Handlers.QueryItemData(_, item1, item2, item3)
    if not MythicHiddenTooltip then
        MythicHiddenTooltip = CreateFrame("GameTooltip", "MythicHiddenTooltip", nil, "GameTooltipTemplate")
        MythicHiddenTooltip:SetOwner(UIParent, "ANCHOR_NONE")
    end

    local function QueryItem(itemId)
        if itemId and itemId > 0 then
            MythicHiddenTooltip:SetHyperlink("item:"..itemId..":0:0:0:0:0:0:0")
            MythicHiddenTooltip:Show()
        end
    end

    if item1 and item1 > 0 then
        QueryItem(item1)
    end

    if item2 and item2 > 0 then
        RunAfter(0.1, function() QueryItem(item2) end)
    end

    if item3 and item3 > 0 then
        RunAfter(0.2, function() QueryItem(item3) end)
    end
end

local function CreateVaultItemButton(index, itemId, tier, subtitle, state)
    local button = CreateFrame("Button", nil, VaultFrame)
    button:SetSize(72, 72)
    button:SetPoint("TOP", subtitle, "BOTTOM", -190 + (index-1)*190, -80)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexture(GetItemIcon(itemId) or "Interface\\Icons\\inv_misc_questionmark")
    button.icon = icon

    local tierLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierLabel:SetPoint("TOP", button, "BOTTOM", 0, -5)
    tierLabel:SetText(MythicGetText("UI", "Tier") .. " " .. (tier or "?"))
    tierLabel:SetFont("Fonts\\FRIZQT__.TTF", 12, "OUTLINE")
    tierLabel:SetTextColor(1, 0.82, 0)
    button.tierLabel = tierLabel

    button:SetScript("OnClick", function(self)
        state.selectedIndex = index

        for j, btn in pairs(state.buttons) do
            if j == index then
                btn.icon:SetDesaturated(false)
                btn.tierLabel:SetTextColor(1, 0.82, 0)
            else
                btn.icon:SetDesaturated(true)
                btn.tierLabel:SetTextColor(0.5, 0.5, 0.5)
            end
        end

        if VaultFrame.confirmButton then
            VaultFrame.confirmButton:Enable()
            VaultFrame.confirmButton:SetText("Confirm Selection")
        end

        if VaultFrame.selectionText then
            local _, itemLink = GetItemInfo(itemId)
            if itemLink then
                VaultFrame.selectionText:SetText("Selected: " .. itemLink)
            else
                VaultFrame.selectionText:SetText("Selected: |cffffffff[Unknown Item]|r")
            end
            VaultFrame.selectionText:SetTextColor(1, 0.82, 0)
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

        local itemLink = select(2, GetItemInfo(itemId))
        if itemLink then
            GameTooltip:SetHyperlink(tostring(itemLink))
        else
            print("Item link not found for item ID:", itemId)
            RunAfter(0.1, function()
                local link = select(2, GetItemInfo(itemId))
                if link and GameTooltip:IsOwned(self) then
                    GameTooltip:SetHyperlink(link)
                end
            end)
        end
        GameTooltip:Show()

        if state.selectedIndex ~= index then
            if not self.highlightTexture then
                self.highlightTexture = self:CreateTexture(nil, "HIGHLIGHT")
                self.highlightTexture:SetTexture("Interface\\Buttons\\ButtonHilight-Square")
                self.highlightTexture:SetAllPoints(self)
                self.highlightTexture:SetBlendMode("ADD")
                self.highlightTexture:SetVertexColor(1, 1, 1, 0.3)
            end
            self.highlightTexture:Show()
        end
    end)
    button:SetScript("OnLeave", function(self)
        GameTooltip_Hide()
        if self.highlightTexture then
            self.highlightTexture:Hide()
        end
    end)
    button:SetScript("OnMouseDown", function(self)
        icon:SetPoint("TOPLEFT", 1, -1)
        icon:SetPoint("BOTTOMRIGHT", 1, -1)
    end)
    button:SetScript("OnMouseUp", function(self)
        icon:SetAllPoints(self)
    end)

    return button
end

function MythicPlus.Handlers.ShowVaultGUI(_, item1, item2, item3, tier1, tier2, tier3)
    AIO.Handle("AIO_Mythic", "QueryItemData", item1, item2, item3)
    if VaultFrame then
        VaultFrame:Hide()
    end

    VaultFrame = CreateFrame("Frame", "MythicVaultFrame", UIParent)
    VaultFrame:SetSize(600, 450)
    VaultFrame:SetPoint("CENTER")
    VaultFrame:SetToplevel(true)

    local vaultBG = VaultFrame:CreateTexture(nil, "BACKGROUND")
    vaultBG:SetTexture("Interface\\MythicPlus\\textures\\VaultFrame")
    vaultBG:SetAllPoints(VaultFrame)
    vaultBG:SetTexCoord(0, 1, 177/1024, (1024-177)/1024)

    local title = VaultFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("TOP", VaultFrame, "TOP", 0, -40)
    title:SetText(MythicGetText("UI", "Mythic+ Vault"))
    title:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    title:SetTextColor(1, 0.82, 0)

    local subtitle = VaultFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    subtitle:SetPoint("TOP", title, "BOTTOM", 0, -2)
    subtitle:SetText(MythicGetText("UI", "Choose item reward"))
    subtitle:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    subtitle:SetTextColor(0.9, 0.9, 0.9)

    local items = {item1, item2, item3}
    local tiers = {tier1, tier2, tier3}
    local state = { selectedIndex = nil, buttons = {} }

    for i = 1, 3 do
        if items[i] and items[i] > 0 then
            state.buttons[i] = CreateVaultItemButton(i, items[i], tiers[i], subtitle, state)
        end
    end

    local selectionText = VaultFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    selectionText:SetPoint("TOP", VaultFrame, "TOP", 0, -300)
    selectionText:SetText(MythicGetText("UI", "No item selected"))
    selectionText:SetTextColor(1, 0.82, 0)
    selectionText:SetFont("Fonts\\FRIZQT__.TTF", 14, "")
    VaultFrame.selectionText = selectionText

    local confirmButton = CreateFrame("Button", nil, VaultFrame, "UIPanelButtonTemplate")
    confirmButton:SetSize(140, 30)
    confirmButton:SetPoint("BOTTOM", VaultFrame, "BOTTOM", 0, 40)
    confirmButton:SetText(MythicGetText("UI", "Select an Item"))
    confirmButton:Disable()
    VaultFrame.confirmButton = confirmButton
    confirmButton:SetScript("OnClick", function(self)
        if state.selectedIndex then
            AIO.Handle("AIO_Mythic", "SelectVaultItem", state.selectedIndex)
            VaultFrame:Hide()
        end
    end)

    local cancelButton = CreateFrame("Button", nil, VaultFrame, "UIPanelButtonTemplate")
    cancelButton:SetSize(100, 30)
    cancelButton:SetPoint("BOTTOMLEFT", VaultFrame, "BOTTOMLEFT", 20, 40)
    cancelButton:SetText(MythicGetText("UI", "Cancel"))
    cancelButton:SetScript("OnClick", function(self)
        VaultFrame:Hide()
    end)
    VaultFrame:SetScript("OnHide", function(self)
        state.selectedIndex = nil
    end)
    VaultFrame:Show()
end

function MythicPlus.Handlers.CloseVaultGUI()
    if VaultFrame then
        VaultFrame:Hide()
    end
end
