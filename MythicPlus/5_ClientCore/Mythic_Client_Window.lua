local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

MythicPlusFrame = CreateFrame("Frame", "MythicPlusFrame", UIParent)
local frame = MythicPlusFrame

frame:SetSize(720, 480)
frame:SetPoint("CENTER", UIParent, "CENTER", 270, 270)
frame:SetToplevel(true)
frame:SetClampedToScreen(true)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnHide", function(self)PlaySound("igCharacterInfoClose") self:StopMovingOrSizing() end)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)

for _, region in ipairs({frame:GetRegions()}) do
    if region:GetObjectType() == "Texture" then
        region:Hide()
    end
end

local paperBG = frame:CreateTexture(nil, "BACKGROUND")
paperBG:SetTexture("Interface\\MythicPlus\\textures\\Paper")
paperBG:SetAllPoints(frame)
paperBG:SetTexCoord(0, 1, 75/1024, (1024-75)/1024)

local borderSize = 167
local borderCornerTexCoordW = 167/256
local borderCornerTexCoordH = 168/256
local borderExpansion = math.floor(borderSize * 0.1)

local function CreateCorner(point, x, y, left, right, top, bottom)
    local corner = frame:CreateTexture(nil, "ARTWORK")
    corner:SetTexture("Interface\\MythicPlus\\textures\\Border")
    corner:SetSize(borderSize, borderSize)
    corner:SetPoint(point, frame, point, x, y)
    corner:SetTexCoord(left, right, top, bottom)
    return corner
end

local topLeftCorner = CreateCorner("TOPLEFT", -borderExpansion, borderExpansion, 0, borderCornerTexCoordW, 0, borderCornerTexCoordH)
local topRightCorner = CreateCorner("TOPRIGHT", borderExpansion, borderExpansion, borderCornerTexCoordW, 0, 0, borderCornerTexCoordH)
local bottomLeftCorner = CreateCorner("BOTTOMLEFT", -borderExpansion, -borderExpansion, 0, borderCornerTexCoordW, borderCornerTexCoordH, 0)
local bottomRightCorner = CreateCorner("BOTTOMRIGHT", borderExpansion, -borderExpansion, borderCornerTexCoordW, 0, borderCornerTexCoordH, 0)

local horizontalTexCoord = math.min(1.0, (720 + (borderExpansion * 2) - (borderSize * 2)) / 1024)
local verticalTexCoord = math.min(1.0, (480 + (borderExpansion * 2) - (borderSize * 2)) / 1024)

local topBorder = frame:CreateTexture(nil, "ARTWORK")
topBorder:SetTexture("Interface\\MythicPlus\\textures\\Border_Top")
topBorder:SetHeight(32)
topBorder:SetPoint("TOPLEFT", topLeftCorner, "TOPRIGHT", 0, 0)
topBorder:SetPoint("TOPRIGHT", topRightCorner, "TOPLEFT", 0, 0)
topBorder:SetTexCoord(0, horizontalTexCoord, 0, 1)

local bottomBorder = frame:CreateTexture(nil, "ARTWORK")
bottomBorder:SetTexture("Interface\\MythicPlus\\textures\\Border_Bottom")
bottomBorder:SetHeight(32)
bottomBorder:SetPoint("BOTTOMLEFT", bottomLeftCorner, "BOTTOMRIGHT", 0, 0)
bottomBorder:SetPoint("BOTTOMRIGHT", bottomRightCorner, "BOTTOMLEFT", 0, 0)
bottomBorder:SetTexCoord(0, horizontalTexCoord, 0, 1)

local leftBorder = frame:CreateTexture(nil, "ARTWORK")
leftBorder:SetTexture("Interface\\MythicPlus\\textures\\Border_Left")
leftBorder:SetWidth(32)
leftBorder:SetPoint("TOPLEFT", topLeftCorner, "BOTTOMLEFT", -1, 0)
leftBorder:SetPoint("BOTTOMLEFT", bottomLeftCorner, "TOPLEFT", -1, 0)
leftBorder:SetTexCoord(0, 1, 0, verticalTexCoord)

local rightBorder = frame:CreateTexture(nil, "ARTWORK")
rightBorder:SetTexture("Interface\\MythicPlus\\textures\\Border_Right")
rightBorder:SetWidth(32)
rightBorder:SetPoint("TOPRIGHT", topRightCorner, "BOTTOMRIGHT", 1, 0)
rightBorder:SetPoint("BOTTOMRIGHT", bottomRightCorner, "TOPRIGHT", 1, 0)
rightBorder:SetTexCoord(0, 1, 0, verticalTexCoord)

table.insert(UISpecialFrames, "MythicPlusFrame")
frame:Hide()

local tabBackground = CreateFrame("Frame", nil, frame)
tabBackground:SetSize(120, 400)
tabBackground:SetPoint("TOPLEFT", frame, "TOPLEFT", 20, -20)

MythicPlus.Tabs = {}

local function CreateStyledTabButton(parent, text, index, onClick)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(100, 32)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", 10, -20 - ((index - 1) * 35))
    button:SetText(text)
    button:SetNormalFontObject("GameFontNormal")
    button:GetNormalTexture():SetVertexColor(0.8, 0.2, 0.2, 1)
    button:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3, 1)
    button:GetPushedTexture():SetVertexColor(0.6, 0.1, 0.1, 1)
    button.isSelected = false
    button:SetScript("OnClick", function()
        onClick(index)
    end)

    return button
end

function MythicPlus.CreateBannerTitle(parent, text, anchorPoint)
    local banner = parent:CreateTexture(nil, "OVERLAY")
    banner:SetTexture("Interface\\MythicPlus\\textures\\Banner")
    banner:SetSize(256, 64)
    banner:SetPoint("TOP", parent, "TOP", 40, anchorPoint)

    local title = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    title:SetPoint("CENTER", banner, "CENTER", 0, 0)
    title:SetText(text)
    title:SetFont("Fonts\\FRIZQT__.TTF", 20, "OUTLINE")
    title:SetTextColor(1, 1, 1)

    return banner, title
end

local SCROLL_AREA_WIDTH = 470
local SCROLL_AREA_BOTTOM = 40

function MythicPlus.CreateScrollArea(name, anchor, anchorPoint, offsetY, contentHeight, step)
    local scrollFrame = CreateFrame("ScrollFrame", name, frame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetWidth(SCROLL_AREA_WIDTH)
    scrollFrame:SetPoint("TOP", anchor, anchorPoint, 0, offsetY)
    scrollFrame:SetPoint("BOTTOM", frame, "BOTTOM", 40, SCROLL_AREA_BOTTOM)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetWidth(SCROLL_AREA_WIDTH)
    content:SetHeight(contentHeight)
    scrollFrame:SetScrollChild(content)

    local scrollBar = _G[name .. "ScrollBar"]

    local function Update()
        local range = math.max(0, content:GetHeight() - scrollFrame:GetHeight())
        if range > 0 then
            scrollBar:SetMinMaxValues(0, range)
            scrollBar:Show()
            scrollFrame:EnableMouseWheel(true)
        else
            scrollBar:SetMinMaxValues(0, 0)
            scrollBar:SetValue(0)
            scrollBar:Hide()
            scrollFrame:SetVerticalScroll(0)
            scrollFrame:EnableMouseWheel(false)
        end
    end

    scrollFrame:SetScript("OnScrollRangeChanged", Update)
    scrollFrame:SetScript("OnSizeChanged", Update)
    scrollFrame:SetScript("OnShow", Update)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        scrollBar:SetValue(scrollBar:GetValue() - delta * step)
    end)

    scrollFrame.content = content
    scrollFrame.Update = Update
    Update()
    return scrollFrame, content
end

function MythicPlus.SetActiveTab(index)
    PlaySound("igMainMenuOptionCheckBoxOn")
    frame.currentTab = index

    for i, tab in ipairs(MythicPlus.Tabs) do
        local button = tab.button
        local isActive = i == index
        button.isSelected = isActive
        if isActive then
            button:GetNormalTexture():SetVertexColor(1, 0.4, 0.4, 1)
            button:GetHighlightTexture():SetVertexColor(1, 0.5, 0.5, 1)
        else
            button:GetNormalTexture():SetVertexColor(0.8, 0.2, 0.2, 1)
            button:GetHighlightTexture():SetVertexColor(1, 0.3, 0.3, 1)
        end

        for _, element in ipairs(tab.elements) do
            if isActive then
                element:Show()
            else
                element:Hide()
            end
        end
    end

    local activeTab = MythicPlus.Tabs[index]
    if activeTab and activeTab.onShow then
        activeTab.onShow()
    end
end

function MythicPlus.RegisterTab(index, key, banner, title, elements, onShow)
    local tab = {
        key = key,
        banner = banner,
        title = title,
        elements = { banner, title },
        onShow = onShow
    }
    for _, element in ipairs(elements) do
        table.insert(tab.elements, element)
    end
    tab.button = CreateStyledTabButton(tabBackground, MythicGetText("UI", key), index, MythicPlus.SetActiveTab)
    MythicPlus.Tabs[index] = tab
    return tab
end

MythicPlus.OnLocalize(function()
    for _, tab in ipairs(MythicPlus.Tabs) do
        tab.button:SetText(MythicGetText("UI", tab.key))
        tab.title:SetText(MythicGetText("UI", tab.key))
    end
end)
