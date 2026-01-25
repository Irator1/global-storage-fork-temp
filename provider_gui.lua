local constants = require("constants")
local state = require("state")

local M = {}

local GUI = constants.GUI

--- Create the relative panel for a player (called once at player creation)
--- The panel will automatically show/hide when the vanilla logistic container GUI opens/closes
---@param player LuaPlayer
function M.create_relative_panel(player)
    -- Don't recreate if it already exists
    if player.gui.relative[GUI.PROVIDER_RELATIVE_PANEL] then
        return
    end

    -- Main frame anchored to the container GUI
    local frame = player.gui.relative.add({
        type = "frame",
        name = GUI.PROVIDER_RELATIVE_PANEL,
        caption = {"gui.provider-title"},
        direction = "vertical",
        anchor = {
            gui = defines.relative_gui_type.container_gui,
            position = defines.relative_gui_position.right,
            name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME  -- Only show for our chest
        }
    })

    -- Inner frame for content
    local inner = frame.add({
        type = "frame",
        name = GUI.PROVIDER_FRAME,
        style = "inside_shallow_frame_with_padding",
        direction = "vertical"
    })

    -- === Requests Section ===
    inner.add({
        type = "label",
        caption = {"gui.provider-requests"},
        style = "caption_label"
    })

    local requests_scroll = inner.add({
        type = "scroll-pane",
        name = GUI.PROVIDER_REQUEST_FLOW,
        direction = "vertical"
    })
    requests_scroll.style.maximal_height = 200
    requests_scroll.style.horizontally_stretchable = true

    local requests_flow = requests_scroll.add({
        type = "flow",
        name = "requests_flow",
        direction = "horizontal"
    })
    requests_flow.style.horizontal_spacing = 4
end

--- Update the relative panel content with the current provider chest's data
---@param player LuaPlayer
---@param chest LuaEntity
function M.update(player, chest)
    local panel = player.gui.relative[GUI.PROVIDER_RELATIVE_PANEL]
    if not panel then return end

    local inner = panel[GUI.PROVIDER_FRAME]
    if not inner then return end

    -- Store chest unit_number in the panel for reference
    panel.tags = { chest_unit_number = chest.unit_number }

    local provider_data = state.get_provider_data(chest.unit_number)
    local requests = provider_data and provider_data.requests or {}

    -- Update requests
    local requests_scroll = inner[GUI.PROVIDER_REQUEST_FLOW]
    if requests_scroll then
        local requests_flow = requests_scroll.requests_flow
        if requests_flow then
            requests_flow.clear()
            M.create_request_slots(requests_flow, requests)
        end
    end
end

--- Create request slots (dynamic: requests + 1 empty)
---@param parent LuaGuiElement
---@param requests table
function M.create_request_slots(parent, requests)
    -- Convert requests dict to array
    local request_list = {}
    for item_name, quantity in pairs(requests) do
        table.insert(request_list, { item = item_name, quantity = quantity })
    end

    -- Create slots for existing requests
    for i, req in ipairs(request_list) do
        M.create_single_slot(parent, i, req.item, req.quantity)
    end

    -- Always add one empty slot at the end
    local next_index = #request_list + 1
    M.create_single_slot(parent, next_index, nil, nil)
end

--- Create a single request slot
---@param parent LuaGuiElement
---@param index number
---@param item_name string|nil
---@param quantity number|nil
function M.create_single_slot(parent, index, item_name, quantity)
    local slot_flow = parent.add({
        type = "flow",
        direction = "vertical"
    })
    slot_flow.style.horizontal_align = "center"
    slot_flow.style.vertical_spacing = 0

    if item_name then
        -- EXISTING REQUEST: sprite-button (click opens popup for quantity)
        local slot = slot_flow.add({
            type = "sprite-button",
            name = GUI.PROVIDER_REQUEST_SPRITE_BUTTON .. "_" .. index,
            sprite = "item/" .. item_name,
            tooltip = item_name .. "\nLeft-click: Edit quantity\nRight-click: Delete",
            tags = { slot_index = index, item_name = item_name, quantity = quantity }
        })
        slot.style.size = 40

        -- Show quantity under the slot
        local qty_label = slot_flow.add({
            type = "label",
            caption = tostring(quantity or 0)
        })
        qty_label.style.font = "default-small"
        qty_label.style.font_color = {0, 1, 0}
    else
        -- EMPTY SLOT: choose-elem-button (opens item selector)
        local slot = slot_flow.add({
            type = "choose-elem-button",
            name = GUI.PROVIDER_REQUEST_SLOT .. "_" .. index,
            elem_type = "item",
            item = nil,
            tags = { slot_index = index, item_name = nil }
        })
        slot.style.size = 40
    end
end

--- Destroy the relative panel
---@param player LuaPlayer
function M.destroy(player)
    local panel = player.gui.relative[GUI.PROVIDER_RELATIVE_PANEL]
    if panel then
        panel.destroy()
    end
end

--- Destroy the request popup
---@param player LuaPlayer
function M.destroy_popup(player)
    local popup = player.gui.screen[GUI.PROVIDER_REQUEST_POPUP]
    if popup then
        popup.destroy()
    end
end

--- Refresh the GUI (recreates request slots with current data)
---@param player LuaPlayer
function M.refresh(player)
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_provider_chest
    if not chest or not chest.valid then return end

    M.update(player, chest)
end

--- Update the GUI with live data (called periodically)
---@param player LuaPlayer
function M.update_live(player)
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_provider_chest
    if not chest or not chest.valid then return end

    local panel = player.gui.relative[GUI.PROVIDER_RELATIVE_PANEL]
    if not panel then return end

    local inner = panel[GUI.PROVIDER_FRAME]
    if not inner then return end

    local provider_data = state.get_provider_data(chest.unit_number)
    local requests = provider_data and provider_data.requests or {}

    local requests_scroll = inner[GUI.PROVIDER_REQUEST_FLOW]
    if not requests_scroll then return end

    local requests_flow = requests_scroll.requests_flow
    if not requests_flow then return end

    -- Update quantity labels for existing slots
    for _, slot_flow in pairs(requests_flow.children) do
        if slot_flow.type == "flow" then
            local slot_button = slot_flow.children[1]
            if slot_button and slot_button.tags and slot_button.tags.item_name then
                local item_name = slot_button.tags.item_name
                local quantity = requests[item_name]
                if quantity then
                    -- Update quantity label (child 2)
                    local qty_label = slot_flow.children[2]
                    if qty_label and qty_label.type == "label" then
                        qty_label.caption = tostring(quantity)
                    end
                end
            end
        end
    end
end

--- Open the quantity popup for a request slot
---@param player LuaPlayer
---@param slot_index number
---@param item_name string
---@param current_quantity number|nil
function M.open_request_popup(player, slot_index, item_name, current_quantity)
    M.destroy_popup(player)

    -- Store the chest unit_number so we can re-open it when popup closes
    local player_data = state.get_player_data(player.index)
    local chest = player_data.opened_provider_chest
    local chest_unit_number = chest and chest.valid and chest.unit_number or nil

    -- Default to stack size
    local stack_size = prototypes.item[item_name] and prototypes.item[item_name].stack_size or 200
    local qty_val = current_quantity or stack_size

    local popup = player.gui.screen.add({
        type = "frame",
        name = GUI.PROVIDER_REQUEST_POPUP,
        caption = {"gui.provider-set-request"},
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

    -- Quantity: slider + textfield
    local qty_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    qty_flow.style.vertical_align = "center"

    qty_flow.add({
        type = "label",
        caption = {"gui.provider-quantity"}
    }).style.width = 60

    local qty_slider = qty_flow.add({
        type = "slider",
        name = GUI.PROVIDER_REQUEST_QUANTITY_SLIDER,
        minimum_value = 0,
        maximum_value = 10000,
        value = qty_val,
        discrete_values = true
    })
    qty_slider.style.width = 150

    local qty_field = qty_flow.add({
        type = "textfield",
        name = GUI.PROVIDER_REQUEST_QUANTITY_FIELD,
        text = tostring(qty_val),
        numeric = true,
        allow_decimal = false,
        allow_negative = false
    })
    qty_field.style.width = 80

    -- Buttons
    local button_flow = popup.add({
        type = "flow",
        direction = "horizontal"
    })
    button_flow.style.horizontal_spacing = 8

    button_flow.add({
        type = "button",
        name = GUI.PROVIDER_REQUEST_CONFIRM,
        caption = {"gui.gn-ok"},
        style = "confirm_button"
    })

    button_flow.add({
        type = "button",
        name = GUI.PROVIDER_REQUEST_CANCEL,
        caption = {"gui.gn-cancel"}
    })

    -- Focus the quantity field
    qty_field.focus()
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

--- Handle click events
---@param event EventData.on_gui_click
function M.on_gui_click(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)
    local chest = player_data.opened_provider_chest

    -- Existing request sprite-button clicked
    if element.name and element.name:find(GUI.PROVIDER_REQUEST_SPRITE_BUTTON) then
        if not chest or not chest.valid then return end

        local tags = element.tags

        if event.button == defines.mouse_button_type.right then
            -- Right-click: delete request
            state.remove_provider_request(chest.unit_number, tags.item_name)
            M.refresh(player)
        else
            -- Left-click: open quantity popup
            M.open_request_popup(player, tags.slot_index, tags.item_name, tags.quantity)
        end
        return
    end

    -- Request popup confirm
    if element.name == GUI.PROVIDER_REQUEST_CONFIRM then
        local popup = player.gui.screen[GUI.PROVIDER_REQUEST_POPUP]
        if not popup then return end

        local item_name = popup.tags.item_name
        local chest_unit_number = popup.tags.chest_unit_number

        if item_name and chest_unit_number then
            -- Find quantity value
            local stack_size = prototypes.item[item_name] and prototypes.item[item_name].stack_size or 200
            local quantity = stack_size

            for _, child in pairs(popup.children) do
                if child.type == "flow" then
                    local qty_field = child[GUI.PROVIDER_REQUEST_QUANTITY_FIELD]
                    if qty_field then
                        quantity = tonumber(qty_field.text) or stack_size
                    end
                end
            end

            state.set_provider_request(chest_unit_number, item_name, quantity)
        end

        M.destroy_popup(player)
        M.refresh(player)
        return
    end

    -- Request popup cancel
    if element.name == GUI.PROVIDER_REQUEST_CANCEL then
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
    if not element.name or not element.name:find(GUI.PROVIDER_REQUEST_SLOT) then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)
    local chest = player_data.opened_provider_chest
    if not chest or not chest.valid then return end

    local item_name = element.elem_value
    local old_item = element.tags.item_name

    if item_name then
        -- Item was selected - open popup for quantity
        local provider_data = state.get_provider_data(chest.unit_number)
        local existing = provider_data and provider_data.requests[item_name]

        M.open_request_popup(
            player,
            element.tags.slot_index,
            item_name,
            existing
        )
    else
        -- Item was cleared - remove the request
        if old_item then
            state.remove_provider_request(chest.unit_number, old_item)
            M.refresh(player)
        end
    end
end

--- Handle slider value changed events
---@param event EventData.on_gui_value_changed
function M.on_gui_value_changed(event)
    local element = event.element
    if not element or not element.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local popup = player.gui.screen[GUI.PROVIDER_REQUEST_POPUP]
    if not popup then return end

    -- Quantity slider changed
    if element.name == GUI.PROVIDER_REQUEST_QUANTITY_SLIDER then
        local qty_val = math.floor(element.slider_value)

        -- Update quantity textfield
        local qty_field = M.find_element(popup, GUI.PROVIDER_REQUEST_QUANTITY_FIELD)
        if qty_field then qty_field.text = tostring(qty_val) end
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

    local popup = player.gui.screen[GUI.PROVIDER_REQUEST_POPUP]
    if not popup then return end

    -- Quantity textfield changed
    if element.name == GUI.PROVIDER_REQUEST_QUANTITY_FIELD then
        local value = tonumber(element.text) or 0
        local qty_slider = M.find_element(popup, GUI.PROVIDER_REQUEST_QUANTITY_SLIDER)
        if qty_slider then
            qty_slider.slider_value = math.min(value, 10000)
        end
        return
    end
end

--- Handle confirmed events (Enter key pressed in textfield)
---@param event EventData.on_gui_confirmed
function M.on_gui_confirmed(event)
    local element = event.element
    if not element or not element.valid then return end

    -- Only handle Enter in the request popup quantity field
    if element.name ~= GUI.PROVIDER_REQUEST_QUANTITY_FIELD then
        return
    end

    local player = game.get_player(event.player_index)
    if not player then return end

    local popup = player.gui.screen[GUI.PROVIDER_REQUEST_POPUP]
    if not popup then return end

    local item_name = popup.tags.item_name
    local chest_unit_number = popup.tags.chest_unit_number

    if item_name and chest_unit_number then
        -- Find quantity value
        local stack_size = prototypes.item[item_name] and prototypes.item[item_name].stack_size or 200
        local quantity = stack_size

        for _, child in pairs(popup.children) do
            if child.type == "flow" then
                local qty_field = child[GUI.PROVIDER_REQUEST_QUANTITY_FIELD]
                if qty_field then
                    quantity = tonumber(qty_field.text) or stack_size
                end
            end
        end

        state.set_provider_request(chest_unit_number, item_name, quantity)
    end

    M.destroy_popup(player)
    M.refresh(player)
end

return M
