local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local frame = MythicPlusFrame

local banner, title = MythicPlus.CreateBannerTitle(frame, MythicGetText("UI", "Score"), 0)
frame.scoreBanner = banner
frame.scoreTitle = title
banner:Hide()
title:Hide()

local scoreText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
scoreText:SetPoint("TOP", banner, "BOTTOM", 0, -10)
scoreText:SetText("Score: Loading...")
frame.scoreText = scoreText
scoreText:Hide()

frame.scoreButtons = {}
local scoreButtonSize = 50
local scoreCols = 4
local scoreButtonSpacingX = 60
local scoreButtonSpacingY = 26
local scoreStartX = -(scoreCols * scoreButtonSize + (scoreCols - 1) * scoreButtonSpacingX) / 2 + 25
local scoreTopPadding = 10
local scoreLabelHeight = 26
local scoreRows = math.ceil(#MythicPlus.DungeonOrder / scoreCols)
local scoreContentHeight = scoreTopPadding + scoreRows * scoreButtonSize + (scoreRows - 1) * scoreButtonSpacingY + scoreLabelHeight

local scoreArea, scoreContent = MythicPlus.CreateScrollArea("MythicPlusScoreScroll", scoreText, "BOTTOM", -10, scoreContentHeight, scoreButtonSize + scoreButtonSpacingY)
frame.scoreArea = scoreArea
scoreArea:Hide()

for i, mapId in ipairs(MythicPlus.DungeonOrder) do
    local button = CreateFrame("Button", nil, scoreContent)
    button:SetSize(scoreButtonSize, scoreButtonSize)

    local row = math.floor((i - 1) / scoreCols)
    local col = (i - 1) % scoreCols
    button:SetPoint(
        "TOP",
        scoreContent,
        "TOP",
        scoreStartX + col * (scoreButtonSize + scoreButtonSpacingX),
        -scoreTopPadding - row * (scoreButtonSize + scoreButtonSpacingY)
    )

    local tex = button:CreateTexture(nil, "BACKGROUND")
    tex:SetAllPoints()
    tex:SetTexture(MythicPlus.Dungeons[mapId].icon or "Interface\\Icons\\inv_misc_questionmark")

    local scoreLabel = button:CreateFontString(nil, "OVERLAY")
    scoreLabel:SetPoint("CENTER", button, "CENTER", 0, -15)
    scoreLabel:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE, THICK")
    scoreLabel:SetText("0")
    button.scoreLabel = scoreLabel

    local nameLabel = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    nameLabel:SetPoint("TOP", button, "BOTTOM", 0, 0)
    nameLabel:SetWidth(scoreButtonSize + 40)
    nameLabel:SetFont("Fonts\\FRIZQT__.TTF", 10, "OUTLINE")
    nameLabel:SetWordWrap(true)
    nameLabel:SetText(MythicGetDungeonName(mapId))
    nameLabel:SetJustifyH("CENTER")
    nameLabel:SetJustifyV("TOP")
    button.nameLabel = nameLabel

    frame.scoreButtons[i] = button
end

local function UpdateDungeonNames()
    for i, mapId in ipairs(MythicPlus.DungeonOrder) do
        frame.scoreButtons[i].nameLabel:SetText(MythicGetDungeonName(mapId))
    end
end

MythicPlus.RegisterTab(2, "Score", banner, title, { scoreText, scoreArea }, function()
    AIO.Handle("AIO_Mythic", "RequestTotalPoints")
end)

MythicPlus.OnLocalize(UpdateDungeonNames)

function MythicPlus.Handlers.ReceiveTotalPoints(_, totalPoints, dungeonScores)
    if not frame.scoreText then return end
    frame.scoreText:SetText(MythicGetText("UI", "Total Score:") .. " " .. string.format("%.2f", totalPoints or 0))
    for i, mapId in ipairs(MythicPlus.DungeonOrder) do
        local button = frame.scoreButtons[i]
        if button and button.scoreLabel then
            local score = dungeonScores and dungeonScores[tostring(mapId)] or 0
            button.scoreLabel:SetText(tostring(score))
        end
    end
    UpdateDungeonNames()
end
