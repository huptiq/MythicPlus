local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local frame = MythicPlusFrame

local banner, title = MythicPlus.CreateBannerTitle(frame, MythicGetText("UI", "Overview"), 0)
frame.overviewBanner = banner
frame.overviewTitle = title

local affixText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
affixText:SetPoint("TOP", banner, "BOTTOM", 0, -10)
affixText:SetJustifyH("CENTER")
affixText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
affixText:SetText(MythicGetText("UI", "This week's affixes:") .. " Loading...")
frame.affixText = affixText

local function GetAffixColor(name)
    local affix = MythicPlus.AffixByName[name]
    return affix and affix.color or "|cffffffff"
end

local function IsActiveAffix(name)
    local current = frame.currentAffixes
    return current and (name == current[1] or name == current[2] or name == current[3])
end

local function UpdateAffixLabels()
    for _, button in ipairs(frame.affixButtons) do
        button.label:SetText((IsActiveAffix(button.affixName) and "|cff00ff00" or "") .. MythicGetText("UI", button.affixName))
    end
end

frame.affixButtons = {}
local buttonSize = 80
local buttonSpacing = 30
local labelHeight = 18
local topPadding = 30
local columns = 4
local totalWidth = columns * buttonSize + (columns - 1) * buttonSpacing
local startX = -(totalWidth / 2) + 40
local rows = math.ceil(#MythicPlus.Affixes / columns)
local contentHeight = topPadding + rows * buttonSize + (rows - 1) * buttonSpacing + labelHeight

local affixArea, affixContent = MythicPlus.CreateScrollArea("MythicPlusAffixScroll", affixText, "BOTTOM", -10, contentHeight, buttonSize + buttonSpacing)
frame.affixArea = affixArea

for i, affix in ipairs(MythicPlus.Affixes) do
    local name = affix.name
    local button = CreateFrame("Button", nil, affixContent)
    button:SetSize(buttonSize, buttonSize)

    local row = math.floor((i - 1) / columns)
    local col = (i - 1) % columns
    button:SetPoint(
        "TOP",
        affixContent,
        "TOP",
        startX + col * (buttonSize + buttonSpacing),
        -topPadding - row * (buttonSize + buttonSpacing)
    )

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetAllPoints()
    icon:SetTexture(affix.icon or "Interface\\Icons\\spell_nature_polymorph")

    local label = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", button, "BOTTOM", 0, -2)
    label:SetFont("Fonts\\FRIZQT__.TTF", 12, "")
    label:SetText(name)

    button.affixName = name
    button.label = label

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(GetAffixColor(name) .. MythicGetText("UI", name) .. "|r")
        GameTooltip:AddLine(MythicGetText("UI", name .. " Description") or "", 1, 1, 1, true)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    frame.affixButtons[i] = button
end

MythicPlus.RegisterTab(1, "Overview", banner, title, { affixText, affixArea }, function()
    AIO.Handle("AIO_Mythic", "RequestWeeklyAffixes")
end)

MythicPlus.OnLocalize(UpdateAffixLabels)

function MythicPlus.Handlers.ReceiveWeeklyAffixes(_, affix1, affix2, affix3)
    local function colorize(name)
        return GetAffixColor(name) .. MythicGetText("UI", name) .. "|r"
    end

    frame.affixText:SetText(MythicGetText("UI", "This week's affixes:") .. " " ..
        colorize(affix1) .. ", " ..
        colorize(affix2) .. ", " ..
        colorize(affix3))

    frame.currentAffixes = {affix1, affix2, affix3}
    UpdateAffixLabels()
end
