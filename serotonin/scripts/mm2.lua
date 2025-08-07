local players = {}
local roleCache = {}

local Players = game.GetService("Players")
local Workspace = game.Workspace

local MM2_PLACE_IDS = {
    [142823291] = true,
    [136333311210714] = true,
    [134955552969606] = true,
}

local function inMM2()
    return MM2_PLACE_IDS[game.PlaceId] == true
end

local isMM2 = inMM2()

ui.newTab("mm2", "MM2")
ui.newContainer("mm2", "mm2_esp", "ESP")
ui.newCheckbox("mm2", "mm2_esp", "Enable Boxes")
ui.newCheckbox("mm2", "mm2_esp", "Box Filled")
ui.newCheckbox("mm2", "mm2_esp", "Show Weapon")
ui.newSliderFloat("mm2", "mm2_esp", "Max Distance", 100.0, 5000.0, 1000.0)
ui.newSliderFloat("mm2", "mm2_esp", "Box Thickness", 1.0, 5.0, 2.0)
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

local function getPlayers()
    if not isMM2 then return end
    players = {}
    local lp = entity.GetLocalPlayer()
    local entity_list = entity.GetPlayers()
    local maxDistance = ui.getValue("mm2", "mm2_esp", "Max Distance") or 1000 -- quick win #1

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

local function paintPlayers()
    if not isMM2 then return end

    local cfg = {
        color_innocent = toColor3(ui.getValue("mm2", "mm2_esp", "Innocent Color")),
        color_sheriff = toColor3(ui.getValue("mm2", "mm2_esp", "Sheriff Color")),
        color_murderer = toColor3(ui.getValue("mm2", "mm2_esp", "Murderer Color")),
        enable_boxes = ui.getValue("mm2", "mm2_esp", "Enable Boxes"),
        box_filled = ui.getValue("mm2", "mm2_esp", "Box Filled"),
        show_weapon = ui.getValue("mm2", "mm2_esp", "Show Weapon"),
        box_thickness = ui.getValue("mm2", "mm2_esp", "Box Thickness") or 2.0,
    }

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
            draw.Rect(boundingBox.x, boundingBox.y, boundingBox.w, boundingBox.h, rectColor, cfg.box_thickness)
            local function clamp(v) if v < 0 then return 0 elseif v > 1 then return 1 end return v end
            local OUTLINE_DELTA = 0.5
            local outlineColor = Color3.new(
                clamp(rectColor.r - OUTLINE_DELTA),
                clamp(rectColor.g - OUTLINE_DELTA),
                clamp(rectColor.b - OUTLINE_DELTA)
            )
            draw.Rect(boundingBox.x - 1, boundingBox.y - 1, boundingBox.w + 2, boundingBox.h + 2, outlineColor, 1)
            draw.Rect(boundingBox.x + 1, boundingBox.y + 1, boundingBox.w - 2, boundingBox.h - 2, outlineColor, 1)
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
end

local function updateMisc()
    isMM2 = inMM2()
    if not isMM2 then return end
    Workspace = game.Workspace
    Players = game.GetService("Players")
end

cheat.Register("onUpdate", getPlayers)
cheat.Register("onSlowUpdate", updateMisc)
cheat.Register("onPaint", paintPlayers)
