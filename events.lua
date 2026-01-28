local constants = require("constants")
local state = require("state")
local network_module = require("network")
local chest_gui = require("chest_gui")
local network_gui = require("network_gui")
local provider_gui = require("provider_gui")

local M = {}

-- Entity filters for our chests
local chest_filter = {{ filter = "name", name = constants.GLOBAL_CHEST_ENTITY_NAME }}
local provider_filter = {{ filter = "name", name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME }}
-- Combined filter for both chest types
local all_chests_filter = {
    { filter = "name", name = constants.GLOBAL_CHEST_ENTITY_NAME },
    { filter = "name", name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME }
}

--- Handle any chest built (player or robot)
---@param event EventData
local function on_any_chest_built(event)
    local entity = event.entity or event.created_entity
    if not entity or not entity.valid then return end

    -- Handle global-chest
    if entity.name == constants.GLOBAL_CHEST_ENTITY_NAME then
        local link_id = entity.link_id
        if link_id == 0 then
            -- Assign default network to new chests without explicit network ID
            network_module.set_chest_network(entity, constants.DEFAULT_NETWORK_NAME)
        else
            network_module.on_chest_built(link_id, entity.unit_number)
        end
        return
    end

    -- Handle global-provider-chest
    if entity.name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
        state.register_provider_chest(entity)
        return
    end
end

--- Handle any chest destroyed (player mined, robot mined, died)
---@param event EventData
local function on_any_chest_destroyed(event)
    local entity = event.entity
    if not entity or not entity.valid then return end

    -- Handle global-chest
    if entity.name == constants.GLOBAL_CHEST_ENTITY_NAME then
        local link_id = entity.link_id
        if link_id and link_id ~= 0 then
            network_module.on_chest_destroyed(link_id)
        end
        state.remove_chest_tracking(entity.unit_number)
        return
    end

    -- Handle global-provider-chest
    if entity.name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
        state.unregister_provider_chest(entity.unit_number)
        return
    end
end

--- Handle copy-paste from assembling machine to chest
---@param event EventData.on_entity_settings_pasted
local function on_entity_settings_pasted(event)
    local source = event.source
    local destination = event.destination

    if not destination or not destination.valid then return end
    if destination.name ~= constants.GLOBAL_CHEST_ENTITY_NAME then return end

    -- Paste from assembling machine: import recipe ingredients as requests
    if source.type == "assembling-machine" or source.type == "furnace" then
        local recipe = source.get_recipe()
        if not recipe then return end

        -- Get network name from recipe name
        local network_name = recipe.name

        -- Check if network exists BEFORE creating it
        local is_new_network = (storage.networks[network_name] == nil)

        -- Update chest link_id to match recipe (always)
        network_module.set_chest_network(destination, network_name)

        -- Only set requests and block slots for NEW networks
        if is_new_network then
            local network = state.get_or_create_network(network_name)
            if network then
                -- Add ingredients as requests
                local request_count = 0
                for _, ingredient in pairs(recipe.ingredients) do
                    if ingredient.type == "item" then
                        local stack_size = prototypes.item[ingredient.name].stack_size
                        network.requests[ingredient.name] = {
                            min = stack_size,
                            max = stack_size
                        }
                        request_count = request_count + 1
                    end
                end

                -- Block slots: keep (request_count + 1) slots open for inputs + output
                local inventory = destination.get_inventory(defines.inventory.chest)
                if inventory and inventory.supports_bar() then
                    inventory.set_bar(request_count + 2)  -- +1 for output, +1 for 1-indexing
                end
            end
        end

        -- Refresh GUI if player has this chest open
        local player = game.get_player(event.player_index)
        if player then
            local player_data = state.get_player_data(event.player_index)
            if player_data.opened_chest and player_data.opened_chest.valid
               and player_data.opened_chest.unit_number == destination.unit_number then
                chest_gui.update(player, destination)
            end
        end
    end

    -- Paste from another global chest: copy network ID
    if source.name == constants.GLOBAL_CHEST_ENTITY_NAME then
        local source_link_id = source.link_id
        local source_network_name = state.get_network_name(source_link_id)

        if source_network_name then
            network_module.set_chest_network(destination, source_network_name)
        end

        -- Refresh GUI if player has this chest open
        local player = game.get_player(event.player_index)
        if player then
            local player_data = state.get_player_data(event.player_index)
            if player_data.opened_chest and player_data.opened_chest.valid
               and player_data.opened_chest.unit_number == destination.unit_number then
                chest_gui.update(player, destination)
            end
        end
    end
end

--- Handle player opening a chest
--- With gui.relative, we just need to update the panel content - the panel shows automatically
---@param event EventData.on_gui_opened
local function on_gui_opened(event)
    -- Only handle entity GUIs
    if event.gui_type ~= defines.gui_type.entity then return end

    local entity = event.entity
    if not entity or not entity.valid then return end

    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)

    -- Handle global-chest
    if entity.name == constants.GLOBAL_CHEST_ENTITY_NAME then
        player_data.opened_chest = entity

        -- Ensure the relative panel exists
        chest_gui.create_relative_panel(player)

        -- Update panel content with this chest's data
        chest_gui.update(player, entity)
        return
    end

    -- Handle global-provider-chest
    if entity.name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
        player_data.opened_provider_chest = entity

        -- Ensure the chest is registered (in case it was placed before mod update)
        if not state.get_provider_data(entity.unit_number) then
            state.register_provider_chest(entity)
        end

        -- Ensure the relative panel exists
        provider_gui.create_relative_panel(player)

        -- Update panel content with this chest's data
        provider_gui.update(player, entity)
        return
    end
end

--- Handle player closing a GUI
---@param event EventData.on_gui_closed
local function on_gui_closed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)

    -- Check if it's an entity being closed (vanilla linked container GUI)
    if event.gui_type == defines.gui_type.entity then
        local entity = event.entity
        if entity and entity.valid then
            -- Handle global-chest
            if entity.name == constants.GLOBAL_CHEST_ENTITY_NAME then
                local popup = player.gui.screen[constants.GUI.CHEST_REQUEST_POPUP]
                if popup then
                    -- Popup is open - close popup only, then re-open chest immediately
                    chest_gui.destroy_popup(player)
                    player.opened = entity
                else
                    -- Truly closing the chest
                    player_data.opened_chest = nil
                end
                return
            end

            -- Handle global-provider-chest
            if entity.name == constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME then
                local popup = player.gui.screen[constants.GUI.PROVIDER_REQUEST_POPUP]
                if popup then
                    -- Popup is open - close popup only, then re-open chest immediately
                    provider_gui.destroy_popup(player)
                    player.opened = entity
                else
                    -- Truly closing the chest
                    player_data.opened_provider_chest = nil
                end
                return
            end
        end
        return
    end

    -- Check element name safely for screen GUIs
    local element_name = nil
    local element = event.element
    if element then
        local ok, name = pcall(function() return element.valid and element.name end)
        if ok and name then
            element_name = name
        end
    end

    -- Close request popup - re-open the chest afterwards
    if element_name == constants.GUI.CHEST_REQUEST_POPUP then
        -- Get the chest unit_number from popup tags before destroying it
        local chest_unit_number = element.tags and element.tags.chest_unit_number
        chest_gui.destroy_popup(player)

        -- Re-open the chest if we have a valid reference
        if chest_unit_number then
            local player_data = state.get_player_data(event.player_index)
            local chest = player_data.opened_chest
            if chest and chest.valid and chest.unit_number == chest_unit_number then
                player.opened = chest
            end
        end
    end

    -- Close provider request popup - re-open the provider chest afterwards
    if element_name == constants.GUI.PROVIDER_REQUEST_POPUP then
        -- Get the chest unit_number from popup tags before destroying it
        local chest_unit_number = element.tags and element.tags.chest_unit_number
        provider_gui.destroy_popup(player)

        -- Re-open the chest if we have a valid reference
        if chest_unit_number then
            local player_data = state.get_player_data(event.player_index)
            local chest = player_data.opened_provider_chest
            if chest and chest.valid and chest.unit_number == chest_unit_number then
                player.opened = chest
            end
        end
    end

    -- Close network GUI
    if element_name == constants.GUI.NETWORK_FRAME then
        -- Check if we're opening the delete confirm popup
        if player_data.opening_delete_confirm then
            player_data.opening_delete_confirm = false
            -- Don't destroy the network GUI, popup is now player.opened
            return
        end

        -- Check if we're opening the inventory edit popup
        if player_data.opening_inventory_popup then
            player_data.opening_inventory_popup = false
            -- Don't destroy the network GUI, popup is now player.opened
            return
        end

        player_data.opened_network_gui = false
        network_gui.destroy(player)
    end

    -- Close delete confirmation popup - reopen network GUI
    if element_name == constants.GUI.NETWORK_DELETE_CONFIRM_POPUP then
        network_gui.destroy_delete_confirm_popup(player)
        -- Reopen network GUI if still marked as open
        if player_data.opened_network_gui then
            local frame = player.gui.screen[constants.GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
    end

    -- Close inventory edit popup - reopen network GUI
    if element_name == constants.GUI.INVENTORY_EDIT_POPUP then
        network_gui.destroy_inventory_edit_popup(player)
        -- Reopen network GUI if still marked as open
        if player_data.opened_network_gui then
            local frame = player.gui.screen[constants.GUI.NETWORK_FRAME]
            if frame then
                player.opened = frame
            end
        end
    end
end

--- Handle hotkey press (Shift+G for network GUI)
---@param event EventData.CustomInputEvent
local function on_hotkey_pressed(event)
    local player = game.get_player(event.player_index)
    if not player then return end

    local player_data = state.get_player_data(event.player_index)

    if player_data.opened_network_gui then
        network_gui.destroy(player)
        player_data.opened_network_gui = false
    else
        network_gui.create(player)
        player_data.opened_network_gui = true
    end
end

--- Handle player created (new player joins for the first time)
---@param event EventData.on_player_created
local function on_player_created(event)
    local player = game.get_player(event.player_index)
    if player then
        chest_gui.create_relative_panel(player)
        provider_gui.create_relative_panel(player)
        network_gui.restore_pin_hud(player)
    end
end

--- Handle player joined game (existing player rejoins)
---@param event EventData.on_player_joined_game
local function on_player_joined_game(event)
    local player = game.get_player(event.player_index)
    if player then
        chest_gui.create_relative_panel(player)
        provider_gui.create_relative_panel(player)
        network_gui.restore_pin_hud(player)
    end
end

--- Initialize relative panels for all existing players
--- Called from control.lua on_init and on_configuration_changed
function M.init_player_guis()
    for _, player in pairs(game.players) do
        chest_gui.create_relative_panel(player)
        provider_gui.create_relative_panel(player)
        network_gui.restore_pin_hud(player)
    end
end

--- Refresh all open GUIs with live data
--- Called periodically from control.lua on_nth_tick
function M.refresh_open_guis()
    for _, player in pairs(game.players) do
        local pdata = state.get_player_data(player.index)
        if pdata.opened_network_gui then
            network_gui.update_live(player)
        end
        if pdata.opened_chest and pdata.opened_chest.valid then
            chest_gui.update_live(player)
        end
        if pdata.opened_provider_chest and pdata.opened_provider_chest.valid then
            provider_gui.update_live(player)
        end
        -- Always update HUD (even when GUI is closed)
        network_gui.update_pin_hud(player)
    end
end

--- Register all event handlers
function M.register()
    -- Chest built events (both global-chest and global-provider-chest)
    script.on_event(defines.events.on_built_entity, on_any_chest_built, all_chests_filter)
    script.on_event(defines.events.on_robot_built_entity, on_any_chest_built, all_chests_filter)
    script.on_event(defines.events.script_raised_built, on_any_chest_built, all_chests_filter)
    script.on_event(defines.events.on_entity_cloned, on_any_chest_built, all_chests_filter)

    -- Chest destroyed events (both global-chest and global-provider-chest)
    script.on_event(defines.events.on_player_mined_entity, on_any_chest_destroyed, all_chests_filter)
    script.on_event(defines.events.on_robot_mined_entity, on_any_chest_destroyed, all_chests_filter)
    script.on_event(defines.events.on_entity_died, on_any_chest_destroyed, all_chests_filter)
    script.on_event(defines.events.script_raised_destroy, on_any_chest_destroyed, all_chests_filter)

    -- Copy-paste
    script.on_event(defines.events.on_entity_settings_pasted, on_entity_settings_pasted)

    -- GUI events
    script.on_event(defines.events.on_gui_opened, on_gui_opened)
    script.on_event(defines.events.on_gui_closed, on_gui_closed)

    -- Player events
    script.on_event(defines.events.on_player_created, on_player_created)
    script.on_event(defines.events.on_player_joined_game, on_player_joined_game)

    -- Hotkey
    script.on_event(constants.NETWORK_GUI_HOTKEY, on_hotkey_pressed)
end

return M
