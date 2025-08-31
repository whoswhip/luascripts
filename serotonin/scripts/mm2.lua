local players = {}
local roleCache = {}
local gunCache = {}
local cfg = {
    color_innocent = Color3.new(0,1,0),
    color_sheriff = Color3.new(0,0,1),
    color_murderer = Color3.new(1,0,0),
    enable_boxes = false,
    box_filled = false,
    show_weapon = false,
    enable_gun_esp = false,
    max_distance = 1000.0,
}
local draw = draw
local map = nil
local Players = game.GetService("Players")
local Workspace = game.Workspace

local MM2_PLACE_IDS = {
    [142823291] = true,
    [136333311210714] = true,
    [134955552969606] = true,
}

local MM2_MAPS = {
  Bank2 = true, BioLab = true, Factory = true, Hospital3 = true, Hotel2 = true,
  House2 = true, Mansion2 = true, MilBase = true, Office3 = true, PoliceStation = true,
  ResearchFacility = true, Workplace = true, BeachResort = true, Yacht = true,
  Manor = true, Farmhouse = true, Mineshaft = true, BarnInfection = true,
  VampiresCastle = true, Workshop = true, LogCabin = true, TrainStation = true,
  Bank = true, Barn = true, Hospital = true, Hospital2 = true, Hotel = true,
  House = true, Lab2 = true, Mansion = true, MilBaseOriginal = true, nStudio = true,
  Office2 = true, Pond = true, BeachHouse = true, Casino = true, Coliseum = true,
  DodgeballArena = true, NightClub = true, Zoo = true, Dungeon = true, PirateShip = true,
  WildWest = true, School = true, Office = true, Castle = true, Junkyard = true
}

local function inMM2()
    return MM2_PLACE_IDS[game.PlaceId] == true
end

local isMM2 = inMM2()

ui.newTab("mm2", "MM2")
ui.newContainer("mm2", "mm2_esp", "ESP")
ui.newCheckbox("mm2", "mm2_esp", "Enable Boxes")
ui.newCheckbox("mm2", "mm2_esp", "Filled Boxes")
ui.newCheckbox("mm2", "mm2_esp", "Show Held Weapon")
ui.newCheckbox("mm2", "mm2_esp", "Enable Dropped Gun ESP")
ui.newSliderFloat("mm2", "mm2_esp", "Max Distance", 100.0, 10000.0, 1000.0)
ui.newColorpicker("mm2", "mm2_esp", "Innocent Color", {r=0, g=255, b=0, a=255})
ui.newColorpicker("mm2", "mm2_esp", "Sheriff Color", {r=0, g=0, b=255, a=255})
ui.newColorpicker("mm2", "mm2_esp", "Murderer Color", {r=255, g=0, b=0, a=255})

local function getRole(player)
    local backpack = player:FindFirstChild("Backpack")
    if backpack then
        for _, item in ipairs(backpack:GetChildren()) do
            if item.Name == "Knife" then
                return "Murderer", false
            elseif item.Name == "Gun" then
                return "Sheriff", false
            end
        end
    end
    local character = Workspace:FindFirstChild(player.Name)
    if character then
        for _, item in ipairs(character:GetChildren()) do
            if item.Name == "Knife" then
                return "Murderer", true
            elseif item.Name == "Gun" then
                return "Sheriff", true
            end
        end
    end
    return "Innocent", false
end

local function getGun()
    gunCache = nil
    if map then
        local mapModel = Workspace:FindFirstChild(map)

        if mapModel then
            local gunModel = mapModel:FindFirstChild("GunDrop")
            if gunModel then
                gunCache = gunModel
            end
        end
    end

    if not gunCache then
        for _, model in ipairs(Workspace:GetChildren()) do
            if model:IsA("Model") then
                for _, part in ipairs(model:GetChildren()) do
                    if part:IsA("Part") and part.Name == "GunDrop" then
                        gunCache = part
                        break
                    end
                end
                if gunCache then break end
            end
        end
    end
end

local function getPlayers()
    if not isMM2 then return end
    players = {}
    local lp = entity.GetLocalPlayer()
    local entity_list = entity.GetPlayers()

    local maxDistance = cfg.max_distance

    local lookup = {}
    for _, ent in ipairs(entity_list) do
        lookup[ent.Name] = ent
    end

    for _, plr in ipairs(Players:GetChildren()) do
        local ent = lookup[plr.Name]
        if ent then
            local pos = ent.Position
            if lp and (pos - lp.Position).Magnitude > maxDistance then
                goto continue
            end
            players[#players+1] = { player = plr, entity = ent }

            local role, holdingWeapon = getRole(plr)
            roleCache[plr] = { role = role, holdingWeapon = holdingWeapon }
        end
        ::continue::
    end
end

local function toColor3(c)
    return Color3.new((c.r or 0)/255, (c.g or 0)/255, (c.b or 0)/255)
end

local function RectOutlined(x, y, width, height, color, outlineColor, thickness)
    draw.Rect(x, y, width, height, color, thickness)
    draw.Rect(x + 1, y + 1, width - 2, height - 2, outlineColor, thickness)
    draw.Rect(x - 1, y - 1, width + 2, height + 2, outlineColor, thickness)
end
draw.RectOutlined = RectOutlined

local function getMap()
    local lobby = game.Workspace:FindFirstChild("Lobby")
    if lobby then
        local maps = {}
        local mapVote = lobby:FindFirstChild("MapVote")
        if mapVote then
            for _, child in ipairs(mapVote:GetChildren()) do
                local VoteInfoGui = child:FindFirstChild("VoteInfoGui")
                if VoteInfoGui then
                   local container = VoteInfoGui:FindFirstChild("Container")
                   if container then
                        local MapName = container:FindFirstChild("MapName")
                        local Votes = container:FindFirstChild("Votes")
                        local entry = {
                            Name = MapName and MapName.Value or "Unknown",
                            Votes = Votes and Votes.Value or 0
                        }
                        table.insert(maps, entry)
                   end
                end
            end
        end
        if #maps > 0 then
            local mostVotes = maps[1]
            for _, map in ipairs(maps) do
                if map.Votes > mostVotes.Votes then
                    mostVotes = map
                end
            end
            map = mostVotes.Name
        end
    end
end

local function updateConfig()
    cfg.color_innocent = toColor3(ui.getValue("mm2", "mm2_esp", "Innocent Color"))
    cfg.color_sheriff  = toColor3(ui.getValue("mm2", "mm2_esp", "Sheriff Color"))
    cfg.color_murderer = toColor3(ui.getValue("mm2", "mm2_esp", "Murderer Color"))
    cfg.enable_boxes   = ui.getValue("mm2", "mm2_esp", "Enable Boxes") or false
    cfg.box_filled     = ui.getValue("mm2", "mm2_esp", "Filled Boxes") or false
    cfg.show_weapon    = ui.getValue("mm2", "mm2_esp", "Show Held Weapon") or false
    cfg.max_distance   = ui.getValue("mm2", "mm2_esp", "Max Distance") or 1000.0
    cfg.enable_gun_esp = ui.getValue("mm2", "mm2_esp", "Enable Dropped Gun ESP") or false
end

local function paint()
    if not isMM2 then return end

    for _, playerData in ipairs(players) do
        local player, ent = playerData.player, playerData.entity
        local boundingBox = ent and ent.BoundingBox
        if not boundingBox or not boundingBox.w or boundingBox.w <= 0 or boundingBox.h <= 0 then
            goto continue
        end

        local cached = roleCache[player]
        local role = cached and cached.role or "Innocent"
        local holdingWeapon = cached and cached.holdingWeapon or false

        local rectColor = (role == "Murderer" and cfg.color_murderer)
            or (role == "Sheriff" and cfg.color_sheriff)
            or cfg.color_innocent

        if cfg.enable_boxes then
            local function clamp(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
            local OUTLINE_DELTA = 0.7
            local outlineColor = Color3.new(
                clamp(rectColor.r - OUTLINE_DELTA),
                clamp(rectColor.g - OUTLINE_DELTA),
                clamp(rectColor.b - OUTLINE_DELTA)
            )
            draw.RectOutlined(boundingBox.x, boundingBox.y, boundingBox.w, boundingBox.h, rectColor, outlineColor, 1)
        end

        if cfg.box_filled then
            draw.RectFilled(boundingBox.x + 1, boundingBox.y + 1, boundingBox.w - 2, boundingBox.h - 2, rectColor, 1, 50)
        end

        draw.TextOutlined(role, boundingBox.x + boundingBox.w + 4, boundingBox.y, Color3.new(1, 1, 1), "SmallestPixel")
        if cfg.show_weapon and role ~= "Innocent" and holdingWeapon then
            local weapon = (role == "Murderer") and "Knife" or "Gun"
            draw.TextOutlined(weapon, boundingBox.x + boundingBox.w + 4, boundingBox.y + 8, Color3.new(1, 1, 1), "SmallestPixel")
        end

        ::continue::
    end
    if cfg.enable_gun_esp and gunCache then
        local gx, gy, onscreen = utility.WorldToScreen(gunCache.Position)
        if gx and gy and onscreen then
            local corners_3d = draw.GetPartCorners(gunCache)
            local topx, topy = nil, nil
            local width, height = nil, nil
            if corners_3d then
                local screen_points = {}
                for _, world_pos in ipairs(corners_3d) do
                    local sx, sy, vis = utility.WorldToScreen(world_pos)
                    if vis then
                        table.insert(screen_points, { sx, sy })
                    end
                end

                if #screen_points >= 3 then
                    local hull = draw.ComputeConvexHull(screen_points)
                    if hull and #hull >= 2 then
                        draw.Polyline(hull, Color3.new(0, 0, 1), true, 1.0, 255)
                        draw.ConvexPolyFilled(hull, Color3.new(0, 0, 0.9), 50)
                    end

                    for _, p in ipairs(hull) do
                        if not topx or p[2] < topy then
                            topx, topy = p[1], p[2]
                        end
                    end

                    local minx, miny = hull[1][1], hull[1][2]
                    local maxx, maxy = hull[1][1], hull[1][2]
                    for _, p in ipairs(hull) do
                        if p[1] < minx then minx = p[1] end
                        if p[1] > maxx then maxx = p[1] end
                        if p[2] < miny then miny = p[2] end
                        if p[2] > maxy then maxy = p[2] end
                    end
                    width = maxx - minx
                    height = maxy - miny
                end
            end
            local x, y = gx - width / 2, gy - height / 2
            draw.TextOutlined("Dropped Gun", x, y - 8, Color3.new(1, 1, 1), "SmallestPixel")
        end
    end
    
end

local function updateMisc()
    isMM2 = inMM2()
    if not isMM2 then return end
    Workspace = game.Workspace
    Players = game.GetService("Players")
end

cheat.Register("onUpdate", function()
    updateConfig()
    getPlayers()
    getGun()
end)
cheat.Register("onSlowUpdate", function()
    updateMisc()
    getMap()
end)
cheat.Register("onPaint", paint)
