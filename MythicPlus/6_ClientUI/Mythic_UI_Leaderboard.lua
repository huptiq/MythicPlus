local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local frame = MythicPlusFrame

local banner, title = MythicPlus.CreateBannerTitle(frame, MythicGetText("UI", "Leaderboard"), 0)
frame.leaderboardBanner = banner
frame.leaderboardTitle = title
banner:Hide()
title:Hide()

frame.podiums = {}
local podiumSpecs = {
    { height = 60, color = {0.8, 0.8, 0.8,}, x = -140 },
    { height = 90, color = {0.95, 0.84, 0.0}, x = 0 },
    { height = 40, color = {0.72, 0.45, 0.2}, x = 140 },
}

for i, spec in ipairs(podiumSpecs) do
    local podium = CreateFrame("Frame", nil, frame)
    podium:SetSize(135, spec.height)
    podium:SetPoint("BOTTOM", banner, "TOP", spec.x + 0, -200)

    local bg = podium:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(spec.color[1], spec.color[2], spec.color[3], 1)

    local name = podium:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    name:SetPoint("BOTTOM", podium, "TOP", 0, 4)
    name:SetText("—")
    podium.name = name

    local score = podium:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    score:SetPoint("CENTER", podium, "CENTER")
    score:SetText("0")
    podium.score = score

    podium:Hide()
    frame.podiums[i] = podium
end

frame.leaderboardButtons = {}
local lbButtonSize = 53
local lbSpacingX = 20
local lbSpacingY = 15
local lbCols = 6
local lbStartX = -(lbCols * lbButtonSize + (lbCols - 1) * lbSpacingX) / 2 + 166 + podiumSpecs[1].x
local lbTopPadding = 10
local lbRows = math.ceil(#MythicPlus.DungeonOrder / lbCols)
local lbContentHeight = lbTopPadding + lbRows * lbButtonSize + (lbRows - 1) * lbSpacingY

local lbArea, lbContent = MythicPlus.CreateScrollArea("MythicPlusLeaderboardScroll", banner, "TOP", -200 - lbTopPadding, lbContentHeight, lbButtonSize + lbSpacingY)
frame.leaderboardArea = lbArea
lbArea:Hide()

for i, mapId in ipairs(MythicPlus.DungeonOrder) do
    local button = CreateFrame("Button", nil, lbContent)
    button:SetSize(lbButtonSize, lbButtonSize)

    local row = math.floor((i - 1) / lbCols)
    local col = (i - 1) % lbCols
    button:SetPoint(
        "TOP",
        lbContent,
        "TOP",
        lbStartX + col * (lbButtonSize + lbSpacingX),
        -lbTopPadding - row * (lbButtonSize + lbSpacingY)
    )

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(MythicPlus.Dungeons[mapId].icon or "Interface\\Icons\\inv_misc_questionmark")

    frame.leaderboardButtons[i] = button
end

local elements = { lbArea }
for _, podium in ipairs(frame.podiums) do
    table.insert(elements, podium)
end

MythicPlus.RegisterTab(3, "Leaderboard", banner, title, elements, function()
    AIO.Handle("AIO_Mythic", "RequestLeaderboard")
end)

local function ShowDungeonTooltip(button, mapId, top)
    GameTooltip:SetOwner(button, "ANCHOR_RIGHT")
    GameTooltip:SetText(MythicGetDungeonName(mapId))

    if top then
        GameTooltip:AddLine(MythicGetText("UI", "Highest Score:"), 1, 1, 0)
        GameTooltip:AddLine("  " .. top.name .. ": " .. top.score, 1, 1, 1)
        if top.highestKey and top.highestKey > 0 then
            GameTooltip:AddLine(MythicGetText("UI", "Highest Key +%d by:"):format(top.highestKey), 1, 1, 0)
            if top.keyHolderNames and #top.keyHolderNames > 0 then
                for _, memberName in ipairs(top.keyHolderNames) do
                    GameTooltip:AddLine("  " .. memberName, 0.8, 1, 0.8)
                end
            else
                GameTooltip:AddLine("  " .. MythicGetText("UI", "Unknown"), 0.8, 1, 0.8)
            end
        else
            GameTooltip:AddLine(MythicGetText("UI", "Highest Key: None completed in time"), 0.7, 0.7, 0.7)
        end
    else
        GameTooltip:AddLine(MythicGetText("UI", "No records available"), 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

function MythicPlus.Handlers.ReceiveLeaderboard(_, topThree, dungeonTop)
    local visualToRank = {2, 1, 3}
    for i = 1, 3 do
        local entry = topThree[visualToRank[i]]
        local podium = frame.podiums[i]

        if entry then
            podium.name:SetText(entry.name)
            podium.score:SetText(string.format("%.2f", entry.points))
        else
            podium.name:SetText("—")
            podium.score:SetText("0")
        end
        podium.name:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE, THICK")
        podium.score:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    end

    for i, mapId in ipairs(MythicPlus.DungeonOrder) do
        local top = dungeonTop[tostring(mapId)]
        local button = frame.leaderboardButtons[i]
        if button then
            button:SetScript("OnEnter", function(self)
                ShowDungeonTooltip(self, mapId, top)
            end)
            button:SetScript("OnLeave", GameTooltip_Hide)
        end
    end
end
