local AIO = AIO or require("AIO")
if AIO.AddAddon() then
    return
end

local COUNTDOWN_TIMER_SOUND = "Interface\\MythicPlus\\sounds\\UI_BattlegroundCountdown_Timer.ogg"
local COUNTDOWN_END_SOUND = "Interface\\MythicPlus\\sounds\\UI_BattlegroundCountdown_End.ogg"

local function CreateCountdownFrame()
    local frame = CreateFrame("Frame", "CountdownFrame", UIParent)
    frame:SetSize(512, 256)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 250)
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:Hide()

    frame.digit1 = frame:CreateTexture(nil, "ARTWORK")
    frame.digit1:SetSize(256, 170)
    frame.digit1:SetPoint("CENTER", frame, "CENTER", -70, 0)
    frame.digit1:SetTexture("Interface\\MythicPlus\\textures\\BigTimerNumbers")

    frame.digit2 = frame:CreateTexture(nil, "ARTWORK")
    frame.digit2:SetSize(256, 170)
    frame.digit2:SetPoint("CENTER", frame, "CENTER", 70, 0)
    frame.digit2:SetTexture("Interface\\MythicPlus\\textures\\BigTimerNumbers")

    return frame
end

local function SetDigit(tex, digit)
    local texW, texH = 1024, 512
    local digitW, digitH = 256, 170
    local columns = 4
    local col = digit % columns
    local row = math.floor(digit / columns)
    local l = (col * digitW) / texW
    local r = ((col + 1) * digitW) / texW
    local t = (row * digitH) / texH
    local b = ((row + 1) * digitH) / texH
    tex:SetTexCoord(l, r, t, b)
    tex:Show()
end

local function SetDigits(frame, num)
    local n1 = math.floor(num / 10)
    local n2 = num % 10

    if n1 > 0 then
        SetDigit(frame.digit1, n1)
        frame.digit1:Show()
        frame.digit2:SetPoint("CENTER", frame, "CENTER", 70, 0)
    else
        frame.digit1:Hide()
        frame.digit2:SetPoint("CENTER", frame, "CENTER", 0, 0)
    end
    SetDigit(frame.digit2, n2)
end

function MythicPlus.Handlers.StartCountdown(_, seconds)
    seconds = tonumber(seconds) or 10
    if CountdownFrame then
        CountdownFrame:Hide()
        CountdownFrame:SetScript("OnUpdate", nil)
    else
        CountdownFrame = CreateCountdownFrame()
    end

    local frame = CountdownFrame
    frame:Show()
    SetDigits(frame, seconds)
    PlaySoundFile(COUNTDOWN_TIMER_SOUND, "master")

    local remaining = seconds
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.lastUpdate then self.lastUpdate = 0 end
        self.lastUpdate = self.lastUpdate + elapsed
        if self.lastUpdate >= 1 then
            self.lastUpdate = self.lastUpdate - 1
            remaining = remaining - 1
            if remaining > 0 then
                SetDigits(self, remaining)
                PlaySoundFile(COUNTDOWN_TIMER_SOUND, "master")
            else
                PlaySoundFile(COUNTDOWN_END_SOUND, "master")
                self:Hide()
                self:SetScript("OnUpdate", nil)
            end
        end
    end)
end
