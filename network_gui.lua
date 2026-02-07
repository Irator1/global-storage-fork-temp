local constants = require("constants")
local state = require("state")
local network_module = require("network")
local quality = require("quality")

local M = {}

local GUI = constants.GUI

--- Format a quantity with k/M suffixes for compact display
---@param qty number
---@return string
local function format_quantity(qty)
    if not qty or qty == 0 then return "0" end
    if qty >= 1000000 then
        return string.format("%.1fM", qty / 1000000)
    elseif qty >= 1000 then
        return string.format("%.1fk", qty / 1000)
    else
        return tostring(qty)
    end
end

--- Get limit display string
---@param item_name string
---@return string
local function get_limit_string(item_name)
    local limit = storage.limits[item_name]
    if limit == constants.UNLIMITED then
        return "[color=green]∞[/color]"  -- infinity symbol, green
    elseif limit and limit > 0 then
        return "[color=yellow]" .. format_quantity(limit) .. "[/color]"
    else
        return "[color=red]0[/color]"  -- blocked
    end
end

--- Get formatted quantity string for HUD
---@param item_name string
---@param color string|nil Optional color for rich text (e.g., "red")
---@return string
local function format_hud_quantity(item_name, color)
    local quantity = storage.inventory[item_name] or 0
    local text = format_quantity(quantity)
    if color then
        return "[color=" .. color .. "]" .. text .. "[/color]"
    end
    return text
end

--- Get formatted limit string for HUD
---@param item_name string
---@param color string|nil Optional color for rich text (e.g., "red")
---@return string
local function format_hud_limit(item_name, color)
    local limit = storage.limits[item_name]
    local text
    if limit == constants.UNLIMITED then
        text = "∞"
    elseif limit and limit > 0 then
        text = format_quantity(limit)
    else
        text = "0"
    end
    if color then
        return "[color=" .. color .. "]" .. text .. "[/color]"
    end
    return text
end

--- Create the network management GUI
---@param player LuaPlayer
function M.create(player)
    -- Destroy existing GUI if any
    M.destroy(player)

    -- Main frame
    local frame = player.gui.screen.add({
        type = "frame",
        name = GUI.NETWORK_FRAME,
        caption = { "gui.global-network-title" },
        direction = "vertical"
    })
    frame.auto_center = true
    frame.style.minimal_width = 550
    frame.style.maximal_width = 700

    -- Tabbed pane
    local tabbed_pane = frame.add({
        type = "tabbed-pane",
        name = GUI.NETWORK_TABS
    })

    -- Networks tab
    local networks_tab = tabbed_pane.add({
        type = "tab",
        name = GUI.NETWORKS_TAB,
        caption = { "gui.networks-tab" }
    })
    local networks_content = tabbed_pane.add({
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding"
    })
    tabbed_pane.add_tab(networks_tab, networks_content)

    M.build_networks_tab(networks_content, player)

    -- Inventory tab
    local inventory_tab = tabbed_pane.add({
        type = "tab",
        name = GUI.INVENTORY_TAB,
        caption = { "gui.inventory-tab" }
    })
    local inventory_content = tabbed_pane.add({
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding"
    })
    tabbed_pane.add_tab(inventory_tab, inventory_content)

    M.build_inventory_tab(inventory_content, player)

    -- Player logistics tab
    local player_tab = tabbed_pane.add({
        type = "tab",
        name = GUI.PLAYER_LOGISTICS_TAB,
        caption = { "gui.player-logistics-tab" }
    })
    local player_content = tabbed_pane.add({
        type = "frame",
        direction = "vertical",
        style = "inside_shallow_frame_with_padding"
    })
    tabbed_pane.add_tab(player_tab, player_content)

    M.build_player_logistics_tab(player_content, player)

    player.opened = frame
end

--- Build the networks tab content
---@param parent LuaGuiElement
---@param player LuaPlayer
function M.build_networks_tab(parent, player)
    -- Scroll pane
    local scroll = parent.add({
        type = "scroll-pane",
        name = GUI.NETWORKS_SCROLL,
        direction = "vertical"
    })
    scroll.style.maximal_height = 600

    -- Networks table
    local networks_table = scroll.add({
        type = "table",
        name = GUI.NETWORKS_TABLE,
        column_count = 6,
        draw_horizontal_lines = true
    })

    -- Header
    networks_table.add({ type = "label", caption = { "gui.network-name" }, style = "bold_label" })
    networks_table.add({ type = "label", caption = { "gui.requests-count" }, style = "bold_label" })
    networks_table.add({ type = "label", caption = { "gui.chests-count" }, style = "bold_label" })
    networks_table.add({ type = "label", caption = { "gui.gn-status" }, style = "bold_label" })
    networks_table.add({ type = "label", caption = { "gui.gn-buffers" }, style = "bold_label" })
    networks_table.add({ type = "label", caption = "", style = "bold_label" })

    -- Initialize element cache for this player
    local pdata = state.get_player_data(player.index)
    pdata.network_element_cache = {}

    -- Network rows
    for network_name, network in pairs(storage.networks) do
        local request_count = 0
        for _ in pairs(network.requests) do
            request_count = request_count + 1
        end

        local chest_count = network.chest_count or 0
        local is_ghost = chest_count == 0

        -- Network name (truncated with tooltip for long names)
        local name_label = networks_table.add({
            type = "label",
            name = "gn_net_name_" .. network_name,
            caption = network_name,
            tooltip = network_name
        })
        name_label.style.maximal_width = 250

        -- Requests count
        local reqs_label = networks_table.add({
            type = "label",
            name = GUI.NETWORK_REQUEST_COUNT_LABEL .. network_name,
            caption = tostring(request_count)
        })

        -- Chests count
        local chests_label = networks_table.add({
            type = "label",
            name = GUI.NETWORK_CHEST_COUNT_LABEL .. network_name,
            caption = tostring(chest_count)
        })

        -- Status
        local status_label = networks_table.add({
            type = "label",
            name = GUI.NETWORK_STATUS_LABEL .. network_name,
            caption = is_ghost and { "gui.gn-status-ghost" } or { "gui.gn-status-active" }
        })
        status_label.style.font_color = is_ghost and { r = 1, g = 0.5, b = 0 } or { r = 0, g = 1, b = 0 }

        -- Buffer count with [+] and [-] buttons
        local buffer_count = network.buffer_count or 1
        local buf_flow = networks_table.add({
            type = "flow",
            direction = "horizontal"
        })
        buf_flow.style.vertical_align = "center"
        if buffer_count > 1 then
            local rem_btn = buf_flow.add({
                type = "button",
                name = GUI.NETWORK_BUFFER_REMOVE_BUTTON .. "_" .. network_name,
                caption = "-",
                tooltip = { "gui.gn-buffer-remove-tooltip" },
                style = "mini_button",
                tags = { network_name = network_name }
            })
            rem_btn.style.width = 24
            rem_btn.style.height = 24
            rem_btn.style.padding = 0
        end
        local buf_label = buf_flow.add({
            type = "label",
            name = GUI.NETWORK_BUFFER_LABEL .. "_" .. network_name,
            caption = "×" .. buffer_count
        })
        if buffer_count < constants.MAX_BUFFER_COUNT then
            local add_btn = buf_flow.add({
                type = "button",
                name = GUI.NETWORK_BUFFER_ADD_BUTTON .. "_" .. network_name,
                caption = "+",
                tooltip = { "gui.gn-buffer-add-tooltip" },
                style = "mini_button",
                tags = { network_name = network_name }
            })
            add_btn.style.width = 24
            add_btn.style.height = 24
            add_btn.style.padding = 0
        end

        -- Cache element references for live updates
        pdata.network_element_cache[network_name] = {
            chest_count_label = chests_label,
            request_count_label = reqs_label,
            status_label = status_label,
            buffer_label = buf_label
        }

        -- Delete button (not for default network)
        if network_name ~= constants.DEFAULT_NETWORK_NAME then
            networks_table.add({
                type = "sprite-button",
                name = GUI.NETWORK_DELETE_BUTTON .. "_" .. network_name,
                sprite = "utility/trash",
                tooltip = { "gui.delete-network" },
                style = "tool_button_red",
                tags = { network_name = network_name }
            })
        else
            -- Empty cell to maintain table alignment
            networks_table.add({ type = "empty-widget" })
        end
    end

    if not next(storage.networks) then
        parent.add({
            type = "label",
            caption = { "gui.no-networks" }
        })
    end
end

--- Build the inventory tab content (grid view)
---@param parent LuaGuiElement
---@param player LuaPlayer
function M.build_inventory_tab(parent, player)
    local pdata = state.get_player_data(player.index)

    -- Filter checkbox + hint
    local filter_flow = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    filter_flow.style.vertical_align = "center"
    filter_flow.add({
        type = "checkbox",
        name = GUI.INVENTORY_FILTER_NO_LIMIT_CHECKBOX,
        caption = { "gui.filter-no-limit" },
        state = pdata.filter_no_limit or false,
        tooltip = { "gui.filter-no-limit-tooltip" }
    })
    local hint = filter_flow.add({
        type = "label",
        caption = { "gui.grid-hint" }
    })
    hint.style.left_margin = 20
    hint.style.font_color = { r = 0.7, g = 0.7, b = 0.7 }

    -- Scroll pane
    local scroll = parent.add({
        type = "scroll-pane",
        name = GUI.INVENTORY_SCROLL,
        direction = "vertical"
    })
    scroll.style.maximal_height = 600
    scroll.style.minimal_width = 520

    -- Inventory grid (10 columns)
    local grid = scroll.add({
        type = "table",
        name = GUI.INVENTORY_GRID,
        column_count = 10
    })
    grid.style.horizontal_spacing = 2
    grid.style.vertical_spacing = 2

    -- Collect all items (from inventory and limits)
    local all_items = {}
    for item_name in pairs(storage.inventory) do
        all_items[item_name] = true
    end
    for item_name in pairs(storage.limits) do
        all_items[item_name] = true
    end

    -- Sort items
    local sorted_items = {}
    for item_name in pairs(all_items) do
        sorted_items[#sorted_items + 1] = item_name
    end
    table.sort(sorted_items)

    -- Apply filter if checkbox is checked (show only items with limit == 0)
    if pdata.filter_no_limit then
        local filtered_items = {}
        for _, item_name in ipairs(sorted_items) do
            local limit = storage.limits[item_name]
            if limit == nil or limit == 0 then
                filtered_items[#filtered_items + 1] = item_name
            end
        end
        sorted_items = filtered_items
    end

    -- Initialize grid cache
    pdata.inventory_grid_cache = {}

    -- Add grid cells for each item
    for _, item_name in ipairs(sorted_items) do
        M.add_grid_cell(grid, item_name, pdata)
    end

    -- Add limit section
    parent.add({ type = "line" })
    local add_flow = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    add_flow.style.vertical_align = "center"
    add_flow.add({
        type = "label",
        caption = { "gui.add-limit" }
    })
    add_flow.add({
        type = "choose-elem-button",
        name = GUI.INVENTORY_ADD_LIMIT_BUTTON,
        elem_type = "item-with-quality"
    })
end

--- Add a single cell to the inventory grid
---@param grid LuaGuiElement
---@param item_key string Composite key (e.g. "iron-plate" or "iron-plate:rare")
---@param pdata table Player data
function M.add_grid_cell(grid, item_key, pdata)
    local quantity = storage.inventory[item_key] or 0
    local limit = storage.limits[item_key]
    local is_pinned = pdata.pinned_items[item_key] or false

    local base_name = quality.get_name(item_key)
    local item_quality = quality.get_quality(item_key)

    -- Cell container
    local cell = grid.add({
        type = "flow",
        direction = "vertical"
    })
    cell.style.width = 46
    cell.style.horizontal_align = "center"

    -- Build tooltip with status info
    local status_text
    if limit == constants.UNLIMITED then
        status_text = "[color=green]Unlimited[/color]"
    elseif limit and limit > 0 then
        status_text = "[color=yellow]Limit: " .. format_quantity(limit) .. "[/color]"
    else
        status_text = "[color=red]Blocked[/color]"
    end

    local display_name = quality.tooltip(item_key)

    -- Item button (clickable to open popup)
    local button = cell.add({
        type = "sprite-button",
        name = GUI.INVENTORY_GRID_CELL .. quality.gui_name(item_key),
        sprite = "item/" .. base_name,
        tooltip = display_name .. "\n" .. status_text .. (is_pinned and "\n[Pinned]" or "") .. "\nClick to edit",
        tags = { item_key = item_key },
        style = "slot_button"
    })
    button.style.size = 40

    -- Native quality indicator (small icon in bottom-left corner)
    if item_quality ~= "normal" then
        button.quality = item_quality
    end

    -- Quantity label (compact)
    local qty_label = cell.add({
        type = "label",
        caption = format_quantity(quantity)
    })
    qty_label.style.font = "default-small-bold"

    -- Limit label (compact)
    local limit_label = cell.add({
        type = "label",
        caption = get_limit_string(item_key)
    })
    limit_label.style.font = "default-small"
    limit_label.style.rich_text_setting = defines.rich_text_setting.enabled

    -- Cache references for live updates
    pdata.inventory_grid_cache[item_key] = {
        button = button,
        qty_label = qty_label,
        limit_label = limit_label
    }
end

--- Rebuild the inventory tab content (for filter changes)
---@param player LuaPlayer
function M.rebuild_inventory_tab(player)
    local frame = player.gui.screen[GUI.NETWORK_FRAME]
    if not frame then return end

    local tabs = frame[GUI.NETWORK_TABS]
    if not tabs then return end

    -- Find the inventory content frame (2nd tab content)
    local inventory_content = nil
    for _, child in pairs(tabs.children) do
        if child.type == "frame" then
            -- Check if this frame has the inventory scroll
            local scroll = child[GUI.INVENTORY_SCROLL]
            if scroll then
                inventory_content = child
                break
            end
        end
    end

    if not inventory_content then return end

    -- Clear and rebuild
    inventory_content.clear()
    M.build_inventory_tab(inventory_content, player)
end

--- Rebuild the networks tab content (e.g., after buffer count change)
---@param player LuaPlayer
function M.rebuild_networks_tab(player)
    local frame = player.gui.screen[GUI.NETWORK_FRAME]
    if not frame then return end

    local tabs = frame[GUI.NETWORK_TABS]
    if not tabs then return end

    -- Find the networks content frame (1st tab content)
    local networks_content = nil
    for _, child in pairs(tabs.children) do
        if child.type == "frame" then
            local scroll = child[GUI.NETWORKS_SCROLL]
            if scroll then
                networks_content = child
                break
            end
        end
    end

    if not networks_content then return end

    -- Clear and rebuild
    networks_content.clear()
    M.build_networks_tab(networks_content, player)
end

--- Build the player logistics tab content
---@param parent LuaGuiElement
---@param player LuaPlayer
function M.build_player_logistics_tab(parent, player)
    local player_data = state.get_player_data(player.index)

    -- Description
    parent.add({
        type = "label",
        caption = { "gui.player-logistics-description" }
    })

    parent.add({ type = "line" })

    -- Enable checkbox
    local enable_flow = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    enable_flow.style.vertical_align = "center"

    enable_flow.add({
        type = "checkbox",
        name = GUI.PLAYER_LOGISTICS_ENABLED_CHECKBOX,
        caption = { "gui.player-logistics-enabled" },
        state = player_data.logistics_enabled or false,
        tooltip = { "gui.player-logistics-enabled-tooltip" }
    })

    parent.add({ type = "line" })

    -- Auto-pin low stock checkbox
    local auto_pin_flow = parent.add({
        type = "flow",
        direction = "horizontal"
    })
    auto_pin_flow.style.vertical_align = "center"

    auto_pin_flow.add({
        type = "checkbox",
        name = GUI.AUTO_PIN_LOW_STOCK_CHECKBOX,
        caption = { "gui.auto-pin-low-stock" },
        state = player_data.auto_pin_low_stock_enabled or false,
        tooltip = { "gui.auto-pin-low-stock-tooltip" }
    })
end

--- Open the inventory edit popup for an item
---@param player LuaPlayer
---@param item_key string Composite key (e.g. "iron-plate" or "iron-plate:rare")
function M.open_inventory_edit_popup(player, item_key)
    -- Destroy existing popup
    M.destroy_inventory_edit_popup(player)

    local base_name = quality.get_name(item_key)
    local item_quality = quality.get_quality(item_key)
    local quantity = storage.inventory[item_key] or 0
    local limit = storage.limits[item_key]
    local is_unlimited = (limit == constants.UNLIMITED)
    local pdata = state.get_player_data(player.index)
    local is_pinned = pdata.pinned_items[item_key] or false

    -- Create popup
    local popup = player.gui.screen.add({
        type = "frame",
        name = GUI.INVENTORY_EDIT_POPUP,
        direction = "vertical",
        tags = { item_key = item_key }
    })
    popup.auto_center = true

    -- Title bar with item sprite
    local titlebar = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    titlebar.style.vertical_align = "center"
    titlebar.add({
        type = "sprite",
        sprite = "item/" .. base_name
    })
    local title_caption = quality.tooltip(item_key)
    titlebar.add({
        type = "label",
        caption = title_caption,
        style = "frame_title"
    })
    local spacer = titlebar.add({ type = "empty-widget" })
    spacer.style.horizontally_stretchable = true
    titlebar.add({
        type = "sprite-button",
        sprite = "utility/close",
        style = "close_button",
        tags = { action = "close_popup" }
    })

    local content = popup.add({
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    })

    -- Current stock (read-only)
    local stock_flow = content.add({ type = "flow", direction = "horizontal" })
    stock_flow.style.vertical_align = "center"
    stock_flow.add({ type = "label", caption = { "gui.current-stock" } })
    stock_flow.add({ type = "label", caption = tostring(quantity), style = "bold_label" })

    content.add({ type = "line" })

    -- Limit section
    local limit_flow = content.add({ type = "flow", direction = "horizontal" })
    limit_flow.style.vertical_align = "center"
    limit_flow.add({ type = "label", caption = { "gui.gn-limit" } })
    local limit_field = limit_flow.add({
        type = "textfield",
        name = GUI.INVENTORY_EDIT_LIMIT_FIELD,
        text = (limit and limit > 0) and tostring(limit) or "",
        numeric = true,
        allow_decimal = false,
        allow_negative = false,
        enabled = not is_unlimited,
        tags = { item_key = item_key }
    })
    limit_field.style.width = 100

    -- Unlimited checkbox
    local unlimited_flow = content.add({ type = "flow", direction = "horizontal" })
    unlimited_flow.style.vertical_align = "center"
    unlimited_flow.add({
        type = "checkbox",
        name = GUI.INVENTORY_EDIT_UNLIMITED_CB,
        caption = { "gui.gn-unlimited" },
        state = is_unlimited,
        tooltip = { "gui.unlimited-tooltip" },
        tags = { item_key = item_key }
    })

    content.add({ type = "line" })

    -- Pin checkbox
    local pin_flow = content.add({ type = "flow", direction = "horizontal" })
    pin_flow.style.vertical_align = "center"
    pin_flow.add({
        type = "checkbox",
        name = GUI.INVENTORY_EDIT_PIN_CB,
        caption = { "gui.pin-to-hud" },
        state = is_pinned,
        tooltip = { "gui.pin-to-hud-tooltip" },
        tags = { item_key = item_key }
    })

    -- Button row: Remove (left) and OK (right)
    local button_flow = popup.add({ type = "flow", direction = "horizontal" })
    button_flow.style.top_margin = 8
    button_flow.style.horizontal_align = "right"
    button_flow.add({
        type = "button",
        name = GUI.INVENTORY_EDIT_REMOVE,
        caption = { "gui.gn-remove-item" },
        style = "red_button",
        tooltip = { "gui.gn-remove-item-tooltip" },
        tags = { item_key = item_key }
    })
    local spacer2 = button_flow.add({ type = "empty-widget" })
    spacer2.style.horizontally_stretchable = true
    button_flow.add({
        type = "button",
        name = GUI.INVENTORY_EDIT_CONFIRM,
        caption = { "gui.gn-ok" },
        style = "confirm_button",
        tags = { item_key = item_key }
    })

    -- Set flag to prevent network GUI from being destroyed
    pdata.opening_inventory_popup = true

    player.opened = popup
end

--- Destroy the inventory edit popup
---@param player LuaPlayer
function M.destroy_inventory_edit_popup(player)
    local popup = player.gui.screen[GUI.INVENTORY_EDIT_POPUP]
    if popup then
        popup.destroy()
    end
end

--- Create or get the HUD frame for pinned items
---@param player LuaPlayer
---@return LuaGuiElement|nil
function M.get_or_create_hud(player)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]
    if frame then return frame end

    -- Create HUD frame
    frame = player.gui.left.add({
        type = "frame",
        name = GUI.PIN_HUD_FRAME,
        direction = "vertical"
    })
    frame.style.padding = 4

    -- Create manual section (vertical flow for rows)
    frame.add({
        type = "flow",
        name = GUI.PIN_HUD_MANUAL_SECTION,
        direction = "vertical"
    })

    -- Create auto section (hidden by default)
    local auto_section = frame.add({
        type = "flow",
        name = GUI.PIN_HUD_AUTO_SECTION,
        direction = "vertical"
    })
    auto_section.visible = false

    return frame
end

--- Remove the HUD frame completely
---@param player LuaPlayer
function M.destroy_hud(player)
    -- Destroy the main HUD frame if it exists
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]
    if frame and frame.valid then
        frame.destroy()
    end

    -- Also clear any cached references to prevent stale data
    local pdata = state.get_player_data(player.index)
    pdata.pin_hud_elements = {}
    pdata.auto_pin_hud_elements = {}
    pdata.auto_pinned_items = {}
end

--- Add an item to the HUD (manual section)
---@param player LuaPlayer
---@param item_name string
function M.add_item_to_hud(player, item_name)
    local pdata = state.get_player_data(player.index)
    local frame = M.get_or_create_hud(player)
    if not frame then return end

    local manual_section = frame[GUI.PIN_HUD_MANUAL_SECTION]
    if not manual_section then return end

    -- Check if already exists
    local safe_name = quality.gui_name(item_name)
    if manual_section[GUI.PIN_HUD_FLOW .. safe_name] then return end

    -- Create row flow
    local row = manual_section.add({
        type = "flow",
        name = GUI.PIN_HUD_FLOW .. safe_name,
        direction = "horizontal"
    })
    row.style.vertical_align = "center"

    local item_button = row.add({
        type = "sprite-button",
        sprite = "item/" .. quality.get_name(item_name),
        tooltip = quality.tooltip(item_name),
        style = "transparent_slot"
    })
    item_button.style.size = 24
    -- Native quality indicator
    local item_quality = quality.get_quality(item_name)
    if item_quality ~= "normal" then
        item_button.quality = item_quality
    end

    local qty_label = row.add({
        type = "label",
        name = GUI.PIN_HUD_LABEL .. safe_name .. "_qty",
        caption = format_hud_quantity(item_name)
    })
    qty_label.style.font = "default-semibold"
    qty_label.style.horizontal_align = "right"
    qty_label.style.width = 45

    local limit_label = row.add({
        type = "label",
        name = GUI.PIN_HUD_LABEL .. safe_name .. "_limit",
        caption = "/" .. format_hud_limit(item_name)
    })
    limit_label.style.font = "default-semibold"
    limit_label.style.rich_text_setting = defines.rich_text_setting.enabled
    limit_label.style.width = 50

    -- Cache references
    pdata.pin_hud_elements[item_name] = {
        row = row,
        qty_label = qty_label,
        limit_label = limit_label
    }
end

--- Remove an item from the HUD (manual section)
---@param player LuaPlayer
---@param item_name string
function M.remove_item_from_hud(player, item_name)
    local pdata = state.get_player_data(player.index)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]

    if frame then
        local manual_section = frame[GUI.PIN_HUD_MANUAL_SECTION]
        if manual_section then
            local safe_name = quality.gui_name(item_name)
            local row = manual_section[GUI.PIN_HUD_FLOW .. safe_name]
            if row then
                row.destroy()
            end
        end
    end

    pdata.pin_hud_elements[item_name] = nil

    -- Cleanup empty HUD if needed
    M.cleanup_empty_hud(player)
end

--- Calculate items with low stock (< 10% of their limit)
---@return table[] Array of { name = string, percentage = number }
local function calculate_low_stock_items()
    local low_stock = {}

    for item_name, limit in pairs(storage.limits) do
        -- Skip items without a proper limit (nil, 0, or unlimited)
        if limit and limit > 0 then
            local quantity = storage.inventory[item_name] or 0
            local percentage = quantity / limit

            if percentage < constants.LOW_STOCK_THRESHOLD then
                low_stock[#low_stock + 1] = {
                    name = item_name,
                    percentage = percentage
                }
            end
        end
    end

    -- Sort by lowest percentage first
    table.sort(low_stock, function(a, b) return a.percentage < b.percentage end)

    -- Limit to max items
    local result = {}
    for i = 1, math.min(#low_stock, constants.AUTO_PIN_MAX_ITEMS) do
        result[i] = low_stock[i]
    end

    return result
end


--- Add an item to the auto-pin section of the HUD
---@param player LuaPlayer
---@param item_name string
---@param percentage number Stock percentage (0-1)
function M.add_auto_pin_to_hud(player, item_name, percentage)
    local pdata = state.get_player_data(player.index)
    local frame = M.get_or_create_hud(player)
    if not frame then return end

    local auto_section = frame[GUI.PIN_HUD_AUTO_SECTION]
    if not auto_section then return end

    -- Create header if it doesn't exist
    if not auto_section[GUI.PIN_HUD_AUTO_HEADER] then
        local header = auto_section.add({
            type = "label",
            name = GUI.PIN_HUD_AUTO_HEADER,
            caption = { "gui.low-stock-header" }
        })
        header.style.font = "default-bold"
        header.style.rich_text_setting = defines.rich_text_setting.enabled
        header.style.top_margin = 4
    end

    -- Check if already exists
    local safe_name = quality.gui_name(item_name)
    if auto_section[GUI.AUTO_PIN_HUD_FLOW .. safe_name] then return end

    -- Create row flow
    local row = auto_section.add({
        type = "flow",
        name = GUI.AUTO_PIN_HUD_FLOW .. safe_name,
        direction = "horizontal"
    })
    row.style.vertical_align = "center"

    local item_button = row.add({
        type = "sprite-button",
        sprite = "item/" .. quality.get_name(item_name),
        tooltip = quality.tooltip(item_name) .. " (" .. string.format("%.0f%%", percentage * 100) .. ")",
        style = "transparent_slot"
    })
    item_button.style.size = 24
    -- Native quality indicator
    local item_quality = quality.get_quality(item_name)
    if item_quality ~= "normal" then
        item_button.quality = item_quality
    end

    local qty_label = row.add({
        type = "label",
        name = GUI.AUTO_PIN_HUD_LABEL .. safe_name .. "_qty",
        caption = format_hud_quantity(item_name, "red")
    })
    qty_label.style.font = "default-semibold"
    qty_label.style.horizontal_align = "right"
    qty_label.style.width = 45
    qty_label.style.rich_text_setting = defines.rich_text_setting.enabled

    local limit_label = row.add({
        type = "label",
        name = GUI.AUTO_PIN_HUD_LABEL .. safe_name .. "_limit",
        caption = "[color=red]/[/color]" .. format_hud_limit(item_name, "red")
    })
    limit_label.style.font = "default-semibold"
    limit_label.style.rich_text_setting = defines.rich_text_setting.enabled
    limit_label.style.width = 50

    -- Make section visible
    auto_section.visible = true

    -- Cache references
    pdata.auto_pin_hud_elements[item_name] = {
        row = row,
        qty_label = qty_label,
        limit_label = limit_label
    }
    pdata.auto_pinned_items[item_name] = true
end

--- Remove an item from the auto-pin section of the HUD
---@param player LuaPlayer
---@param item_name string
function M.remove_auto_pin_from_hud(player, item_name)
    local pdata = state.get_player_data(player.index)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]

    if frame then
        local auto_section = frame[GUI.PIN_HUD_AUTO_SECTION]
        if auto_section then
            local safe_name = quality.gui_name(item_name)
            local row = auto_section[GUI.AUTO_PIN_HUD_FLOW .. safe_name]
            if row then
                row.destroy()
            end

            -- Hide section if only header remains (or empty)
            local has_items = false
            for _, child in pairs(auto_section.children) do
                if child.name and child.name:find(GUI.AUTO_PIN_HUD_FLOW) then
                    has_items = true
                    break
                end
            end
            if not has_items then
                auto_section.visible = false
                local header = auto_section[GUI.PIN_HUD_AUTO_HEADER]
                if header then header.destroy() end
            end
        end
    end

    pdata.auto_pin_hud_elements[item_name] = nil
    pdata.auto_pinned_items[item_name] = nil

    -- Cleanup empty HUD if needed
    M.cleanup_empty_hud(player)
end

--- Clear all auto-pinned items from HUD
---@param player LuaPlayer
function M.clear_auto_pinned_hud(player)
    local pdata = state.get_player_data(player.index)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]

    if frame then
        local auto_section = frame[GUI.PIN_HUD_AUTO_SECTION]
        if auto_section then
            auto_section.clear()
            auto_section.visible = false
        end
    end

    pdata.auto_pin_hud_elements = {}
    pdata.auto_pinned_items = {}

    -- Cleanup empty HUD if needed
    M.cleanup_empty_hud(player)
end

--- Update auto-pinned items based on current inventory state
---@param player LuaPlayer
function M.update_auto_pinned_items(player)
    local pdata = state.get_player_data(player.index)
    if not pdata.auto_pin_low_stock_enabled then return end

    -- Calculate which items should be auto-pinned
    local low_stock_items = calculate_low_stock_items()
    local should_be_pinned = {}
    for _, item in ipairs(low_stock_items) do
        should_be_pinned[item.name] = item.percentage
    end

    -- Remove items that are no longer low stock
    for item_name in pairs(pdata.auto_pinned_items) do
        if not should_be_pinned[item_name] then
            M.remove_auto_pin_from_hud(player, item_name)
        end
    end

    -- Add new low stock items
    for item_name, percentage in pairs(should_be_pinned) do
        if not pdata.auto_pinned_items[item_name] then
            M.add_auto_pin_to_hud(player, item_name, percentage)
        end
    end
end

--- Check if HUD is empty and destroy it if so
---@param player LuaPlayer
function M.cleanup_empty_hud(player)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]
    if not frame then return end

    local manual_section = frame[GUI.PIN_HUD_MANUAL_SECTION]
    local auto_section = frame[GUI.PIN_HUD_AUTO_SECTION]

    local has_manual = manual_section and #manual_section.children > 0
    local has_auto = auto_section and auto_section.visible

    if not has_manual and not has_auto then
        frame.destroy()
    end
end

--- Update HUD quantities for a player (called periodically)
---@param player LuaPlayer
function M.update_pin_hud(player)
    local pdata = state.get_player_data(player.index)

    -- Check if HUD needs full refresh (flag set after load or structure mismatch)
    local frame = player.gui.left[GUI.PIN_HUD_FRAME]
    local needs_refresh = pdata.hud_needs_refresh

    -- Also check if existing HUD has correct structure
    if frame and frame.valid then
        local manual_section = frame[GUI.PIN_HUD_MANUAL_SECTION]
        if not manual_section or manual_section.type ~= "flow" then
            needs_refresh = true
        end
    end

    if needs_refresh then
        M.restore_pin_hud(player)
        pdata.hud_needs_refresh = false
        return
    end

    -- Update manual pins
    if pdata.pin_hud_elements and pdata.pinned_items then
        for item_name, elements in pairs(pdata.pin_hud_elements) do
            -- Check if elements have new structure (qty_label) and are valid
            if elements.qty_label and elements.qty_label.valid then
                elements.qty_label.caption = format_hud_quantity(item_name)
                if elements.limit_label and elements.limit_label.valid then
                    elements.limit_label.caption = "/" .. format_hud_limit(item_name)
                end
            else
                -- Element invalide ou ancien format: supprimer du cache
                pdata.pin_hud_elements[item_name] = nil
            end
        end

        -- Recreate missing items
        for item_name, is_pinned in pairs(pdata.pinned_items) do
            if is_pinned and not pdata.pin_hud_elements[item_name] then
                M.add_item_to_hud(player, item_name)
            end
        end
    end

    -- Update auto-pins if enabled
    if pdata.auto_pin_low_stock_enabled then
        M.update_auto_pinned_items(player)

        -- Update auto-pin labels
        if pdata.auto_pin_hud_elements then
            for item_name, elements in pairs(pdata.auto_pin_hud_elements) do
                if elements.qty_label and elements.qty_label.valid then
                    elements.qty_label.caption = format_hud_quantity(item_name, "red")
                    if elements.limit_label and elements.limit_label.valid then
                        elements.limit_label.caption = "[color=red]/[/color]" .. format_hud_limit(item_name, "red")
                    end
                end
            end
        end
    end
end

--- Restore HUD for a player (called on join)
---@param player LuaPlayer
function M.restore_pin_hud(player)
    -- Destroy existing HUD completely (also clears caches)
    M.destroy_hud(player)

    local pdata = state.get_player_data(player.index)

    -- Recreate HUD for all manually pinned items
    local has_pins = false
    if pdata.pinned_items then
        for item_name, is_pinned in pairs(pdata.pinned_items) do
            if is_pinned then
                M.add_item_to_hud(player, item_name)
                has_pins = true
            end
        end
    end

    -- Restore auto-pins if enabled
    if pdata.auto_pin_low_stock_enabled then
        M.update_auto_pinned_items(player)
        has_pins = has_pins or next(pdata.auto_pinned_items) ~= nil
    end

    -- Remove empty HUD frame
    if not has_pins then
        M.destroy_hud(player)
    end
end

--- Destroy the network GUI
---@param player LuaPlayer
---@param keep_confirm_popup boolean|nil If true, don't destroy confirmation popup
function M.destroy(player, keep_confirm_popup)
    local frame = player.gui.screen[GUI.NETWORK_FRAME]
    if frame then
        frame.destroy()
    end
    if not keep_confirm_popup then
        M.destroy_delete_confirm_popup(player)
    end
    M.destroy_inventory_edit_popup(player)

    -- Clear element caches
    local pdata = state.get_player_data(player.index)
    pdata.inventory_element_cache = nil
    pdata.network_element_cache = nil
    pdata.inventory_grid_cache = {}
end

--- Create confirmation popup for deleting a network with chests
---@param player LuaPlayer
---@param network_name string
---@param chest_count number
function M.create_delete_confirm_popup(player, network_name, chest_count)
    M.destroy_delete_confirm_popup(player)

    local popup = player.gui.screen.add({
        type = "frame",
        name = GUI.NETWORK_DELETE_CONFIRM_POPUP,
        caption = { "gui.delete-network-confirm-title" },
        direction = "vertical",
        tags = { network_name = network_name }
    })
    popup.auto_center = true

    -- Message
    local inner = popup.add({
        type = "frame",
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    })
    inner.add({
        type = "label",
        caption = { "gui.delete-network-confirm-message", network_name, chest_count }
    })
    inner.add({
        type = "label",
        caption = { "gui.delete-network-confirm-reassign" }
    })

    -- Buttons
    local button_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    button_flow.style.horizontal_spacing = 8
    button_flow.style.top_margin = 8

    button_flow.add({
        type = "button",
        name = GUI.NETWORK_DELETE_CONFIRM_YES,
        caption = { "gui.gn-delete-confirm" },
        style = "red_button",
        tags = { network_name = network_name }
    })
    button_flow.add({
        type = "button",
        name = GUI.NETWORK_DELETE_CONFIRM_NO,
        caption = { "gui.gn-cancel" }
    })

    -- Set flag to prevent network GUI from being destroyed
    local pdata = state.get_player_data(player.index)
    pdata.opening_delete_confirm = true

    -- Set popup as opened (ESC will close popup first)
    player.opened = popup
end

--- Destroy the delete confirmation popup
---@param player LuaPlayer
function M.destroy_delete_confirm_popup(player)
    local popup = player.gui.screen[GUI.NETWORK_DELETE_CONFIRM_POPUP]
    if popup then
        popup.destroy()
    end
end

--- Actually delete a network and update the GUI
---@param player LuaPlayer
---@param network_name string
function M.do_delete_network(player, network_name)
    state.delete_network(network_name, player.force)

    -- Remove from element cache
    local pdata = state.get_player_data(player.index)
    if pdata.network_element_cache then
        pdata.network_element_cache[network_name] = nil
    end

    -- Rebuild the networks tab to reflect changes
    M.rebuild_networks_tab(player)
end

--- Refresh the network GUI (preserves position and selected tab)
---@param player LuaPlayer
function M.refresh(player)
    local frame = player.gui.screen[GUI.NETWORK_FRAME]
    if not frame then return end

    local player_data = state.get_player_data(player.index)
    if not player_data.opened_network_gui then return end

    -- Save current state
    local location = frame.location
    local tabs = frame[GUI.NETWORK_TABS]
    local selected_tab_index = tabs and tabs.selected_tab_index or 1

    -- Recreate the GUI
    M.create(player)

    -- Restore state
    local new_frame = player.gui.screen[GUI.NETWORK_FRAME]
    if new_frame then
        new_frame.location = location
        local new_tabs = new_frame[GUI.NETWORK_TABS]
        if new_tabs then
            new_tabs.selected_tab_index = selected_tab_index
        end
    end
end

--- Handle GUI events
---@param event EventData
function M.on_gui_event(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local tags = element.tags

    -- Delete network
    if tags and tags.network_name and element.name:find(GUI.NETWORK_DELETE_BUTTON) then
        local network_name = tags.network_name
        local network = storage.networks[network_name]
        local chest_count = network and network.chest_count or 0

        if chest_count > 0 then
            -- Show confirmation popup
            M.create_delete_confirm_popup(player, network_name, chest_count)
        else
            -- No chests, delete directly
            M.do_delete_network(player, network_name)
        end
        return
    end

    -- Add limit (item chosen)
    if element.name == GUI.INVENTORY_ADD_LIMIT_BUTTON then
        -- elem_value is a table {name=string, quality=string} for item-with-quality, or nil
        local item_key = quality.key_from_elem_value(element.elem_value)
        if item_key then
            -- Check if item already exists in the cache
            local pdata = state.get_player_data(player.index)
            local cache = pdata.inventory_grid_cache
            local existing = cache and cache[item_key]

            if not existing then
                -- Set default limit
                storage.limits[item_key] = 10000

                -- Add new cell to inventory grid
                local frame = player.gui.screen[GUI.NETWORK_FRAME]
                local grid = frame and M.find_element(frame, GUI.INVENTORY_GRID)
                if grid and grid.valid then
                    M.add_grid_cell(grid, item_key, pdata)
                end
            end
            element.elem_value = nil
        end
        return
    end
end

--- Handle click events
---@param event EventData.on_gui_click
function M.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end
    if not element.name then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local tags = element.tags

    -- Grid cell clicked - open edit popup
    if element.name:find(GUI.INVENTORY_GRID_CELL) then
        if tags and tags.item_key then
            M.open_inventory_edit_popup(player, tags.item_key)
        end
        return
    end

    -- Close popup button
    if tags and tags.action == "close_popup" then
        M.destroy_inventory_edit_popup(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
        return
    end

    -- Remove item from global inventory tracking
    if element.name == GUI.INVENTORY_EDIT_REMOVE then
        local item_key = tags and tags.item_key
        if item_key then
            -- Remove from all tracking tables
            storage.inventory[item_key] = nil
            storage.limits[item_key] = nil
            storage.previous_limits[item_key] = nil
            -- Remove pins and HUD elements for all players
            for _, pdata_entry in pairs(storage.player_data) do
                if pdata_entry.pinned_items then
                    pdata_entry.pinned_items[item_key] = nil
                end
                if pdata_entry.auto_pinned_items then
                    pdata_entry.auto_pinned_items[item_key] = nil
                end
                -- Destroy HUD elements if they exist
                if pdata_entry.pin_hud_elements and pdata_entry.pin_hud_elements[item_key] then
                    local elems = pdata_entry.pin_hud_elements[item_key]
                    if elems.flow and elems.flow.valid then elems.flow.destroy() end
                    pdata_entry.pin_hud_elements[item_key] = nil
                end
                if pdata_entry.auto_pin_hud_elements and pdata_entry.auto_pin_hud_elements[item_key] then
                    local elems = pdata_entry.auto_pin_hud_elements[item_key]
                    if elems.flow and elems.flow.valid then elems.flow.destroy() end
                    pdata_entry.auto_pin_hud_elements[item_key] = nil
                end
            end
        end
        M.destroy_inventory_edit_popup(player)
        M.rebuild_inventory_tab(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
        return
    end

    -- Confirm edit popup
    if element.name == GUI.INVENTORY_EDIT_CONFIRM then
        M.destroy_inventory_edit_popup(player)
        -- Rebuild inventory grid to show changes
        M.rebuild_inventory_tab(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
        return
    end

    -- Confirm delete with reassignment
    if element.name == GUI.NETWORK_DELETE_CONFIRM_YES then
        if tags and tags.network_name then
            local network_name = tags.network_name
            -- Reassign chests to default network
            state.reassign_network_chests(network_name, nil)
            -- Delete the network
            M.do_delete_network(player, network_name)
        end
        M.destroy_delete_confirm_popup(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
        return
    end

    -- Cancel delete
    if element.name == GUI.NETWORK_DELETE_CONFIRM_NO then
        M.destroy_delete_confirm_popup(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
        return
    end

    -- Buffer add button
    if element.name:find(GUI.NETWORK_BUFFER_ADD_BUTTON) then
        if tags and tags.network_name then
            local network_name = tags.network_name
            local network = storage.networks[network_name]
            if network then
                local current = network.buffer_count or 1
                if current < constants.MAX_BUFFER_COUNT then
                    state.set_network_buffer_count(network_name, current + 1)
                    -- Rebuild the networks tab to reflect the change
                    M.rebuild_networks_tab(player)
                end
            end
        end
        return
    end

    -- Buffer remove button
    if element.name:find(GUI.NETWORK_BUFFER_REMOVE_BUTTON) then
        if tags and tags.network_name then
            local network_name = tags.network_name
            local network = storage.networks[network_name]
            if network then
                local current = network.buffer_count or 1
                if current > 1 then
                    state.remove_network_buffer(network_name)
                    M.rebuild_networks_tab(player)
                end
            end
        end
        return
    end

    -- Delete network button
    if element.name:find(GUI.NETWORK_DELETE_BUTTON) then
        M.on_gui_event(event)
        return
    end
end

--- Handle text changed events
---@param event EventData.on_gui_text_changed
function M.on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    if not element.name then return end

    -- Popup limit field
    if element.name == GUI.INVENTORY_EDIT_LIMIT_FIELD then
        local tags = element.tags
        if tags and tags.item_key then
            local value = tonumber(element.text)
            network_module.set_limit(tags.item_key, value)
        end
        return
    end
end

--- Handle elem changed events
---@param event EventData.on_gui_elem_changed
function M.on_gui_elem_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    if element.name ~= GUI.INVENTORY_ADD_LIMIT_BUTTON then return end

    M.on_gui_event(event)
end

--- Handle checkbox state changed events
---@param event EventData.on_gui_checked_state_changed
function M.on_gui_checked_state_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    if not element.name then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local tags = element.tags

    -- Player logistics enabled checkbox
    if element.name == GUI.PLAYER_LOGISTICS_ENABLED_CHECKBOX then
        local pdata = state.get_player_data(player.index)
        pdata.logistics_enabled = element.state
        return
    end

    -- Auto-pin low stock checkbox
    if element.name == GUI.AUTO_PIN_LOW_STOCK_CHECKBOX then
        local pdata = state.get_player_data(player.index)
        pdata.auto_pin_low_stock_enabled = element.state

        if element.state then
            -- Enable: calculate and display low stock items
            M.update_auto_pinned_items(player)
        else
            -- Disable: clear all auto-pinned items
            M.clear_auto_pinned_hud(player)
        end
        return
    end

    -- Inventory filter checkbox (show only items with no limit)
    if element.name == GUI.INVENTORY_FILTER_NO_LIMIT_CHECKBOX then
        local pdata = state.get_player_data(player.index)
        pdata.filter_no_limit = element.state
        -- Rebuild inventory tab to apply filter
        M.rebuild_inventory_tab(player)
        return
    end

    -- Popup unlimited checkbox
    if element.name == GUI.INVENTORY_EDIT_UNLIMITED_CB then
        if not tags or not tags.item_key then return end
        local item_key = tags.item_key
        local current_limit = storage.limits[item_key]

        -- Ensure previous_limits table exists
        storage.previous_limits = storage.previous_limits or {}

        -- Find the limit field in the popup
        local popup = player.gui.screen[GUI.INVENTORY_EDIT_POPUP]
        local limit_field = popup and M.find_element(popup, GUI.INVENTORY_EDIT_LIMIT_FIELD)

        if element.state then
            -- Checked: save current limit and set unlimited
            if current_limit and current_limit > 0 then
                storage.previous_limits[item_key] = current_limit
            end
            network_module.set_limit(item_key, constants.UNLIMITED)
            if limit_field and limit_field.valid then
                limit_field.enabled = false
                limit_field.text = ""
            end
        else
            -- Unchecked: restore previous limit or block
            local previous = storage.previous_limits[item_key]
            network_module.set_limit(item_key, previous)
            if limit_field and limit_field.valid then
                limit_field.enabled = true
                limit_field.text = previous and tostring(previous) or ""
            end
        end
        return
    end

    -- Popup pin checkbox
    if element.name == GUI.INVENTORY_EDIT_PIN_CB then
        if not tags or not tags.item_key then return end
        local item_key = tags.item_key
        local pdata = state.get_player_data(player.index)

        if element.state then
            -- Pin item to HUD
            pdata.pinned_items[item_key] = true
            M.add_item_to_hud(player, item_key)
        else
            -- Unpin item from HUD
            pdata.pinned_items[item_key] = nil
            M.remove_item_from_hud(player, item_key)
        end
        return
    end
end

--- Handle confirmed events (Enter key pressed in textfield)
---@param event EventData.on_gui_confirmed
function M.on_gui_confirmed(event)
    local element = event.element
    if not element or not element.valid then return end
    if not element.name then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    -- Enter pressed in popup limit field - close popup
    if element.name == GUI.INVENTORY_EDIT_LIMIT_FIELD then
        M.destroy_inventory_edit_popup(player)
        -- Rebuild inventory grid to show changes
        M.rebuild_inventory_tab(player)
        -- Reopen network GUI
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            local frame = player.gui.screen[GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
    end
end

--- Recursively find a GUI element by name
---@param parent LuaGuiElement
---@param name string
---@return LuaGuiElement|nil
function M.find_element(parent, name)
    if parent.name == name then return parent end
    for _, child in pairs(parent.children) do
        local found = M.find_element(child, name)
        if found then return found end
    end
    return nil
end

--- Update the GUI with live data (called periodically)
---@param player LuaPlayer
function M.update_live(player)
    local frame = player.gui.screen[GUI.NETWORK_FRAME]
    if not frame then return end

    local tabs = frame[GUI.NETWORK_TABS]
    if not tabs then return end

    local pdata = state.get_player_data(player.index)
    local selected_tab = tabs.selected_tab_index

    -- Only update the currently visible tab
    if selected_tab == 2 then
        -- Update inventory grid quantities using cached references
        local cache = pdata.inventory_grid_cache
        if cache then
            for item_name, cached in pairs(cache) do
                local quantity = storage.inventory[item_name] or 0
                if cached.qty_label and cached.qty_label.valid then
                    cached.qty_label.caption = format_quantity(quantity)
                end
            end
        end
    elseif selected_tab == 1 then
        -- Update network tab using cached references
        local cache = pdata.network_element_cache
        if cache then
            for network_name, network in pairs(storage.networks) do
                local cached = cache[network_name]
                if cached then
                    -- Update chest count
                    if cached.chest_count_label and cached.chest_count_label.valid then
                        cached.chest_count_label.caption = tostring(network.chest_count or 0)
                    end

                    -- Update request count
                    local request_count = 0
                    for _ in pairs(network.requests) do request_count = request_count + 1 end
                    if cached.request_count_label and cached.request_count_label.valid then
                        cached.request_count_label.caption = tostring(request_count)
                    end

                    -- Update status
                    local is_ghost = (network.chest_count or 0) == 0
                    if cached.status_label and cached.status_label.valid then
                        cached.status_label.caption = is_ghost and { "gui.gn-status-ghost" } or { "gui.gn-status-active" }
                        cached.status_label.style.font_color = is_ghost and { r = 1, g = 0.5, b = 0 } or { r = 0, g = 1, b = 0 }
                    end
                end
            end
        end
    end

    -- Always update HUD (even if GUI is closed, update_pin_hud handles that)
    M.update_pin_hud(player)
end

return M
