-- Minesweeper Solver
-- https://roblox.com/games/7871169780/bLockermans-Minesweeper
-- Made by whoswhip
-- https://github.com/whoswhip/luascripts/blob/main/serotonin/scripts/MineSweeper.lua
local data = {
    cells = { 
        all = {},
        numbered = {},
        toFlag = {},
        toClear = {},
        guess = {},
    },
    cache = {
        xs_centers_cached = nil,
        zs_centers_cached = nil
    },
    grid = {
        w = 0,
        h = 0
    },
    ui = {
        PROB_FLAG_THRESHOLD = 0.70,
        PROB_SAFE_THRESHOLD = 0.30,
        drawNumbers = false,
        drawFlags = true,
        drawClears = true,
        drawGuesses = true
    },
    timing = {
        lastPlanTick = 0,
        planIntervalMs = 50
    }
}

local colors = {
    [1] = { R = 100, G = 100, B = 255 },
    [2] = { R = 100, G = 206, B = 0 },
    [3] = { R = 238, G = 0, B = 0 },
    [4] = { R = 0, G = 0, B = 114 },
    [5] = { R = 96, G = 0, B = 0 },
    [6] = { R = 0, G = 167, B = 189 },
    [7] = { R = 17, G = 18, B = 21 },
    [8] = { R = 231, G = 234, B = 239 },
}

local abs, floor, huge = math.abs, math.floor, math.huge
local sort = table.sort
local tostring, tonumber, ipairs, pairs = tostring, tonumber, ipairs, pairs
local Color3_fromRGB = Color3 and Color3.fromRGB

local NUM_COLORS = {}
for i = 1, 8 do
    local c = colors[i]
    if c then NUM_COLORS[i] = (Color3_fromRGB and Color3_fromRGB(c.R, c.G, c.B) or Color3.fromRGB(c.R, c.G, c.B)) end
end
local COL_YELLOW = (Color3_fromRGB and Color3_fromRGB(255, 255, 0) or Color3.fromRGB(255, 255, 0))
local COL_FLAG = (Color3_fromRGB and Color3_fromRGB(255, 51, 51) or Color3.fromRGB(255, 51, 51))
local COL_CLEAR = (Color3_fromRGB and Color3_fromRGB(51, 255, 51) or Color3.fromRGB(51, 255, 51))
local COL_GUESS_HIGH = (Color3_fromRGB and Color3_fromRGB(255, 180, 50) or Color3.fromRGB(255, 180, 50))
local COL_GUESS_HIGH_PCT = (Color3_fromRGB and Color3_fromRGB(255, 210, 120) or Color3.fromRGB(255, 210, 120))
local COL_GUESS_SAFE = (Color3_fromRGB and Color3_fromRGB(50, 220, 220) or Color3.fromRGB(50, 220, 220))
local COL_GUESS_SAFE_PCT = (Color3_fromRGB and Color3_fromRGB(120, 230, 230) or Color3.fromRGB(120, 230, 230))
local COL_GUESS_OTHER = (Color3_fromRGB and Color3_fromRGB(180, 100, 220) or Color3.fromRGB(180, 100, 220))
local COL_GUESS_OTHER_PCT = (Color3_fromRGB and Color3_fromRGB(200, 150, 230) or Color3.fromRGB(200, 150, 230))

ui.newTab("ms", "Minesweeper")
ui.newContainer("ms", "settings", "Settings")
ui.newCheckbox("ms", "settings", "Draw Numbers")
ui.newCheckbox("ms", "settings", "Draw Flags")
ui.newCheckbox("ms", "settings", "Draw Clears")
ui.newCheckbox("ms", "settings", "Draw Guesses")
ui.newSliderInt("ms", "settings", "Flag Probability Threshold", 25, 95, 70)
ui.newSliderInt("ms", "settings", "Safe Probability Threshold", 25, 95, 30)

ui.setValue("ms", "settings", "Draw Numbers", true)
ui.setValue("ms", "settings", "Draw Flags", true)
ui.setValue("ms", "settings", "Draw Clears", true)
ui.setValue("ms", "settings", "Draw Guesses", true)

local function isPartFlagged(part) 
    if not part or not part.GetChildren then return false end
    local children = part:GetChildren()
    for _, child in pairs(children) do
        local name = child and child.Name
        if name and string.sub(name, 1, 4) == "Flag" then
            return true
        end
    end
    return false
end

local function isNumber(str)
    return tonumber(str) ~= nil
end

local function key(ix, iz)
    return tostring(ix)..":"..tostring(iz)
end

local function clusterSorted(sorted_list, epsilon)
    local clusters = {}
    if #sorted_list == 0 then return clusters end
    local current_center = sorted_list[1]
    local current_count = 1
    for i = 2, #sorted_list do
        local v = sorted_list[i]
    if abs(v - current_center) <= epsilon then
            current_count = current_count + 1
            current_center = current_center + (v - current_center) / current_count
        else
            table.insert(clusters, current_center)
            current_center = v
            current_count = 1
        end
    end
    table.insert(clusters, current_center)
    return clusters
end


local function median(tbl)
    if #tbl == 0 then return nil end
    sort(tbl)
    local mid = floor((#tbl + 1) / 2)
    return tbl[mid]
end

local function typicalSpacing(sorted_centers)
    if #sorted_centers < 2 then return 4 end
    local diffs = {}
    for i = 2, #sorted_centers do
        diffs[#diffs + 1] = abs(sorted_centers[i] - sorted_centers[i - 1])
    end
    return median(diffs) or 4
end

local function nearestIndex(v, centers)
    local bestI = 1
    local bestD = huge
    for i = 1, #centers do 
        local d = abs(v - centers[i])
        if d < bestD then
            bestD = d
            bestI = i
        end
    end
    return bestI - 1
end

local function isCoveredCell(cell)
    if not cell then return false end
    if cell.state == "number" or cell.state == "flagged" then return false end
    return cell.covered ~= false
end

local function buildGrid()
    data.cells.all = {}
    data.cells.numbered = {}
    data.cells.grid = {}

    local root = game.Workspace:FindFirstChild("Flag")
    if not root then return end
    local partsFolder = root:FindFirstChild("Parts")
    if not partsFolder then return end

    local parts = partsFolder:GetChildren()
    local raw = {}
    local sumY, countY = 0, 0
    for _, part in pairs(parts) do
        local pos = part and part.Position
        if pos then
            table.insert(raw, {
                part = part,
                pos = pos
            })
            sumY = sumY + pos.Y
            countY = countY + 1
        end
    end

    local centersX, centersZ = {}, {}
    for _, item in ipairs(raw) do 
        local part = item.part
        local pos = item.pos
        centersX[#centersX + 1] = pos.X
        centersZ[#centersZ + 1] = pos.Z
    end

    sort(centersX)
    sort(centersZ)
    local typicalWX = typicalSpacing(centersX)
    local typicalWZ = typicalSpacing(centersZ)
    local epsX = typicalWX * 0.6
    local epsZ = typicalWZ * 0.6

    data.cache.xs_centers_cached = clusterSorted(centersX, epsX)
    data.cache.zs_centers_cached = clusterSorted(centersZ, epsZ)
    data.grid.w = #data.cache.xs_centers_cached
    data.grid.h = #data.cache.zs_centers_cached

    local planeY = (countY > 0) and (sumY / countY) or 0
    for iz = 0, data.grid.h - 1 do
        for ix = 0, data.grid.w - 1 do
            local k = key(ix, iz)
            local row = data.cells.grid[ix]
            if not row then row = {} data.cells.grid[ix] = row end
            local cell = {
                ix = ix,
                iz = iz,
                part = nil,
                pos = Vector3.new(
                    data.cache.xs_centers_cached[ix + 1] or 0,
                    planeY,
                    data.cache.zs_centers_cached[iz + 1] or 0
                ),
                state = "unknown",
                number = nil,
                k = k,
                covered = true,
                neigh = nil,
            }
            data.cells.all[k] = cell
            row[iz] = cell
        end
    end

    for _, item in ipairs(raw) do 
        local part = item.part
        local pos = item.pos
        local ix = nearestIndex(pos.X, data.cache.xs_centers_cached)
        local iz = nearestIndex(pos.Z, data.cache.zs_centers_cached)
        if ix >= 0 and ix < data.grid.w and iz >= 0 and iz < data.grid.h then
            local k = key(ix, iz)
            local cell = data.cells.all[k]
            if not cell.part then
                cell.part = part
                cell.pos = pos
            else
                local cur_d = abs((cell.part and cell.part.Position.X or cell.pos.X) - data.cache.xs_centers_cached[ix+1])
                            + abs((cell.part and cell.part.Position.Z or cell.pos.Z) - data.cache.zs_centers_cached[iz+1])
                local new_d = abs(pos.X - data.cache.xs_centers_cached[ix+1])
                            + abs(pos.Z - data.cache.zs_centers_cached[iz+1])

                if new_d < cur_d then
                    cell.part = part
                    cell.pos = pos
                end
            end

            if part.Color then
                local color = part.Color
                local r = color.R or color.r or color[1]
                local g = color.G or color.g or color[2]
                local b = color.B or color.b or color[3]
                if r and r <= 1 then r = math.floor(r * 255 + 0.5) end
                if g and g <= 1 then g = math.floor(g * 255 + 0.5) end
                if b and b <= 1 then b = math.floor(b * 255 + 0.5) end
                cell.color = { R = r, G = g, B = b }
            end

            local ngui = part:FindFirstChild("NumberGui")
            if ngui then
                local textLabel = ngui:FindFirstChild("TextLabel")
                if textLabel and textLabel.Value and isNumber(textLabel.Value) then
                    cell.number = tonumber(textLabel.Value)
                    cell.covered = false
                end
            end

            if cell.color and cell.color.R and cell.color.G and cell.color.B then
                if cell.color.R == 255 and cell.color.G == 255 and cell.color.B == 125 then
                    cell.covered = false
                end
            end
            if isPartFlagged(part) then
                cell.state = "flagged"
            end
            if cell.number and not cell.covered then
                cell.state = "number"
                table.insert(data.cells.numbered, cell)
            end
        end
    end

    for iz = 0, data.grid.h - 1 do
        for ix = 0, data.grid.w - 1 do
            local c = data.cells.grid[ix][iz]
            local neigh = {}
            for dz = -1, 1 do
                for dx = -1, 1 do
                    if not (dx == 0 and dz == 0) then
                        local jx, jz = ix + dx, iz + dz
                        if jx >= 0 and jx < data.grid.w and jz >= 0 and jz < data.grid.h then
                            local row = data.cells.grid[jx]
                            local n = row and row[jz]
                            if n then neigh[#neigh + 1] = n end
                        end
                    end
                end
            end
            c.neigh = neigh
        end
    end
end

local function neighbors(ix, iz)
    local row = data.cells.grid[ix]
    local c = row and row[iz]
    return c and c.neigh or {}
end



local function planMove()
    if not data.cache.xs_centers_cached or not data.cache.zs_centers_cached or data.grid.w == 0 or data.grid.h == 0 then
        return
    end
    if #data.cells.numbered == 0 then
        data.cells.toFlag = {}
        data.cells.toClear = {}
        data.cells.guess = {}
        return
    end
    data.cells.toFlag = {}
    data.cells.toClear = {}
    data.cells.guess = {}

    local knownFlag = {}
    for _, cell in pairs(data.cells.all) do
        if cell.state == "flagged" then knownFlag[cell] = true end
    end
    local knownClear = {}

    local scratch = {}
    local function computeUnknowns(c)
        local nbs = neighbors(c.ix, c.iz)
        for i = 1, #scratch do scratch[i] = nil end
        local flaggedCount = 0
        for i = 1, #nbs do
            local nb = nbs[i]
            if knownFlag[nb] or nb.state == "flagged" then
                flaggedCount = flaggedCount + 1
            elseif not knownClear[nb] and isCoveredCell(nb) then
                scratch[#scratch + 1] = nb
            end
        end
        return scratch, flaggedCount
    end

    local changed = true
    local guard = 0
    while changed and guard < 64 do
        changed = false
        guard = guard + 1
        for _, cell in ipairs(data.cells.numbered) do
            local num = cell.number or 0
            local unknowns, flaggedCount = computeUnknowns(cell)
            local remaining = num - flaggedCount
            if remaining > 0 and remaining == #unknowns then
                for i = 1, #unknowns do
                    local u = unknowns[i]
                    if not knownFlag[u] then
                        knownFlag[u] = true
                        data.cells.toFlag[u] = true
                        changed = true
                    end
                end
            elseif remaining == 0 and #unknowns > 0 then
                for i = 1, #unknowns do
                    local u = unknowns[i]
                    if not knownClear[u] then
                        knownClear[u] = true
                        data.cells.toClear[u] = true
                        changed = true
                    end
                end
            end
        end
    end

    local accum = {}
    for _, cell in ipairs(data.cells.numbered) do
        local num = cell.number or 0
        local unknowns, flaggedCount = computeUnknowns(cell)
        local remaining = num - flaggedCount
        if remaining > 0 and #unknowns > 0 then
            local p_each = remaining / #unknowns
            for i = 1, #unknowns do
                local u = unknowns[i]
                if not knownFlag[u] and not knownClear[u] then
                    local e = accum[u]
                    if not e then e = { sum = 0, w = 0 } accum[u] = e end
                    e.sum = e.sum + p_each
                    e.w = e.w + 1
                end
            end
        end
    end

    local pflag = (data.ui and data.ui.PROB_FLAG_THRESHOLD) or PROB_FLAG_THRESHOLD
    local psafe = (data.ui and data.ui.PROB_SAFE_THRESHOLD) or PROB_SAFE_THRESHOLD
    for cell, e in pairs(accum) do
        local p = (e.w > 0) and (e.sum / e.w) or 0
        if knownFlag[cell] then
            data.cells.toFlag[cell] = true
        else
            if p >= pflag then
                data.cells.toFlag[cell] = true
                knownFlag[cell] = true
            else
                data.cells.guess[cell] = p
            end
        end
    end

    for cell, _ in pairs(data.cells.toFlag) do
        data.cells.toClear[cell] = nil
        data.cells.guess[cell] = nil
    end
    for cell, _ in pairs(data.cells.toClear) do
        data.cells.toFlag[cell] = nil
        data.cells.guess[cell] = nil
    end
    for cell, _ in pairs(data.cells.guess) do
        if knownFlag[cell] then
            data.cells.guess[cell] = nil
        end
    end
end

local function isEmptyCell(part)
    if part.state == "number" or part.state == "flagged" then return false end
    local color = part.color
    if color and color.R and color.G and color.B then
        if color.R == 255 and color.G == 255 and color.B == 125 then
            return true
        end
    end
end

local function updateUIData()
    data.ui.PROB_FLAG_THRESHOLD = (ui.getValue("ms", "settings", "Flag Probability Threshold") or 70) / 100
    data.ui.PROB_SAFE_THRESHOLD = (ui.getValue("ms", "settings", "Safe Probability Threshold") or 30) / 100
    data.ui.drawNumbers = ui.getValue("ms", "settings", "Draw Numbers") or false
    data.ui.drawFlags = ui.getValue("ms", "settings", "Draw Flags") or false
    data.ui.drawClears = ui.getValue("ms", "settings", "Draw Clears") or false
    data.ui.drawGuesses = ui.getValue("ms", "settings", "Draw Guesses") or false
end

local function cellToScreen(cell)
    local pos
    if cell.part and cell.part.Position then
        pos = cell.part.Position
    else
        pos = cell.pos
    end
    if not pos then return nil, nil end
    if not utility or not utility.WorldToScreen then return nil, nil end
    local sx, sy, onScreen = utility.WorldToScreen(pos)
    if not onScreen then return nil, nil end
    return sx, sy
end
local function fmtPct(p)
    return string.format("%d%%", floor(p * 100 + 0.5))
end

local function paint()
    if data.ui.drawNumbers then
        for _, cell in ipairs(data.cells.numbered) do
            local sx, sy = cellToScreen(cell)
            if sx and sy then
                local col = NUM_COLORS[cell.number or 0] or COL_YELLOW
                draw.TextOutlined(tostring(cell.number or "?"), sx, sy, col)
            end
        end
    end

    if data.ui.drawFlags then
        for cell, _ in pairs(data.cells.toFlag or {}) do
            local sx, sy = cellToScreen(cell)
            if sx and sy then draw.TextOutlined("F", sx, sy, COL_FLAG) end
        end
    end

    if data.ui.drawClears then
        for cell, _ in pairs(data.cells.toClear or {}) do
            local sx, sy = cellToScreen(cell)
            if sx and sy then draw.TextOutlined("O", sx, sy, COL_CLEAR) end
        end
    end

    if data.ui.drawGuesses then
        for cell, p in pairs(data.cells.guess or {}) do
            local sx, sy = cellToScreen(cell)
            if sx and sy then
                if p >= data.ui.PROB_FLAG_THRESHOLD then
                    draw.TextOutlined("X", sx, sy, COL_GUESS_HIGH)
                    draw.TextOutlined(fmtPct(p), sx + 10, sy - 10, COL_GUESS_HIGH_PCT)
                elseif p <= data.ui.PROB_SAFE_THRESHOLD then
                    draw.TextOutlined("?", sx, sy, COL_GUESS_SAFE)
                    draw.TextOutlined(fmtPct(1 - p), sx + 10, sy - 10, COL_GUESS_SAFE_PCT)
                else
                    draw.TextOutlined("?", sx, sy, COL_GUESS_OTHER)
                    draw.TextOutlined(fmtPct(p), sx + 10, sy - 10, COL_GUESS_OTHER_PCT)
                end
            end
        end
    end
end

cheat.register("onUpdate", function()
    if data.grid.w == 0 or not data.cache.xs_centers_cached or not data.cache.zs_centers_cached then
        buildGrid()
    end
    local now = (utility and utility.GetTickCount and utility.GetTickCount()) or 0
    if data.timing.lastPlanTick == 0 or now == 0 or (now - data.timing.lastPlanTick) >= (data.timing.planIntervalMs or 50) then
        planMove()
        if now ~= 0 then data.timing.lastPlanTick = now end
    end
end)
cheat.register("onSlowUpdate", function()
    updateUIData()
    buildGrid()
end)

cheat.register("onPaint", paint)