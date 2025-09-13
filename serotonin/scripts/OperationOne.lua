-- Operation One - Gadget ESP
-- game: https://www.roblox.com/games/72920620366355/Operation-One-MAP-CHANGES
-- github: https://github.com/whoswhip/luascripts/blob/main/serotonin/scripts/OperationOne.lua
-- made by: whoswhip

local data = {
    gadget_names = {
        RemoteC4 = false,
        FragGrenade = false,
        Drone = false,
        SmokeGrenade = false,
        StunGrenade = false,
        BreachCharge = false,
        Claymore = false,
        EMPGrenade = false,
        ImpactGrenade = false,
        ProximityAlarm = false,
        IncendiaryGrenade = false,
        HardBreacher = false,
        DeployableShield = false,
        BarbedWire = false,
        BulletproofCamera = false
    },
    gadgets = {},
    enemies = {},
    ui = {
        only_enemies = true,
        show_owner = true
    }
}

local gadget_list = {
    'RemoteC4',
    'FragGrenade',
    'Drone',
    'SmokeGrenade',
    'StunGrenade',
    'BreachCharge',
    'Claymore',
    'EMPGrenade',
    'ImpactGrenade',
    'ProximityAlarm',
    'IncendiaryGrenade',
    'HardBreacher',
    'DeployableShield',
    'BarbedWire',
    'BulletproofCamera'
}

ui.new_tab('op1', 'Operation One')
ui.new_container('op1', 'gdtesp', 'Gadget ESP')
ui.new_checkbox('op1', 'gdtesp', 'Only Show Enemies')
ui.new_checkbox('op1', 'gdtesp', 'Show Owner')
ui.new_multiselect('op1', 'gdtesp', 'Activated Gadgets', gadget_list)
ui.new_button('op1', 'gdtesp', 'Select All Gadgets', function()
    local all_selected = {}
    for i = 1, #gadget_list do
        all_selected[i] = true
    end
    ui.set_value('op1', 'gdtesp', 'Activated Gadgets', all_selected)
end)

local function update_ui()
    data.ui.only_enemies = ui.get_value('op1', 'gdtesp', 'Only Show Enemies')
    data.ui.show_owner = ui.get_value('op1', 'gdtesp', 'Show Owner')

    local activated = ui.get_value('op1', 'gdtesp', 'Activated Gadgets')
    for gadget, _ in pairs(data.gadget_names) do
        data.gadget_names[gadget] = false
    end
    for index, selected in pairs(activated) do
        if selected then
            local gadget = gadget_list[index]
            if gadget then
                data.gadget_names[gadget] = true
            end
        end
    end
end

local function cache_gadgets()
    data.gadgets = {}
    data.enemies = entity.get_players(true)
    for _, gadget in pairs(game.workspace:GetChildren()) do
        if data.gadget_names[gadget.Name] then
            local username = nil
            if gadget:FindFirstChild('Owner') and gadget.Owner:FindFirstChild('Username') then
                username = gadget.Owner.Username.Value or 'Unknown'
            else
                username = 'Unknown'
            end
            if data.ui.only_enemies then
                local is_enemy = false
                for _, enemy in pairs(data.enemies) do
                    if enemy.Name == username then
                        is_enemy = true
                        break
                    end
                end
                if not is_enemy then
                    goto continue
                end
            end

            local gadget_data = {
                Owner = username,
                Gadget = gadget
            }
            table.insert(data.gadgets, gadget_data)
        end
        ::continue::
    end
end



local function paint()
    for _, gadget in pairs(data.gadgets) do 
        if not gadget.Gadget.Root then
            goto continue
        end
        local corners = draw.get_part_corners(gadget.Gadget.Root)
        local screen_points = {}
        for _, corner in pairs(corners) do
            local sx, sy, visible = utility.world_to_screen(corner)
            if visible then
                table.insert(screen_points, {sx, sy})
            end
        end
        if #screen_points >= 3 then
            local hull = draw.compute_convex_hull(screen_points)
            if hull and #hull > 2 then
                draw.Polyline(hull, Color3.fromRGB(255, 0, 0), true, 2)
                draw.convex_poly_filled(hull, Color3.fromRGB(255, 0, 0), 92)
                local txWidth = draw.get_text_size(gadget.Owner, "SmallestPixel")
                local nameWidth = draw.get_text_size(gadget.Gadget.Name, "SmallestPixel")
                local center = gadget.Gadget.Root.Position
                local sx, sy, visible = utility.world_to_screen(center)
                if visible then
                    draw.text_outlined(gadget.Gadget.Name, sx - (nameWidth / 2), sy - 15, Color3.fromRGB(255, 255, 255), "SmallestPixel")
                    if data.ui.show_owner and gadget.Owner ~= 'Unknown' then
                        draw.text_outlined(gadget.Owner, sx - (txWidth / 2), sy - 5, Color3.fromRGB(255, 255, 255), "SmallestPixel")
                    end
                end
            end
        end
        ::continue::
    end
end

cheat.register('onUpdate', function()
    update_ui()
    cache_gadgets()
end)
cheat.register('onPaint', paint)