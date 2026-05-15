--[[
    word hunt solver, based off of taylor's (befia) script

    game: https://roblox.com/games/123117601553923/WORD-HUNT
    github: https://github.com/whoswhip/luascripts/blob/main/serotonin/scripts/Word_Hunt.lua
    original: https://discord.com/channels/1388071156032077906/1500707801650171904/1500707801650171904
    made by: whoswhip
]]

--region constants
local WORD_LIST_URL = "https://raw.githubusercontent.com/whoswhip/luascripts/refs/heads/main/serotonin/assets/words.txt"

local BASE_W, BASE_H = 2560, 1440

local GRID_SIZING = {
    [1] = { -- 100%
        GRID = {
            x = 761 / BASE_W,
            y = 176 / BASE_H,
        },
        TILE = {
            width = 198 / BASE_W,
            height = 198 / BASE_H,
        },
        GAP = {
            x = 85 / BASE_W,
            y = 85 / BASE_H,
        }
    },
    [2] = { -- 75%
        GRID = {
            x = 890 / BASE_W,
            y = 304 / BASE_H,
        },
        TILE = {
            width = 150 / BASE_W,
            height = 150 / BASE_H,
        },
        GAP = {
            x = 59 / BASE_W,
            y = 59 / BASE_H,
        }
    },
    [3] = { -- 50%
        GRID = {
            x = 1019 / BASE_W,
            y = 434 / BASE_H,
        },
        TILE = {
            width = 100 / BASE_W,
            height = 100 / BASE_H,
        },
        GAP = {
            x = 40 / BASE_W,
            y = 40 / BASE_H,
        }
    },
}

local HTTP_HEADERS = {
    ["Accept"] = "*/*",
    ["User-Agent"] = "Serotonin-WordHunt/1.0"
}
--endregion

local config = {
    board = {
        size = 4,
        flip_columns = true,
        flip_rows = false,
        tile = {
            width_n = 150 / BASE_W,
            height_n = 150 / BASE_H,
            inner_padding = 20 / (BASE_H / BASE_H),
            circle_radius = 5 / (BASE_H / BASE_H),
        },
        sizing = 2,
    },
    overlay = {
        enabled = true,
        draw_best_path = true,
        best_path_color = Color3.new(0, 0, 1),
        best_path_start_color = Color3.new(0, 0, 1),
        best_path_middle_color = Color3.new(1, 1, 0),
        best_path_end_color = Color3.new(0, 1, 0),
        draw_tile_highlight = false,
    },
    -- wip
    -- auto_player = {
    --     enabled = false,
    --     keybind = 0x06,
    --     start_delay = 750,
    --     between_delay = 250,
    --     mouse_speed = 0.5,
    --     click_duration = 50,
    -- }
}

local state = {
    trie = nil,
    board = {},
    found_words = {},
    completed_words = {},
    best_path = {},
    selected_path = {},
    selected_set = {},
    screen_tiles = {},
    lmb_was_held = false,
}

--region word list
local function parse_word_list(raw)
    local list = {}
    for word in string.gmatch(raw or "", "%S+") do
        list[#list + 1] = word:lower()
    end
    return list
end

local function load_word_list()
    local raw = file.read("words.txt")

    if raw and raw ~= "" then
        print("Word list loaded from disk.")
        local list = parse_word_list(raw)
        print("Total words: " .. #list)
        return list
    end

    http.Get(WORD_LIST_URL, HTTP_HEADERS, function(body)
        if body and body ~= "" then
            file.write("words.txt", body)
            print("Word list downloaded and saved to disk.")
        else
            print("Failed to load word list.")
        end
    end)

    local fallback = file.read("words.txt") or ""
    local list = parse_word_list(fallback)
    print("Total words: " .. #list)
    return list
end

local word_list = load_word_list()
if not word_list or #word_list == 0 then
    error("Word list is empty.")
end
--endregion

--region ui

ui.newTab("whnt", "Word Hunt")
ui.newContainer("whnt", "overlay", "Overlay", { autosize = true, halfsize = true })
ui.newCheckbox("whnt", "overlay", "Enabled")
ui.newCheckbox("whnt", "overlay", "Draw Best Path")
ui.newColorpicker("whnt", "overlay", "Best Path Color", { r = 0, g = 0, b = 255, a=255}, true)
ui.newColorpicker("whnt", "overlay", "Best Path Start Color", { r = 0, g = 0, b = 255, a=255}, true)
ui.newColorpicker("whnt", "overlay", "Best Path Middle Color", { r = 255, g = 255, b = 0, a=255}, true)
ui.newColorpicker("whnt", "overlay", "Best Path End Color", { r = 0, g = 255, b = 0, a=255}, true)
ui.newCheckbox("whnt", "overlay", "Draw Tile Highlight")

ui.newContainer("whnt", "board", "Board", { autosize = true, halfsize = true, next = true })
ui.newDropdown("whnt", "board", "Grid Sizing", {"100%", "75%", "50%"}, 1)

ui.setValue("whnt", "overlay", "Enabled", config.overlay.enabled)
ui.setValue("whnt", "overlay", "Draw Best Path", config.overlay.draw_best_path)
ui.setValue("whnt", "overlay", "Draw Tile Highlight", config.overlay.draw_tile_highlight)

local function getColor3FromConfig(config_color)
    return Color3.new(
        (config_color.r or 0) / 255,
        (config_color.g or 0) / 255,
        (config_color.b or 0) / 255
    )
end

local function updateConfig()
    config.overlay.enabled = ui.getValue("whnt", "overlay", "Enabled")
    config.overlay.draw_best_path = ui.getValue("whnt", "overlay", "Draw Best Path")
    config.overlay.best_path_color = getColor3FromConfig(ui.getValue("whnt", "overlay", "Best Path Color"))
    config.overlay.best_path_start_color = getColor3FromConfig(ui.getValue("whnt", "overlay", "Best Path Start Color"))
    config.overlay.best_path_middle_color = getColor3FromConfig(ui.getValue("whnt", "overlay", "Best Path Middle Color"))
    config.overlay.best_path_end_color = getColor3FromConfig(ui.getValue("whnt", "overlay", "Best Path End Color"))
    config.overlay.draw_tile_highlight = ui.getValue("whnt", "overlay", "Draw Tile Highlight")

    local sizing_index = ui.getValue("whnt", "board", "Grid Sizing") + 1 or 1
    config.board.sizing = sizing_index
end

--endregion

--region board mapping
local function compute_tile_screen_positions()
    local sw, sh = cheat.getWindowSize()
    local positions = {}
    local sizing = GRID_SIZING[config.board.sizing] or GRID_SIZING[2]

    local tile_w = sizing.TILE.width * sw
    local tile_h = sizing.TILE.height * sh
    local start_x = sizing.GRID.x * sw
    local start_y = sizing.GRID.y * sh
    local step_x = tile_w + (sizing.GAP.x * sw)
    local step_y = tile_h + (sizing.GAP.y * sh)

    for i = 1, config.board.size do
        positions[i] = {}
        for j = 1, config.board.size do
            local physical_j = config.board.flip_columns and ((config.board.size + 1) - j) or j
            local physical_i = config.board.flip_rows and ((config.board.size + 1) - i) or i

            local x = start_x + (physical_j - 1) * step_x
            local y = start_y + (physical_i - 1) * step_y

            positions[i][j] = {
                x = x,
                y = y,
                w = tile_w,
                h = tile_h,
                center_x = x + tile_w * 0.5,
                center_y = y + tile_h * 0.5,
            }
        end
    end

    state.screen_tiles = positions
end

local function find_tile_at_screen_position(sx, sy)
    local sw, sh = cheat.getWindowSize()
    local padding = config.board.tile.inner_padding * math.min(sw / BASE_W, sh / BASE_H)
    for i = 1, config.board.size do
        for j = 1, config.board.size do
            local tile = state.screen_tiles[i][j]
            if tile and
                sx >= tile.x + padding and sx <= tile.x + tile.w - padding and
                sy >= tile.y + padding and sy <= tile.y + tile.h - padding then
                return i, j
            end
        end
    end
    return nil
end
--endregion

--region board reading
local function get_grid_frame()
    local lp = game.LocalPlayer
    if not lp then return nil end

    local gui = lp:FindFirstChild("PlayerGui")
    if not gui then return nil end

    local screen_gui = gui:FindFirstChild("ScreenGui")
    if not screen_gui then return nil end

    return screen_gui:FindFirstChild("PiecesFrame")
end

local function read_tile(tile)
    local text_label = tile:FindFirstChild("TextLabel")
    if text_label and text_label:IsA("TextLabel") then
        return text_label.Value:lower()
    end
    return nil
end

local function read_board()
    local frame = get_grid_frame()
    if not frame then return nil end

    local board = {}
    local children = frame:GetChildren()
    local tile_index = 1

    for i = 1, config.board.size do
        board[i] = {}
        for j = config.board.size, 1, -1 do
            while tile_index <= #children and not children[tile_index]:IsA("ImageButton") do
                tile_index = tile_index + 1
            end

            local tile = children[tile_index]
            if tile and tile:IsA("ImageButton") then
                board[i][j] = read_tile(tile)
                tile_index = tile_index + 1
            else
                board[i][j] = nil
            end
        end
    end

    return board
end
--endregion

--region solver
local function build_trie(words)
    local root = {}

    for _, word in ipairs(words) do
        local node = root
        for i = 1, #word do
            local c = word:sub(i, i)
            local next_node = node[c]
            if not next_node then
                next_node = {}
                node[c] = next_node
            end
            node = next_node
        end
        node.word = word
    end

    return root
end

local function solve_board(board, trie, size)
    local found = {}
    local best_path = nil
    local best_len = 0

    local path_i = {}
    local path_j = {}

    local function dfs(i, j, node, depth)
        if i < 1 or i > size or j < 1 or j > size then return end

        local row = board[i]
        local letter = row[j]
        if not letter then return end

        local next_node = node[letter]
        if not next_node then return end

        row[j] = nil
        depth = depth + 1
        path_i[depth] = i
        path_j[depth] = j

        local word = next_node.word
        if word and not found[word] then
            local pi, pj = {}, {}
            for k = 1, depth do
                pi[k] = path_i[k]
                pj[k] = path_j[k]
            end
            found[word] = { pi, pj }

            if depth > best_len then
                best_len = depth
                best_path = { pi, pj }
            end
        end

        dfs(i - 1, j - 1, next_node, depth)
        dfs(i - 1, j, next_node, depth)
        dfs(i - 1, j + 1, next_node, depth)
        dfs(i, j - 1, next_node, depth)
        dfs(i, j + 1, next_node, depth)
        dfs(i + 1, j - 1, next_node, depth)
        dfs(i + 1, j, next_node, depth)
        dfs(i + 1, j + 1, next_node, depth)

        row[j] = letter
    end

    for i = 1, size do
        local row = board[i]
        for j = 1, size do
            if row[j] then
                dfs(i, j, trie, 0)
            end
        end
    end

    return found, best_path
end
--endregion

--region path helpers
local function path_prefix_matches(path, selected_path)
    local selected_len = #selected_path
    if #path[1] < selected_len then
        return false
    end

    for i = 1, selected_len do
        if path[1][i] ~= selected_path[i][1] or path[2][i] ~= selected_path[i][2] then
            return false
        end
    end

    return true
end

local function path_equals_selection(path, selected_path)
    if #path[1] ~= #selected_path then
        return false
    end
    return path_prefix_matches(path, selected_path)
end

local function find_best_path_from_selection(selected_path)
    if not selected_path or #selected_path == 0 then return nil end

    local best = nil
    local best_len = 0

    for i = 1, #state.found_words do
        local result = state.found_words[i]
        if path_prefix_matches(result.path, selected_path) then
            local candidate_len = #result.path[1]
            if candidate_len > best_len then
                best = result
                best_len = candidate_len
            end
        end
    end

    return best
end

local function refresh_best_path()
    local best_path = nil
    local best_len = 0

    for i = 1, #state.found_words do
        local result = state.found_words[i]
        local path = result.path
        local path_len = #path[1]
        if path_len > best_len then
            best_len = path_len
            best_path = path
        end
    end

    state.best_path = best_path
end
--endregion

--region rendering
local function draw_board()
    if not state.screen_tiles or not state.screen_tiles[1] then return end
    local sw, sh = cheat.getWindowSize()
    local padding = config.board.tile.inner_padding * math.min(sw / BASE_W, sh / BASE_H)

    for i = 1, config.board.size do
        for j = 1, config.board.size do
            local pos = state.screen_tiles[i][j]
            if pos then
                draw.Rect(pos.x, pos.y, pos.w, pos.h, Color3.new(0, 0, 0), 2)

                draw.Rect(
                    pos.x + padding,
                    pos.y + padding,
                    pos.w - 2 * padding,
                    pos.h - 2 * padding,
                    Color3.new(1, 0, 0),
                    2
                )

                local tile = state.board and state.board[i] and state.board[i][j]
                if tile then
                    draw.TextOutlined(tile, pos.center_x, pos.center_y, Color3.new(1, 1, 1), "Verdana")
                end
            end
        end
    end
end

local function draw_path(path, color)
    if not path or not path[1] or #path[1] == 0 then return end

    for i = 1, #path[1] - 1 do
        local from = state.screen_tiles[path[1][i]] and state.screen_tiles[path[1][i]][path[2][i]]
        local to = state.screen_tiles[path[1][i + 1]] and state.screen_tiles[path[1][i + 1]][path[2][i + 1]]
        if from and to then
            draw.Line(from.center_x, from.center_y, to.center_x, to.center_y, color, 2)
        end
    end
end

local function draw_best_path_markers(path)
    if not path or not path[1] or #path[1] == 0 then return end

    local sw, sh = cheat.getWindowSize()
    local radius = config.board.tile.circle_radius * (sw / sh)

    for i = 1, #path[1] do
        local tile = state.screen_tiles[path[1][i]] and state.screen_tiles[path[1][i]][path[2][i]]
        if tile then
            local color = config.overlay.best_path_middle_color or Color3.new(1, 1, 0)
            if i == 1 then
                color = config.overlay.best_path_start_color or Color3.new(0, 0, 1)
            elseif i == #path[1] then
                color = config.overlay.best_path_end_color or Color3.new(0, 1, 0)
            end
            draw.CircleFilled(tile.center_x, tile.center_y, radius, color, 50)
        end
    end
end

local function resolve_overlay_path()
    if state.selected_path and #state.selected_path > 0 then
        local best_from_selection = find_best_path_from_selection(state.selected_path)
        return best_from_selection and best_from_selection.path or nil
    end

    if state.best_path and state.best_path[1] and state.best_path[2] then
        return state.best_path
    end

    return nil
end

local function paint()
    if not config.overlay.enabled then return end
    if config.overlay.draw_tile_highlight then
        draw_board()
    end

    if config.overlay.draw_best_path then
        local path = resolve_overlay_path()
        if path then
            draw_path(path, config.overlay.best_path_color)
            draw_best_path_markers(path)
        end
    end
end
--endregion

--region selection and updates
local function clear_selection()
    state.selected_path = {}
    state.selected_set = {}
end

local function add_selection_tile(r, c)
    local key = r .. "," .. c
    state.selected_set[key] = true
    state.selected_path[#state.selected_path + 1] = { r, c }
end

local function truncate_selection_to(r, c)
    for i = 1, #state.selected_path do
        local step = state.selected_path[i]
        if step[1] == r and step[2] == c then
            while #state.selected_path > i do
                local last = state.selected_path[#state.selected_path]
                state.selected_set[last[1] .. "," .. last[2]] = nil
                table.remove(state.selected_path)
            end
            return
        end
    end
end

local function complete_selected_word_if_matched()
    if not state.lmb_was_held or #state.selected_path == 0 then
        return
    end

    for i = 1, #state.found_words do
        local result = state.found_words[i]
        if path_equals_selection(result.path, state.selected_path) then
            state.completed_words[result.word] = true
            table.remove(state.found_words, i)
            refresh_best_path()
            return
        end
    end
end

local function track_mouse()
    if not state.screen_tiles or not state.screen_tiles[1] then return end

    local lmb = keyboard.IsPressed(0x01)
    local mouse = utility.GetMousePos()
    local mx = mouse and mouse[1]
    local my = mouse and mouse[2]

    if not lmb then
        complete_selected_word_if_matched()
        clear_selection()
        state.lmb_was_held = false
        return
    end

    if not mx or not my then return end

    local r, c = find_tile_at_screen_position(mx, my)
    if not r then
        state.lmb_was_held = lmb
        return
    end

    if not state.lmb_was_held then
        clear_selection()
        add_selection_tile(r, c)
        state.lmb_was_held = lmb
        return
    end

    local key = r .. "," .. c
    if state.selected_set[key] then
        truncate_selection_to(r, c)
        state.lmb_was_held = lmb
        return
    end

    if #state.selected_path > 0 then
        local last = state.selected_path[#state.selected_path]
        if math.abs(r - last[1]) <= 1 and math.abs(c - last[2]) <= 1 then
            add_selection_tile(r, c)
        end
    end

    state.lmb_was_held = lmb
end

local function has_board_changed(next_board)
    if not state.board or not state.board[1] then
        return true
    end

    return next_board[1][1] ~= state.board[1][1]
end

local function slowUpdate()
    local board = read_board()
    if not board then return end
    if not has_board_changed(board) then return end

    state.board = board
    state.trie = build_trie(word_list)

    local found, best_path = solve_board(board, state.trie, config.board.size)
    state.found_words = {}
    for word, path in pairs(found) do
        state.found_words[#state.found_words + 1] = { word = word, path = path }
    end
    state.best_path = best_path
end
--endregion


cheat.Register("onUpdate", function()
    updateConfig()
    if not utility.GetMenuState() then
        track_mouse()
    end
    compute_tile_screen_positions()
end)

cheat.Register("onSlowUpdate", function()
    slowUpdate()
end)

cheat.Register("onPaint", function()
    paint()
end)
