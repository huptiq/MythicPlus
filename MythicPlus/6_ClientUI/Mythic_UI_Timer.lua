local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local Handlers = MythicPlus.Handlers
local fmt, floor = string.format, math.floor

local function BuildScoreText(gold, potentialGain, penalty, bonus, deaths, maxDeaths)
    local red   = "|cffff0000"
    local green = "|cff33ff33"
    local reset = "|r"
    return gold..potentialGain..reset.." "..
        gold.."("..reset..
        red.."-"..penalty..reset..
        gold.."/"..reset..
        green.."+"..bonus..reset..
        gold..")"..reset.." "..
        gold..deaths.."/"..maxDeaths..reset
end

local function RefreshScoreLabel(ui)
    ui.scoreLabel:SetText(BuildScoreText("|cffcc9933", ui.potentialGain, ui.penalty, ui.bonus, ui.deaths, ui.maxDeaths))
end

local function CreateProgressBar(timerFrame)
    local progressBar = timerFrame:CreateTexture(nil, "BACKGROUND")
    progressBar:SetTexture("Interface\\MythicPlus\\textures\\MythicBar.blp")
    progressBar:SetSize(0, 128)
    progressBar:SetPoint("LEFT", timerFrame, "LEFT", 0, -10)
    progressBar:SetTexCoord(0, 0, 0, 1)
    progressBar:Hide()

    local function updateProgress(killedBosses, totalBosses)
        if totalBosses == 0 then return end
        local progress = math.min(killedBosses / totalBosses, 1.0)
        local maxWidth = 256
        local currentWidth = maxWidth * progress
        if progress > 0 then
            progressBar:Show()
            progressBar:SetWidth(currentWidth)
            progressBar:SetTexCoord(0, progress, 0, 1)
        else
            progressBar:Hide()
        end
    end

    return progressBar, updateProgress
end

local function CreateAffixIcons(timerFrame, scoreLabel, tier)
    local affixContainer = CreateFrame("Frame", nil, timerFrame)
    affixContainer:SetSize(200, 30)
    affixContainer:SetPoint("BOTTOM", scoreLabel, "TOP", 40, 11)

    local currentAffixes = {}
    if MythicPlusFrame and MythicPlusFrame.currentAffixes then
        currentAffixes = MythicPlusFrame.currentAffixes
    end

    local numAffixes = MythicPlus.GetAffixCount(tier)
    local iconSize = 20
    local iconSpacing = 4
    local totalWidth = (numAffixes * iconSize) + ((numAffixes - 1) * iconSpacing)
    local startX = -totalWidth / 2

    for i = 1, numAffixes do
        local affixName = currentAffixes[i]
        local affix = affixName and MythicPlus.AffixByName[affixName]
        if affix then
            local icon = CreateFrame("Button", nil, affixContainer)
            icon:SetSize(iconSize, iconSize)
            icon:SetPoint("LEFT", affixContainer, "LEFT", startX + (i-1) * (iconSize + iconSpacing) + 30, -5)

            local texture = icon:CreateTexture(nil, "ARTWORK")
            texture:SetAllPoints()
            texture:SetTexture(affix.icon)

            icon:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_TOP")
                GameTooltip:SetText(affixName)
                GameTooltip:Show()
            end)

            icon:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
        end
    end
end

local function CreateBossLabels(timerFrame, goldenFrame, bossNames)
    local bossLabels = {}
    for i, name in ipairs(bossNames) do
        local lbl = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        lbl:SetPoint("TOPLEFT", goldenFrame, "BOTTOMLEFT", 20, 10 - (i-1)*16)
        lbl:SetText(fmt("%d/%d %s", 0, 1, name))
        lbl:SetTextColor(1, 0.82, 0)
        lbl.bossName = name
        bossLabels[i] = lbl
    end
    return bossLabels
end

local function CreateEnemyForces(timerFrame, goldenFrame, bossCount)
    local enemyLabel = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    enemyLabel:SetPoint("TOPLEFT", goldenFrame, "BOTTOMLEFT", 20, 10 - bossCount*16)
    enemyLabel:SetText("0/1 " .. MythicGetText("UI", "Enemy Forces"))
    enemyLabel:SetTextColor(1, 0.82, 0)

    local enemyProgressFrame = CreateFrame("StatusBar", nil, timerFrame)
    enemyProgressFrame:SetSize(200, 12)
    enemyProgressFrame:SetPoint("TOPLEFT", enemyLabel, "BOTTOMLEFT", 0, -10)
    enemyProgressFrame:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    enemyProgressFrame:SetStatusBarColor(0.2, 0.8, 0.2)
    enemyProgressFrame:SetMinMaxValues(0, 100)
    enemyProgressFrame:SetValue(0)

    local enemyProgressBorder = CreateFrame("Frame", nil, timerFrame, BackdropTemplateMixin and "BackdropTemplate")
    enemyProgressBorder:SetAllPoints(enemyProgressFrame)
    enemyProgressBorder:SetBackdrop({
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 8,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    enemyProgressBorder:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    local enemyPercentText = enemyProgressFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    enemyPercentText:SetPoint("CENTER", enemyProgressFrame, "CENTER")
    enemyPercentText:SetText("0%")

    return enemyLabel, enemyProgressFrame, enemyPercentText
end

function Handlers.StartMythicTimerGUI(_, mapId, tier, duration, bossNames, potentialGain, enemiesRequired)
    potentialGain = tonumber(potentialGain) or 0
    enemiesRequired = tonumber(enemiesRequired) or 50
    if type(bossNames) ~= "table" then bossNames = {} end
    local maxDeaths = MythicPlus.GetDeathLimit(tier)
    WatchFrame:Hide(); WATCHFRAME_COLLAPSED = true

    local baseHeight = 140 + #bossNames * 18
    local frameHeight = (enemiesRequired > 0) and (baseHeight + 28) or baseHeight

    local timerFrame = CreateFrame("Frame", nil, UIParent)
    timerFrame:SetSize(320, frameHeight)
    timerFrame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -120)
    timerFrame:SetMovable(true)
    timerFrame:EnableMouse(true)
    timerFrame:RegisterForDrag("LeftButton")
    timerFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    timerFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

    local progressBar, updateProgress = CreateProgressBar(timerFrame)

    local goldenFrame = timerFrame:CreateTexture(nil, "ARTWORK")
    goldenFrame:SetTexture("Interface\\MythicPlus\\textures\\MythicFrame.blp")
    goldenFrame:SetSize(256, 128)
    goldenFrame:SetPoint("LEFT", timerFrame, "LEFT", 0, -10)
    goldenFrame:SetTexCoord(0, 1, 0, 1)

    local dungeonText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeonText:SetPoint("TOP", goldenFrame, "TOP", 0, -12)
    dungeonText:SetFont("Fonts\\FRIZQT__.TTF", 16, "OUTLINE")
    dungeonText:SetText(fmt("|cffFFD700%s|r", MythicGetDungeonName(mapId)))

    local tierText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tierText:SetPoint("TOP", goldenFrame, "LEFT", 50, 26)
    tierText:SetFont("Fonts\\FRIZQT__.TTF", 16, "")
    tierText:SetText(fmt("|cffFFD700Level %d|r", tier))

    local timerText = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    timerText:SetPoint("CENTER", goldenFrame, "LEFT", 48, -6)
    timerText:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    timerText:SetText(fmt("%02d:%02d", floor(duration/60), duration%60))

    local scoreLabel = timerFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scoreLabel:SetPoint("BOTTOM", goldenFrame, "BOTTOM", 60, 50)
    scoreLabel:SetText(BuildScoreText("|cffFFD700", potentialGain, 0, 0, 0, maxDeaths))

    CreateAffixIcons(timerFrame, scoreLabel, tier)

    local bossLabels = CreateBossLabels(timerFrame, goldenFrame, bossNames)

    local enemyLabel, enemyProgressFrame, enemyPercentText
    if enemiesRequired > 0 then
        enemyLabel, enemyProgressFrame, enemyPercentText = CreateEnemyForces(timerFrame, goldenFrame, #bossNames)
    end

    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, dt)
        if self.stopped then return end
        elapsed = elapsed + dt
        local left = duration - elapsed
        if left < 0 then left = 0 end
        local m,s = floor(left/60), floor(left%60)
        local ratio = left/duration
        local color = "|cff00ff00"
        if ratio < 0.3 then color = "|cffff0000"
        elseif ratio < 0.6 then color = "|cffffff00" end
        timerText:SetText(fmt("%s%02d:%02d|r", color, m, s))
    end)

    timerFrame:Show()

    MythicBossTimerUI = {
        frame = timerFrame,
        timerText = timerText,
        scoreLabel = scoreLabel,
        labels = bossLabels,
        progressBar = progressBar,
        updateProgress = updateProgress,
        totalBosses = #bossNames,
        killedBosses = 0,
        potentialGain = potentialGain,
        penalty = 0,
        bonus = 0,
        deaths = 0,
        maxDeaths = maxDeaths,
        enemyLabel = enemyLabel,
        enemyProgressFrame = enemyProgressFrame,
        enemyPercentText = enemyPercentText,
        enemiesRequired = enemiesRequired,
        enemiesCurrent = 0
    }
end

function Handlers.UpdateMythicScore(_, newPenalty, newDeaths)
    local ui = MythicBossTimerUI
    if not ui or not ui.scoreLabel then return end
    ui.penalty = tonumber(newPenalty) or ui.penalty
    ui.deaths  = tonumber(newDeaths)   or ui.deaths
    RefreshScoreLabel(ui)
end

function Handlers.FinalizeMythicScore(_, finalPenalty, finalDeaths, finalBonus)
    local ui = MythicBossTimerUI
    if not ui or not ui.scoreLabel then return end
    ui.penalty = tonumber(finalPenalty) or ui.penalty
    ui.deaths  = tonumber(finalDeaths)  or ui.deaths
    ui.bonus   = tonumber(finalBonus)   or ui.bonus
    RefreshScoreLabel(ui)
end

function Handlers.MarkBossKilled(_, mapId, bossIndex)
    local ui = MythicBossTimerUI
    if not ui or not ui.labels then return end
    local lbl = ui.labels[bossIndex]
    if lbl and lbl.bossName then
        lbl:SetText(fmt("|cff26c426%d/%d %s|r", 1, 1, lbl.bossName))
        ui.killedBosses = ui.killedBosses + 1
        if ui.updateProgress then
            ui.updateProgress(ui.killedBosses, ui.totalBosses)
        end
    end
end

function Handlers.UpdateEnemyForces(_, current, required, percentage, completed)
    local ui = MythicBossTimerUI
    if not ui or not ui.enemyLabel then return end
    ui.enemiesCurrent = current
    ui.enemiesRequired = required
    local completedText = completed and "1" or "0"
    ui.enemyLabel:SetText(fmt("%s/1 %s", completedText, MythicGetText("UI", "Enemy Forces")))
    ui.enemyProgressFrame:SetValue(percentage)
    ui.enemyPercentText:SetText(fmt("%.0f%%", percentage))
    if completed then
        ui.enemyLabel:SetTextColor(0.15, 0.76, 0.15)
    else
        ui.enemyLabel:SetTextColor(1, 0.82, 0)
    end
end

function Handlers.StopMythicTimerGUI(_, remaining)
    local ui = MythicBossTimerUI
    if ui and ui.timerText then
        if type(remaining) == "number" then
            local m, s = floor(remaining/60), floor(remaining%60)
            ui.timerText:SetText(fmt("|cffffff00%02d:%02d|r", m, s))
        end
        ui.frame.stopped = true
    end
end

function Handlers.KillMythicTimerGUI()
    WatchFrame:Show(); WATCHFRAME_COLLAPSED = nil
    if MythicBossTimerUI and MythicBossTimerUI.frame then
        MythicBossTimerUI.frame.stopped = true
        MythicBossTimerUI.frame:Hide()
        MythicBossTimerUI.frame:SetScript("OnUpdate", nil)
        MythicBossTimerUI.frame:SetParent(nil)
        MythicBossTimerUI.frame = nil
    end
    MythicBossTimerUI = nil
end

function Handlers.StartOvertimeMode()
    if MythicBossTimerUI and MythicBossTimerUI.timerText then
        MythicBossTimerUI.timerText:SetText("|cffff0000OVERTIME|r")
        MythicBossTimerUI.frame.stopped = true
    end
end

function Handlers.RestoreRunState(_, runState)
    if not runState or not runState.active then
        MythicPlusCharRunState = MythicPlus.NewRunState()
        return
    end

    MythicPlusCharRunState = runState
    MythicPlusCharRunState.saveTime = GetTime()

    Handlers.StartMythicTimerGUI(nil, runState.mapId, runState.tier, runState.duration - runState.elapsed, runState.bossNames, runState.potentialGain, runState.enemyForces.required)

    if MythicBossTimerUI then
        MythicBossTimerUI.deaths = runState.deaths
        MythicBossTimerUI.penalty = runState.penalty
        MythicBossTimerUI.maxDeaths = runState.maxDeaths

        Handlers.UpdateMythicScore(nil, runState.penalty, runState.deaths)

        for _, bossIndex in ipairs(runState.killedBosses) do
            Handlers.MarkBossKilled(nil, runState.mapId, bossIndex)
        end

        if runState.enemyForces then
            Handlers.UpdateEnemyForces(nil, runState.enemyForces.current, runState.enemyForces.required, runState.enemyForces.percentage, runState.enemyForces.completed)
        end

        if runState.overtime then
            Handlers.StartOvertimeMode()
        end
    end
end

function Handlers.ClearRunState()
    MythicPlusCharRunState = MythicPlus.NewRunState()
end
