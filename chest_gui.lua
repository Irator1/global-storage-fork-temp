local constants = require("constants")
local state = require("state")
local network_module = require("network")

local M = {}

local GUI = constants.GUI

--- Create the relative panel for a player (called once at player creation)
--- The panel will automatically show/hide when the vanilla linked container GUI opens/closes
---@param player LuaPlayer
function M.create_relative_panel(player)
    -- Destroy and recreate to ensure latest layout
    if player.gui.relative[GUI.CHEST_RELATIVE_PANEL] then
        player.gui.relative[GUI.CHEST_RELATIVE_PANEL].destroy()
    end

    -- Main frame anchored to the linked container GUI
    local frame = player.gui.relative.add({
        type = "frame",
        name = GUI.CHEST_RELATIVE_PANEL,
        caption = "Global Network",
        direction = "vertical",
        anchor = {
            gui = defines.relative_gui_type.linked_container_gui,
            position = defines.relative_gui_position.right,
            name = constants.GLOBAL_CHEST_ENTITY_NAME  -- Only show for our chest
        }
    })

    frame.style.minimal_width = 380

    -- Inner frame for content
    local inner = frame.add({
        type = "frame",
        name = GUI.CHEST_FRAME,
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    })

    -- === Network ID Section ===
    -- Display mode flow (shown by default)
    local display_flow = inner.add({
        type = "flow",
        name = GUI.CHEST_NETWORK_DISPLAY_FLOW,
        direction = "horizontal"
    })
    display_flow.style.vertical_align = "center"

    display_flow.add({
        type = "label",
        caption = "Network:"
    })

    local network_label = display_flow.add({
        type = "label",
        name = GUI.CHEST_NETWORK_ID_LABEL,
        caption = "[No network]"
    })
    network_label.style.font = "default-bold"
    network_label.style.left_margin = 4
    network_label.style.right_margin = 8

    display_flow.add({
        type = "button",
        name = GUI.CHEST_NETWORK_EDIT_BUTTON,
        caption = "Edit",
        style = "mini_button",
        tooltip = "Edit network ID"
    })

    -- Edit mode flow (hidden by default)
    local edit_flow = inner.add({
        type = "flow",
        name = GUI.CHEST_NETWORK_EDIT_FLOW,
        direction = "vertical"
    })
    edit_flow.visible = false

    -- Row 1: Label + textfield
    local edit_row1 = edit_flow.add({
        type = "flow",
        direction = "horizontal"
    })
    edit_row1.style.vertical_align = "center"

    edit_row1.add({
        type = "label",
        caption = "Network:"
    })

    local network_field = edit_row1.add({
        type = "textfield",
        name = GUI.CHEST_NETWORK_ID_FIELD,
        text = ""
    })
    network_field.style.width = 220

    -- Row 2: Buttons (Validate + Cancel)
    local edit_row2 = edit_flow.add({
        type = "flow",
        direction = "horizontal"
    })
    edit_row2.style.vertical_align = "center"
    edit_row2.style.horizontal_spacing = 8

    edit_row2.add({
        type = "button",
        name = GUI.CHEST_NETWORK_CONFIRM_BUTTON,
        caption = "Validate",
        style = "confirm_button"
    })

    edit_row2.add({
        type = "button",
        name = GUI.CHEST_NETWORK_CANCEL_BUTTON,
        caption = "Cancel"
    })

    -- Row 3: Network list
    local list_scroll = edit_flow.add({
        type = "scroll-pane",
        name = GUI.CHEST_NETWORK_LIST_SCROLL,
        direction = "vertical"
    })
    list_scroll.style.maximal_height = 325
    list_scroll.style.horizontally_stretchable = true

    -- === Requests Section ===
    inner.add({ type = "line" })
    inner.add({
        type = "label",
        caption = "Requests",
        style = "caption_label"
    })

    local requests_scroll = inner.add({
        type = "scroll-pane",
        name = GUI.CHEST_REQUEST_SLOT_FLOW,
        direction = "vertical"
    })
    requests_scroll.style.maximal_height = 300
    requests_scroll.style.horizontally_stretchable = true

    local requests_flow = requests_scroll.add({
        type = "table",
        name = "requests_flow",
        column_count = 7
    })
    requests_flow.style.horizontal_spacing = 4
    requests_flow.style.vertical_spacing = 4
end

--- Update the relative panel content with the current chest's data
---@param player LuaPlayer
---@param chest LuaEntity
function M.update(player, chest)
    local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
    if not panel then return end

    local inner = panel[GUI.CHEST_FRAME]
    if not inner then return end

    -- Store chest unit_number in the panel for reference
    panel.tags = { chest_unit_number = chest.unit_number }

    local network_name = network_module.get_chest_network_name(chest) or ""
    local network = storage.networks and storage.networks[network_name]
    local requests = network and network.requests or {}

    -- Update network display label
    local display_flow = inner[GUI.CHEST_NETWORK_DISPLAY_FLOW]
    if display_flow then
        local label = display_flow[GUI.CHEST_NETWORK_ID_LABEL]
        if label then
            local display_text = network_name ~= "" and network_name or "[No network]"
            -- Append buffer info
            if network then
                local info_parts = {}
                local buf_count = network.buffer_count or 1
                if buf_count > 1 then
                    -- Show which buffer this chest is on
                    local chest_lid = chest.link_id
                    local buf_idx = nil
                    if network.link_ids then
                        for i, lid in ipairs(network.link_ids) do
                            if lid == chest_lid then
                                buf_idx = i
                                break
                            end
                        end
                    end
                    if buf_idx then
                        info_parts[#info_parts + 1] = "buf " .. buf_idx .. "/" .. buf_count
                    else
                        info_parts[#info_parts + 1] = "×" .. buf_count .. " buf"
                    end
                end
                if #info_parts > 0 then
                    display_text = display_text .. "  [color=yellow][" .. table.concat(info_parts, ", ") .. "][/color]"
                end
            end
            label.caption = display_text
        end
    end

    -- Update edit flow textfield and network list
    local edit_flow = inner[GUI.CHEST_NETWORK_EDIT_FLOW]
    if edit_flow then
        local field = M.find_element(edit_flow, GUI.CHEST_NETWORK_ID_FIELD)
        if field then
            field.text = network_name
        end
        -- Populate network list
        M.populate_network_list(edit_flow)
    end

    -- Update requests
    local requests_scroll = inner[GUI.CHEST_REQUEST_SLOT_FLOW]
    if requests_scroll then
        local requests_flow = requests_scroll.requests_flow
        if requests_flow then
            requests_flow.clear()
            M.create_request_slots(requests_flow, requests)
        end
    end
end

--- Create request slots in vanilla style (dynamic: requests + 1 empty)
---@param parent LuaGuiElement
---@param requests table
function M.create_request_slots(parent, requests)
    -- Convert requests dict to array
    local request_list = {}
    for item_name, req in pairs(requests) do
        table.insert(request_list, { item = item_name, min = req.min, max = req.max })
    end

    -- Create slots for existing requests
    for i, req in ipairs(request_list) do
        M.create_single_slot(parent, i, req.item, req.min, req.max)
    end

    -- Always add one empty slot at the end
    local next_index = #request_list + 1
    M.create_single_slot(parent, next_index, nil, nil, nil)
end

--- Create a single request slot
---@param parent LuaGuiElement
---@param index number
---@param item_name string|nil
---@param min number|nil
---@param max number|nil
function M.create_single_slot(parent, index, item_name, min, max)
    local slot_flow = parent.add({
        type = "flow",
        direction = "vertical"
    })
    slot_flow.style.horizontal_align = "center"
    slot_flow.style.vertical_spacing = 0

    if item_name then
        -- EXISTING REQUEST: sprite-button (click opens popup min/max directly)
        local slot = slot_flow.add({
            type = "sprite-button",
            name = GUI.CHEST_REQUEST_SPRITE_BUTTON .. "_" .. index,
            sprite = "item/" .. item_name,
            tooltip = item_name .. "\nLeft-click: Edit min/max\nRight-click: Delete",
            tags = { slot_index = index, item_name = item_name, min = min, max = max }
        })
        slot.style.size = 40

        -- Show min under the slot (green)
        local min_label = slot_flow.add({
            type = "label",
            caption = tostring(min or 0)
        })
        min_label.style.font = "default-small"
        min_label.style.font_color = {0, 1, 0}

        -- Show max under the slot (orange)
        local max_label = slot_flow.add({
            type = "label",
            caption = tostring(max or 0)
        })
        max_label.style.font = "default-small"
        max_label.style.font_color = {1, 0.5, 0}
    else
        -- EMPTY SLOT: choose-elem-button (opens item selector)
        local slot = slot_flow.add({
            type = "choose-elem-button",
            name = GUI.CHEST_REQUEST_SLOT .. "_" .. index,
            elem_type = "item",
            item = nil,
            tags = { slot_index = index, item_name = nil }
        })
        slot.style.size = 40

        -- Spacer labels to match height of filled slots
        local spacer1 = slot_flow.add({ type = "label", caption = "" })
        spacer1.style.font = "default-small"
        local spacer2 = slot_flow.add({ type = "label", caption = "" })
        spacer2.style.font = "default-small"
    end
end

--- Destroy the relative panel
---@param player LuaPlayer
function M.destroy(player)
    local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
    if panel then
        panel.destroy()
    end
end

--- Destroy the request popup
---@param player LuaPlayer
function M.destroy_popup(player)
    local popup = player.gui.screen[GUI.CHEST_REQUEST_POPUP]
    if popup then
        popup.destroy()
    end
end

--- Refresh the GUI (recreates request slots with current data)
---@param player LuaPlayer
function M.refresh(player)
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_chest
    if not chest or not chest.valid then return end

    M.update(player, chest)
end

--- Update the GUI with live data (called periodically)
--- Only updates existing elements, doesn't recreate the GUI
---@param player LuaPlayer
function M.update_live(player)
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_chest
    if not chest or not chest.valid then return end

    local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
    if not panel then return end

    local inner = panel[GUI.CHEST_FRAME]
    if not inner then return end

    -- Get current network data
    local network_name = network_module.get_chest_network_name(chest) or ""
    local network = storage.networks and storage.networks[network_name]
    local requests = network and network.requests or {}

    -- Update requests
    local requests_scroll = inner[GUI.CHEST_REQUEST_SLOT_FLOW]
    if not requests_scroll then return end

    local requests_flow = requests_scroll.requests_flow
    if not requests_flow then return end

    -- Update min/max labels for existing slots
    for _, slot_flow in pairs(requests_flow.children) do
        if slot_flow.type == "flow" then
            local slot_button = slot_flow.children[1]
            if slot_button and slot_button.tags and slot_button.tags.item_name then
                local item_name = slot_button.tags.item_name
                local req = requests[item_name]
                if req then
                    -- Update min label (child 2)
                    local min_label = slot_flow.children[2]
                    if min_label and min_label.type == "label" then
                        min_label.caption = tostring(req.min or 0)
                    end
                    -- Update max label (child 3)
                    local max_label = slot_flow.children[3]
                    if max_label and max_label.type == "label" then
                        max_label.caption = tostring(req.max or 0)
                    end
                end
            end
        end
    end
end

--- Recursively find a GUI element by name
---@param parent LuaGuiElement
---@param name string
---@return LuaGuiElement|nil
function M.find_element(parent, name)
    for _, child in pairs(parent.children) do
        if child.name == name then return child end
        if child.children then
            local found = M.find_element(child, name)
            if found then return found end
        end
    end
    return nil
end

--- Populate the network list in edit mode (only manual networks)
---@param edit_flow LuaGuiElement
function M.populate_network_list(edit_flow)
    local list_scroll = edit_flow[GUI.CHEST_NETWORK_LIST_SCROLL]
    if not list_scroll then return end

    list_scroll.clear()

    -- Get only manual network names (not from copy-paste of recipes)
    local networks = storage.networks or {}
    local network_names = {}
    for name, data in pairs(networks) do
        if data.manual then
            table.insert(network_names, name)
        end
    end
    table.sort(network_names)

    -- Create buttons for each manual network
    for _, name in ipairs(network_names) do
        local btn = list_scroll.add({
            type = "button",
            name = GUI.CHEST_NETWORK_LIST_BUTTON .. "_" .. name,
            caption = name,
            style = "list_box_item",
            tags = { network_name = name }
        })
        btn.style.horizontally_stretchable = true
        btn.style.horizontal_align = "left"
    end

    -- Show message if no manual networks exist
    if #network_names == 0 then
        list_scroll.add({
            type = "label",
            caption = "[No manual networks]",
            style = "label"
        })
    end
end

--- Show/hide edit mode for network ID
---@param player LuaPlayer
---@param show_edit boolean
function M.set_edit_mode(player, show_edit)
    local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
    if not panel then return end

    local inner = panel[GUI.CHEST_FRAME]
    if not inner then return end

    local display_flow = inner[GUI.CHEST_NETWORK_DISPLAY_FLOW]
    local edit_flow = inner[GUI.CHEST_NETWORK_EDIT_FLOW]

    if display_flow then
        display_flow.visible = not show_edit
    end

    if edit_flow then
        edit_flow.visible = show_edit
        if show_edit then
            -- Copy current network name to textfield
            local player_data = state.get_player_data(player.index)
            local chest = player_data.opened_chest
            if chest and chest.valid then
                local network_name = network_module.get_chest_network_name(chest) or ""
                local field = M.find_element(edit_flow, GUI.CHEST_NETWORK_ID_FIELD)
                if field then
                    field.text = network_name
                    field.focus()
                    field.select_all()
                end
                -- Populate network list
                M.populate_network_list(edit_flow)
            end
        end
    end
end

--- Open the min/max popup for a request slot
---@param player LuaPlayer
---@param slot_index number
---@param item_name string
---@param current_min number|nil
---@param current_max number|nil
function M.open_request_popup(player, slot_index, item_name, current_min, current_max)
    M.destroy_popup(player)

    -- Store the chest unit_number so we can re-open it when popup closes
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_chest
    local chest_unit_number = chest and chest.valid and chest.unit_number or nil

    local min_val = current_min or 100
    local max_val = current_max or 200

    local popup = player.gui.screen.add({
        type = "frame",
        name = GUI.CHEST_REQUEST_POPUP,
        caption = "Set Request",
        direction = "vertical"
    })
    popup.auto_center = true
    popup.tags = { slot_index = slot_index, item_name = item_name, chest_unit_number = chest_unit_number }

    -- Item display
    local item_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    item_flow.style.vertical_align = "center"

    item_flow.add({
        type = "sprite",
        sprite = "item/" .. item_name
    })
    item_flow.add({
        type = "label",
        caption = item_name
    })

    -- Min: slider + textfield
    local min_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    min_flow.style.vertical_align = "center"

    min_flow.add({
        type = "label",
        caption = "Min:"
    }).style.width = 40

    local min_slider = min_flow.add({
        type = "slider",
        name = GUI.CHEST_REQUEST_MIN_SLIDER,
        minimum_value = 0,
        maximum_value = 10000,
        value = min_val,
        discrete_values = true
    })
    min_slider.style.width = 150

    local min_field = min_flow.add({
        type = "textfield",
        name = GUI.CHEST_REQUEST_MIN_FIELD,
        text = tostring(min_val),
        numeric = true,
        allow_decimal = false,
        allow_negative = false
    })
    min_field.style.width = 80

    -- Max: slider + textfield
    local max_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    max_flow.style.vertical_align = "center"

    max_flow.add({
        type = "label",
        caption = "Max:"
    }).style.width = 40

    local max_slider = max_flow.add({
        type = "slider",
        name = GUI.CHEST_REQUEST_MAX_SLIDER,
        minimum_value = 0,
        maximum_value = 10000,
        value = max_val,
        discrete_values = true
    })
    max_slider.style.width = 150

    local max_field = max_flow.add({
        type = "textfield",
        name = GUI.CHEST_REQUEST_MAX_FIELD,
        text = tostring(max_val),
        numeric = true,
        allow_decimal = false,
        allow_negative = false
    })
    max_field.style.width = 80

    -- Buttons
    local button_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    button_flow.style.horizontal_spacing = 8

    button_flow.add({
        type = "button",
        name = GUI.CHEST_REQUEST_CONFIRM,
        caption = "OK",
        style = "confirm_button"
    })

    button_flow.add({
        type = "button",
        name = GUI.CHEST_REQUEST_CANCEL,
        caption = "Cancel"
    })

    -- Focus the min field
    min_field.focus()

    -- Note: We don't set player.opened = popup to keep the chest GUI visible
    -- The E key is handled in on_gui_closed to close popup first, then chest
end

--- Handle click events
---@param event EventData.on_gui_click
function M.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)
    local chest = player_data.opened_chest

    -- Network Edit button - switch to edit mode
    if element.name == GUI.CHEST_NETWORK_EDIT_BUTTON then
        M.set_edit_mode(player, true)
        return
    end

    -- Network Confirm button - validate and apply network, return to display mode
    if element.name == GUI.CHEST_NETWORK_CONFIRM_BUTTON then
        if not chest or not chest.valid then return end

        local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
        if panel then
            local inner = panel[GUI.CHEST_FRAME]
            if inner then
                local edit_flow = inner[GUI.CHEST_NETWORK_EDIT_FLOW]
                if edit_flow then
                    local field = M.find_element(edit_flow, GUI.CHEST_NETWORK_ID_FIELD)
                    if field then
                        local new_network = field.text
                        -- manual = true because user is setting network via GUI
                        network_module.set_chest_network(chest, new_network, true)
                        M.set_edit_mode(player, false)
                        M.refresh(player)
                        return
                    end
                end
            end
        end
        return
    end

    -- Network Cancel button - return to display mode without changes
    if element.name == GUI.CHEST_NETWORK_CANCEL_BUTTON then
        M.set_edit_mode(player, false)
        return
    end

    -- Network list button clicked - select that network
    if element.name and element.name:find(GUI.CHEST_NETWORK_LIST_BUTTON) then
        local network_name = element.tags and element.tags.network_name
        if network_name then
            local panel = player.gui.relative[GUI.CHEST_RELATIVE_PANEL]
            if panel then
                local inner = panel[GUI.CHEST_FRAME]
                if inner then
                    local edit_flow = inner[GUI.CHEST_NETWORK_EDIT_FLOW]
                    if edit_flow then
                        local field = M.find_element(edit_flow, GUI.CHEST_NETWORK_ID_FIELD)
                        if field then
                            field.text = network_name
                        end
                    end
                end
            end
        end
        return
    end

    -- Existing request sprite-button clicked
    if element.name and element.name:find(GUI.CHEST_REQUEST_SPRITE_BUTTON) then
        if not chest or not chest.valid then return end

        local network_name = network_module.get_chest_network_name(chest)
        if not network_name or network_name == "" then
            player.print("Please set a network ID first")
            return
        end

        local tags = element.tags

        if event.button == defines.mouse_button_type.right then
            -- Right-click: delete request
            network_module.remove_request(network_name, tags.item_name)
            M.refresh(player)
        else
            -- Left-click: open min/max popup
            M.open_request_popup(player, tags.slot_index, tags.item_name, tags.min, tags.max)
        end
        return
    end

    -- Request popup confirm
    if element.name == GUI.CHEST_REQUEST_CONFIRM then
        if not chest or not chest.valid then return end

        local popup = player.gui.screen[GUI.CHEST_REQUEST_POPUP]
        if not popup then return end

        local item_name = popup.tags.item_name
        local network_name = network_module.get_chest_network_name(chest)

        if network_name and item_name then
            -- Find min/max values
            local min_value = 100
            local max_value = 200

            for _, child in pairs(popup.children) do
                if child.type == "flow" then
                    local min_field = child[GUI.CHEST_REQUEST_MIN_FIELD]
                    local max_field = child[GUI.CHEST_REQUEST_MAX_FIELD]
                    if min_field then
                        min_value = tonumber(min_field.text) or 100
                    end
                    if max_field then
                        max_value = tonumber(max_field.text) or 200
                    end
                end
            end

            network_module.set_request(network_name, item_name, min_value, max_value)
        end

        M.destroy_popup(player)
        M.refresh(player)
        return
    end

    -- Request popup cancel
    if element.name == GUI.CHEST_REQUEST_CANCEL then
        M.destroy_popup(player)
        M.refresh(player)
        return
    end
end

--- Handle elem changed events (item selection in slots)
---@param event EventData.on_gui_elem_changed
function M.on_gui_elem_changed(event)
    local element = event.element
    if not element or not element.valid then return end
    if not element.name or not element.name:find(GUI.CHEST_REQUEST_SLOT) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)
    local chest = player_data.opened_chest
    if not chest or not chest.valid then return end

    local network_name = network_module.get_chest_network_name(chest)
    if not network_name or network_name == "" then
        -- No network set, clear the selection
        element.elem_value = nil
        player.print("Please set a network ID first")
        return
    end

    local item_name = element.elem_value
    local old_item = element.tags.item_name

    if item_name then
        -- Item was selected - open popup for min/max
        local network = storage.networks[network_name]
        local existing = network and network.requests[item_name]

        M.open_request_popup(
            player,
            element.tags.slot_index,
            item_name,
            existing and existing.min,
            existing and existing.max
        )
    else
        -- Item was cleared - remove the request
        if old_item then
            network_module.remove_request(network_name, old_item)
            M.refresh(player)
        end
    end
end

--- Handle slider value changed events (dynamic min/max sync)
---@param event EventData.on_gui_value_changed
function M.on_gui_value_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local popup = player.gui.screen[GUI.CHEST_REQUEST_POPUP]
    if not popup then return end

    -- Min slider changed
    if element.name == GUI.CHEST_REQUEST_MIN_SLIDER then
        local min_val = math.floor(element.slider_value)

        -- Update min textfield
        local min_field = M.find_element(popup, GUI.CHEST_REQUEST_MIN_FIELD)
        if min_field then min_field.text = tostring(min_val) end

        -- If min > max, make max follow
        local max_slider = M.find_element(popup, GUI.CHEST_REQUEST_MAX_SLIDER)
        local max_field = M.find_element(popup, GUI.CHEST_REQUEST_MAX_FIELD)
        if max_slider and max_slider.slider_value < min_val then
            max_slider.slider_value = min_val
            if max_field then max_field.text = tostring(min_val) end
        end
        return
    end

    -- Max slider changed
    if element.name == GUI.CHEST_REQUEST_MAX_SLIDER then
        local max_val = math.floor(element.slider_value)

        -- Update max textfield
        local max_field = M.find_element(popup, GUI.CHEST_REQUEST_MAX_FIELD)
        if max_field then max_field.text = tostring(max_val) end

        -- If max < min, make min follow
        local min_slider = M.find_element(popup, GUI.CHEST_REQUEST_MIN_SLIDER)
        local min_field = M.find_element(popup, GUI.CHEST_REQUEST_MIN_FIELD)
        if min_slider and min_slider.slider_value > max_val then
            min_slider.slider_value = max_val
            if min_field then min_field.text = tostring(max_val) end
        end
        return
    end
end

--- Handle text changed events (sync textfield -> slider)
---@param event EventData.on_gui_text_changed
function M.on_gui_text_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local popup = player.gui.screen[GUI.CHEST_REQUEST_POPUP]
    if not popup then return end

    local value = tonumber(element.text) or 0

    -- Min textfield changed
    if element.name == GUI.CHEST_REQUEST_MIN_FIELD then
        local min_slider = M.find_element(popup, GUI.CHEST_REQUEST_MIN_SLIDER)
        if min_slider then
            min_slider.slider_value = math.min(value, 10000)
        end
        -- Make max follow if needed (only if current max < new min)
        local max_slider = M.find_element(popup, GUI.CHEST_REQUEST_MAX_SLIDER)
        local max_field = M.find_element(popup, GUI.CHEST_REQUEST_MAX_FIELD)
        local current_max = max_field and tonumber(max_field.text) or 0
        if current_max < value then
            if max_slider then max_slider.slider_value = math.min(value, 10000) end
            if max_field then max_field.text = tostring(value) end
        end
        return
    end

    -- Max textfield changed
    if element.name == GUI.CHEST_REQUEST_MAX_FIELD then
        local max_slider = M.find_element(popup, GUI.CHEST_REQUEST_MAX_SLIDER)
        if max_slider then
            max_slider.slider_value = math.min(value, 10000)
        end
        -- Make min follow if needed (only if current min > new max)
        local min_slider = M.find_element(popup, GUI.CHEST_REQUEST_MIN_SLIDER)
        local min_field = M.find_element(popup, GUI.CHEST_REQUEST_MIN_FIELD)
        local current_min = min_field and tonumber(min_field.text) or 0
        if current_min > value then
            if min_slider then min_slider.slider_value = math.min(value, 10000) end
            if min_field then min_field.text = tostring(value) end
        end
        return
    end
end

--- Handle confirmed events (Enter key pressed in textfield)
---@param event EventData.on_gui_confirmed
function M.on_gui_confirmed(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Only handle Enter in the request popup min/max fields
    if element.name ~= GUI.CHEST_REQUEST_MIN_FIELD and element.name ~= GUI.CHEST_REQUEST_MAX_FIELD then
        return
    end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)
    local chest = player_data.opened_chest
    if not chest or not chest.valid then return end

    local popup = player.gui.screen[GUI.CHEST_REQUEST_POPUP]
    if not popup then return end

    local item_name = popup.tags.item_name
    local network_name = network_module.get_chest_network_name(chest)

    if network_name and item_name then
        -- Find min/max values
        local min_value = 100
        local max_value = 200

        for _, child in pairs(popup.children) do
            if child.type == "flow" then
                local min_field = child[GUI.CHEST_REQUEST_MIN_FIELD]
                local max_field = child[GUI.CHEST_REQUEST_MAX_FIELD]
                if min_field then
                    min_value = tonumber(min_field.text) or 100
                end
                if max_field then
                    max_value = tonumber(max_field.text) or 200
                end
            end
        end

        network_module.set_request(network_name, item_name, min_value, max_value)
    end

    M.destroy_popup(player)
    M.refresh(player)
end

return M
