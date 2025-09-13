-- RoQube Auto Player
-- game: https://www.roblox.com/games/116543366018035/VR-Ro-Qube
-- github: https://github.com/whoswhip/luascripts/blob/main/serotonin/scripts/RoQube.lua
-- made by: whoswhip

--region Rect
local Rect = {}
Rect.__index = Rect

setmetatable(Rect, {
    __call = function(_, width, height, x, y)
        return setmetatable({ w = width, h = height, x = x, y = y }, Rect)
    end
})

function Rect:contains(px, py)
    return px >= self.x and px <= self.x + self.w
       and py >= self.y and py <= self.y + self.h
end

function Rect:intersects(other)
    return not (
                self.x > other.x + other.w or
                self.x + self.w < other.x or
                self.y > other.y + other.h or
                self.y + self.h < other.y
            )
end
--endregion

local InputAreaWidth = 155 / 2560
local InputAreaHeight = 155 / 1440
local InputAreaGap = 27 / 2560
local InputAreaStartX = 930 / 2560
local InputAreaStartY = 1230 / 1440
local lanes = {
    Rect(InputAreaWidth, InputAreaHeight, InputAreaStartX, InputAreaStartY),
    Rect(InputAreaWidth, InputAreaHeight, InputAreaStartX + InputAreaWidth + InputAreaGap, InputAreaStartY),
    Rect(InputAreaWidth, InputAreaHeight, InputAreaStartX + 2 * (InputAreaWidth + InputAreaGap), InputAreaStartY),
    Rect(InputAreaWidth, InputAreaHeight, InputAreaStartX + 3 * (InputAreaWidth + InputAreaGap), InputAreaStartY),
}
local KEYBINDS = { [1] = 0x44, [2] = 0x46, [3] = 0x4A, [4] = 0x4B } -- D, F, J, K

local ACCURACY_OFFSETS  = {
    [1] = -50 / 1440, -- MARVELOUS
    [2] = -25 / 1440, -- PERFECT
    [3] = 60 / 1440, -- GREAT
    [4] = 150 / 1440, -- GOOD
    [5] = 200 / 1440, -- BAD
    [6] = -10000 / 1440 -- MISS
}

local config = {
    autoPlay = true,
    accuracy = { 1, 2, 3 },
    hitChance = 100,
    hitDelay = 0,
    hitHold = 10,
    laneYOffset = 0
}

local notes = {}

ui.newTab("rqbs", "RoQube")
ui.newContainer("rqbs", "settings", "Settings", { autosize = true})
ui.newCheckbox("rqbs", "settings", "Auto Play")
ui.newMultiselect("rqbs", "settings", "Hit Accuracy", { "MARVELOUS", "PERFECT", "GREAT", "GOOD", "BAD", "MISS" })
ui.newSliderInt("rqbs", "settings", "Hit Chance (%)", 0, 100, 100)
ui.newSliderInt("rqbs", "settings", "Hit Delay (ms)", 0, 800, 0)
ui.newSliderInt("rqbs", "settings", "Hit Hold (ms)", 0, 100, 10)
ui.newSliderInt("rqbs", "settings", "Lane Y Offset (px)", -100, 100, 0)

ui.setValue("rqbs", "settings", "Auto Play", config.autoPlay)
ui.setValue("rqbs", "settings", "Hit Chance (%)", config.hitChance)
ui.setValue("rqbs", "settings", "Hit Delay (ms)", config.hitDelay)
ui.setValue("rqbs", "settings", "Hit Hold (ms)", config.hitHold)
ui.setValue("rqbs", "settings", "Lane Y Offset (px)", config.laneYOffset)

local function updateConfig()
    config.autoPlay = ui.getValue("rqbs", "settings", "Auto Play")
    config.accuracy = ui.getValue("rqbs", "settings", "Hit Accuracy")
    config.hitChance = ui.getValue("rqbs", "settings", "Hit Chance (%)")
    config.hitDelay = ui.getValue("rqbs", "settings", "Hit Delay (ms)")
    config.hitHold = ui.getValue("rqbs", "settings", "Hit Hold (ms)")
    config.laneYOffset = ui.getValue("rqbs", "settings", "Lane Y Offset (px)")
    if config.laneYOffset ~= 0 or config.laneYOffset then
        for _, lane in pairs(lanes) do
            lane.y = InputAreaStartY + config.laneYOffset / 1440
        end
    end
end

local function wait(ms)
    local start = utility.GetTickCount()
    while utility.GetTickCount() - start < ms do end
end

local function inLane(x, y)
    for i, lane in ipairs(lanes) do
        if lane:contains(x, y) then
            return i
        end
    end
    return nil
end

local function getNotes()
    notes = {}
    local sW, sH = cheat.getWindowSize()
    local QubeFold = game.Workspace:FindFirstChild("QubeFold")
    if QubeFold then
        for _, child in ipairs(QubeFold:GetChildren()) do
            local qubePart = child:FindFirstChild("Qube")
            if qubePart then
                local sx, sy, onScreen = utility.WorldToScreen(qubePart.Position)
                if onScreen and sx and sy then

                    if config.accuracy and #config.accuracy > 0 then
                        local choices = {}
                        for i, selected in ipairs(config.accuracy) do
                            if selected then table.insert(choices, i) end
                        end
                        if #choices > 0 then
                            local rnd = utility.randomInt(1, #choices)
                            local accuracyIndex = choices[rnd]
                            local offset = (ACCURACY_OFFSETS[accuracyIndex] * sH) or (50 / 1440 * sH)
                            sy = sy + offset
                        end
                    end

                    local nx, ny = sx / sW, sy / sH
                    local laneIndex = inLane(nx, ny)
                    if laneIndex then
                        table.insert(notes, {
                            part = qubePart,
                            lane = laneIndex
                        })
                    end
                end
            end
        end
    end
end

local function playNotes()
    if utility.GetMenuState() or not config.autoPlay then return end
    for _, note in ipairs(notes) do
        local lane = note.lane
        if lane and KEYBINDS[lane] then
            if utility.randomInt(1, 100) > config.hitChance then return end
            if config.hitDelay > 0 then
                wait(config.hitDelay)
            end

            keyboard.click(KEYBINDS[lane], config.hitHold)
        end
    end
end

local function drawLanes()
    local sW, sH = cheat.getWindowSize()
    for _, lane in pairs(lanes) do
        local x, y = lane.x * sW, lane.y * sH
        local w, h = lane.w * sW, lane.h * sH
        draw.Rect(x, y, w, h, Color3.new(1,1,1))
    end
end

cheat.Register("onUpdate", function()
    getNotes()
    playNotes()
    updateConfig()
end)
cheat.Register("onPaint", function()
    drawLanes()
end)