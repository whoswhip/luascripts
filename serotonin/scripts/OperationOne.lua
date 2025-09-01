local data = {players = {}, workspace = game.Workspace}
ui.newTab("op1", "Operation One")
ui.newContainer("op1", "visuals", "Visuals")
ui.newCheckbox("op1", "visuals", "Enable Chams")
ui.newColorpicker("op1", "visuals", "Chams Color", {r = 255, g = 0, b = 0, a = 128}, true)
ui.newCheckbox("op1", "visuals", "Enable Filled Chams")
ui.newColorpicker("op1", "visuals", "Filled Chams Color", {r = 128, g = 0, b = 0, a = 192}, true)
ui.newCheckbox("op1", "visuals", "Enable Boxes")
ui.newColorpicker("op1", "visuals", "Box Color", {r = 255, g = 1, b = 0, a = 255}, true)
ui.newCheckbox("op1", "visuals", "Enable Health Bar")
ui.newCheckbox("op1", "visuals", "Enable Names")

ui.newContainer("op1", "rcs", "Anti-Recoil", {autosize = true, next = true})
ui.newCheckbox("op1", "rcs", "Enable Anti-Recoil")
ui.newSliderInt("op1", "rcs", "Recoil Control Delay (ms)", 0, 100, 50)
ui.newSliderInt("op1", "rcs", "Recoil Control Horizontal", -100, 100, 50)
ui.newSliderInt("op1", "rcs", "Recoil Control Vertical", -100, 100, 50)

local uiValues = {enableChams = false, chamsColor = {r = 255, g = 0, b = 0, a = 128}, enableFilledChams = false, filledChamsColor = {r = 255, g = 0, b = 0, a = 192}, enableBoxes = false, boxColor = {r = 255, g = 1, b = 0, a = 255}, enableAntiRecoil = false, recoilControlHorizontal = 50, recoilControlVertical = 50}
local last_rcs_time = 0

local function updateUIValues()
    uiValues.enableChams = ui.getValue("op1", "visuals", "Enable Chams")
    uiValues.chamsColor = ui.getValue("op1", "visuals", "Chams Color")
    uiValues.enableFilledChams = ui.getValue("op1", "visuals", "Enable Filled Chams")
    uiValues.filledChamsColor = ui.getValue("op1", "visuals", "Filled Chams Color")
    uiValues.enableBoxes = ui.getValue("op1", "visuals", "Enable Boxes")
    uiValues.boxColor = ui.getValue("op1", "visuals", "Box Color")
    uiValues.enableHealthBar = ui.getValue("op1", "visuals", "Enable Health Bar")
    uiValues.enableNames = ui.getValue("op1", "visuals", "Enable Names")

    uiValues.enableAntiRecoil = ui.getValue("op1", "rcs", "Enable Anti-Recoil")
    uiValues.recoilControlHorizontal = ui.getValue("op1", "rcs", "Recoil Control Horizontal")
    uiValues.recoilControlVertical = ui.getValue("op1", "rcs", "Recoil Control Vertical")
    uiValues.recoilControlDelay = ui.getValue("op1", "rcs", "Recoil Control Delay (ms)")
end

local function doAntiRecoil()
    if uiValues.enableAntiRecoil and utility.GetMenuState() == false then
        if keyboard.isPressed(0x01) and keyboard.isPressed(0x02) then
            local current_time = utility.GetTickCount()
            if current_time - last_rcs_time >= uiValues.recoilControlDelay then
                utility.MoveMouse(uiValues.recoilControlHorizontal / 10, uiValues.recoilControlVertical / 10)
                last_rcs_time = current_time
            end
        end
    end
end

local function update()
    updateUIValues()
    doAntiRecoil()
    data.players = {}
    local lp = entity.getLocalPlayer()
    if not lp then return end
    local players = entity.getPlayers()
    local viewmodels = game.workspace:FindFirstChild("Viewmodels")
    if not viewmodels then return end
    for _, player in ipairs(players) do
        if player.Team == lp.Team or not player.Team or player.Team ~= "Blue" and player.Team ~= "Red" then goto continue end
        local wplayer = game.workspace:FindFirstChild(player.Name)
        local viewmodel = viewmodels:FindFirstChild("Viewmodels/" .. player.Name)
        if not viewmodel or not wplayer then goto continue end
        local humanoid = wplayer:FindFirstChild("Humanoid")
        if humanoid and humanoid.Health <= 0 then goto continue end
        table.insert(data.players, {workspace = wplayer, entity = player, viewmodel = viewmodel, humanoid = humanoid})
        ::continue::
    end
end

local function getScreenPointsFromCorners(corners)
    local screen_points = {}
    for _, world_pos in ipairs(corners) do
        local sx, sy, on_screen = utility.worldToScreen(world_pos)
        if on_screen then table.insert(screen_points, {sx, sy}) end
    end
    return screen_points
end

local function color3FromUI(color) return Color3.new(color.r / 255, color.g / 255, color.b / 255) end

local function clamp(v)
    if v < 0 then
        return 0
    elseif v > 1 then
        return 1
    end
    return v
end

local function RectOutlined(x, y, width, height, color, thickness)
    local outlineColor = Color3.new(clamp(color.r - 0.7), clamp(color.g - 0.7), clamp(color.b - 0.7))
    draw.Rect(x, y, width, height, color, thickness)
    draw.Rect(x + 1, y + 1, width - 2, height - 2, outlineColor, thickness)
    draw.Rect(x - 1, y - 1, width + 2, height + 2, outlineColor, thickness)
end

local function paint()
    if #data.players == 0 then return end
    for _, player_data in ipairs(data.players) do
        local parts = {head = player_data.viewmodel:FindFirstChild("head"), torso = player_data.viewmodel:FindFirstChild("torso"), arm1 = player_data.viewmodel:FindFirstChild("arm1"), arm2 = player_data.viewmodel:FindFirstChild("arm2"), leg1 = player_data.viewmodel:FindFirstChild("leg1"), leg2 = player_data.viewmodel:FindFirstChild("leg2"), hip1 = player_data.viewmodel:FindFirstChild("hip1"), hip2 = player_data.viewmodel:FindFirstChild("hip2"), shoulder1 = player_data.viewmodel:FindFirstChild("shoulder1"), shoulder2 = player_data.viewmodel:FindFirstChild("shoulder2")}
        local chamsColor = color3FromUI(uiValues.chamsColor)
        local boxColor = color3FromUI(uiValues.boxColor)
        local chamsAlpha = math.min(uiValues.chamsColor.a, 255)
        local boxAlpha = math.min(uiValues.boxColor.a, 255)

        if uiValues.enableChams then
            for _, part in pairs({parts.head, parts.torso}) do
                if part then
                    local corners = draw.GetPartCorners(part)
                    local screen_points = getScreenPointsFromCorners(corners)
                    local hull = draw.ComputeConvexHull(screen_points)
                    if hull and #hull >= 3 then
                        if uiValues.enableFilledChams then
                            local filledChamsColor = color3FromUI(uiValues.filledChamsColor)
                            local filledChamsAlpha = math.min(uiValues.filledChamsColor.a, 255)
                            draw.ConvexPolyFilled(hull, filledChamsColor, filledChamsAlpha)
                        end
                        if uiValues.enableChams then draw.Polyline(hull, chamsColor, true, 1, chamsAlpha) end
                    end
                end
            end
            for _, pair in pairs({{parts.hip1, parts.leg1}, {parts.hip2, parts.leg2}, {parts.shoulder1, parts.arm1}, {parts.shoulder2, parts.arm2}}) do
                if pair[1] and pair[2] then
                    local corners1 = draw.GetPartCorners(pair[1])
                    local corners2 = draw.GetPartCorners(pair[2])
                    local screen_points = {}
                    for _, p in ipairs(getScreenPointsFromCorners(corners1)) do table.insert(screen_points, p) end
                    for _, p in ipairs(getScreenPointsFromCorners(corners2)) do table.insert(screen_points, p) end
                    local hull = draw.ComputeConvexHull(screen_points)
                    if hull and #hull >= 3 then
                        if uiValues.enableFilledChams then
                            local filledChamsColor = color3FromUI(uiValues.filledChamsColor)
                            local filledChamsAlpha = math.min(uiValues.filledChamsColor.a, 255)
                            draw.ConvexPolyFilled(hull, filledChamsColor, filledChamsAlpha)
                        end
                        if uiValues.enableChams then draw.Polyline(hull, chamsColor, true, 1, chamsAlpha) end
                    end
                end
            end
        end
        if uiValues.enableBoxes or uiValues.enableHealthBar or uiValues.enableNames then
            local all_screen_points = {}
            for _, part in pairs(parts) do
                if part then
                    local corners = draw.GetPartCorners(part)
                    for _, p in ipairs(getScreenPointsFromCorners(corners)) do table.insert(all_screen_points, p) end
                end
            end
            if #all_screen_points >= 3 then
                local min_x, max_x = math.huge, -math.huge
                local min_y, max_y = math.huge, -math.huge
                for _, p in ipairs(all_screen_points) do
                    min_x = math.min(min_x, p[1])
                    max_x = math.max(max_x, p[1])
                    min_y = math.min(min_y, p[2])
                    max_y = math.max(max_y, p[2])
                end
                local width = max_x - min_x
                local height = max_y - min_y
                if uiValues.enableBoxes then RectOutlined(min_x, min_y, width, height, boxColor, 1) end
                if uiValues.enableHealthBar then
                    local health = player_data.humanoid and player_data.humanoid.Health or 100
                    local max_health = player_data.humanoid and player_data.humanoid.MaxHealth or 100

                    local health_percentage = health / max_health
                    local low_health_threshold = 0.3
                    local low_health_color = Color3.fromRGB(200, 0, 0)
                    local high_health_color = Color3.fromRGB(0, 200, 0)

                    draw.RectFilled(min_x - (width / 10) - 1, min_y - 1, 4, height, Color3.new(0.2, 0.2, 0.2), 1, 0, 255)
                    local health_color = low_health_color:Lerp(high_health_color, health_percentage)
                    local bar_height = height * health_percentage
                    local bar_y = min_y + (height - bar_height)
                    draw.Gradient(min_x - (width / 10), bar_y, 2, bar_height, health_color, health_color, false, 255, 255)
                end

                if uiValues.enableNames then
                    local name = player_data.entity.Name or "Unknown"
                    local tw, th = draw.GetTextSize(name, "SmallestPixel")
                    draw.TextOutlined(name, min_x + (width / 2) - (tw / 2), min_y - 12, Color3.new(1, 1, 1), "SmallestPixel")
                end
            end

        end
    end
end

cheat.Register("onUpdate", update)
cheat.Register("onPaint", paint)
