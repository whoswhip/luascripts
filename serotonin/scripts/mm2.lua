local players = {}
local Players = game.GetService("Players")
local Workspace = game.Workspace
local isMM2 = (game.PlaceId == 142823291 or game.PlaceId == 136333311210714 or game.PlaceId == 134955552969606)

ui.newTab("mm2", "MM2")
ui.newContainer("mm2", "mm2_esp", "ESP")
ui.newCheckbox("mm2", "mm2_esp", "Enable Boxes")
ui.newCheckbox("mm2", "mm2_esp", "Box Filled")
ui.newCheckbox("mm2", "mm2_esp", "Show Weapon")
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
    local entity_lookup = entity.GetPlayers()
    for _, ent in ipairs(entity_lookup) do entity_lookup[ent.Name] = ent end
    for _, player in ipairs(Players:GetChildren()) do
        local ent = entity_lookup[player.Name]
        if ent then
            local pos = ent.Position
            if lp and (pos - lp.Position).Magnitude > 1000 then
                goto continue
            end
            players[#players+1] = {player=player, entity=ent}
        end
        ::continue::
    end
end

local function toColor3(c)
    return Color3.new((c.r or 0)/255, (c.g or 0)/255, (c.b or 0)/255)
end

local function paintPlayers()
    if not isMM2 then return end
    local screen_w, screen_h = cheat.getWindowSize()
    local color_innocent = toColor3(ui.getValue("mm2", "mm2_esp", "Innocent Color"))
    local color_sheriff = toColor3(ui.getValue("mm2", "mm2_esp", "Sheriff Color"))
    local color_murderer = toColor3(ui.getValue("mm2", "mm2_esp", "Murderer Color"))
    local enable_boxes = ui.getValue("mm2", "mm2_esp", "Enable Boxes")
    local box_filled = ui.getValue("mm2", "mm2_esp", "Box Filled")
    local show_weapon = ui.getValue("mm2", "mm2_esp", "Show Weapon")

    for _, playerData in ipairs(players) do
        local player, entity = playerData.player, playerData.entity
        local boundingBox = entity.BoundingBox

        if not boundingBox or boundingBox.x <= 0 or boundingBox.y <= 0 then
            goto continue
        end

        local role, holdingWeapon = getRole(player)
        local rectColor = (role == "Murderer" and color_murderer) or (role == "Sheriff" and color_sheriff) or color_innocent
        if enable_boxes then 
            draw.Rect(boundingBox.x, boundingBox.y, boundingBox.w, boundingBox.h, rectColor, 2) 
            -- outline
            local outlineColor =  Color3.new(rectColor.r - 0.7, rectColor.g - 0.7, rectColor.b - 0.7)
            draw.Rect(boundingBox.x - 1, boundingBox.y - 1, boundingBox.w + 2, boundingBox.h + 2, outlineColor, 1)
            draw.Rect(boundingBox.x + 1, boundingBox.y + 1, boundingBox.w - 2, boundingBox.h - 2, outlineColor, 1)
        end
        if box_filled then
            draw.RectFilled(boundingBox.x + 1, boundingBox.y + 1, boundingBox.w - 2, boundingBox.h - 2, rectColor, 1, 50)
        end
        draw.TextOutlined(role, boundingBox.x + boundingBox.w + 4, boundingBox.y, Color3.new(1, 1, 1), "SmallestPixel")
        if show_weapon and role ~= "Innocent" and holdingWeapon then
            local weapon = role == "Murderer" and "Knife" or "Gun" 
            draw.TextOutlined(weapon, boundingBox.x + boundingBox.w + 4, boundingBox.y + 8, Color3.new(1, 1, 1), "SmallestPixel")
        end

        ::continue::
    end
end

local function updateMisc() 
    isMM2 = (game.PlaceId == 142823291 or game.PlaceId == 136333311210714 or game.PlaceId == 134955552969606)
    if not isMM2 then return end
    Workspace = game.Workspace
    Players = game.GetService("Players")
end

cheat.Register("onUpdate", getPlayers)
cheat.Register("onSlowUpdate", updateMisc)
cheat.Register("onPaint", paintPlayers)
