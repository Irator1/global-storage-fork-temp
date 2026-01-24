local constants = require("constants")

local M = {}

--- Hash function to convert network name to link_id
--- Same algorithm as original chest_ids.lua
---@param name string Network name
---@return number link_id
function M.get_link_id(name)
    if not name or name == "" then
        return 0
    end
    local hash = 0
    for i = 1, #name do
        hash = (hash * i + string.byte(name, i) * i) % (2 ^ 32)
    end
    return hash
end

--- Initialize storage structure for new game
function M.init()
    storage.networks = storage.networks or {}
    storage.inventory = storage.inventory or {}
    storage.limits = storage.limits or {}
    storage.previous_limits = storage.previous_limits or {}  -- Remembers last numeric limit when switching to unlimited
    storage.link_id_to_network = storage.link_id_to_network or {}
    storage.player_data = storage.player_data or {}
    storage.provider_chests = storage.provider_chests or {}  -- Provider chests with per-chest requests

    -- Migration: add cached link_id to existing networks and rebuild reverse mapping
    for name, network in pairs(storage.networks) do
        local link_id = M.get_link_id(name)
        if not network.link_id then
            network.link_id = link_id
        end
        -- Ensure reverse mapping exists
        storage.link_id_to_network[link_id] = name
    end

    -- Reset round-robin state for rebuild
    storage.network_list = nil
    storage.network_index = 1
end

--- Recalculate chest_count for all networks by scanning all surfaces
--- Called on configuration changed to fix any desync
function M.recalculate_chest_counts()
    -- Reset all counts to 0
    for _, network in pairs(storage.networks) do
        network.chest_count = 0
    end

    -- Scan all surfaces for chests
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = constants.GLOBAL_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid then
                local link_id = chest.link_id
                if link_id and link_id ~= 0 then
                    local network_name = storage.link_id_to_network[link_id]
                    if network_name and storage.networks[network_name] then
                        storage.networks[network_name].chest_count =
                            (storage.networks[network_name].chest_count or 0) + 1
                    end
                end
            end
        end
    end
end

--- Get or create network by name
---@param name string Network name
---@param manual boolean|nil If true, marks network as manually created (shown in list)
---@return table network Network data
function M.get_or_create_network(name, manual)
    if not name or name == "" then
        return nil
    end

    if not storage.networks[name] then
        local link_id = M.get_link_id(name)
        storage.networks[name] = {
            chest_count = 0,
            requests = {},
            manual = manual or false,
            link_id = link_id  -- Cache hash for processor performance
        }
        -- Store reverse mapping
        storage.link_id_to_network[link_id] = name
        -- Invalidate network list for round-robin rebuild
        storage.network_list = nil
    elseif manual then
        -- If manually accessed, mark as manual
        storage.networks[name].manual = true
    end

    return storage.networks[name]
end

--- Get network name from link_id
---@param link_id number
---@return string|nil network_name
function M.get_network_name(link_id)
    return storage.link_id_to_network[link_id]
end

--- Delete a network and transfer its items to global pool
---@param name string Network name
---@param force LuaForce Force to access linked inventory
function M.delete_network(name, force)
    local network = storage.networks[name]
    if not network then return end

    -- Transfer items from linked inventory to global pool
    local link_id = M.get_link_id(name)
    local linked_inv = force.get_linked_inventory(constants.GLOBAL_CHEST_ENTITY_NAME, link_id)

    if linked_inv then
        local contents = linked_inv.get_contents()
        for _, item in pairs(contents) do
            local item_name = item.name
            local count = item.count
            local current = storage.inventory[item_name] or 0

            -- Bypass limits on deletion: priority = never lose items
            storage.inventory[item_name] = current + count
            linked_inv.remove({ name = item_name, count = count })
        end
    end

    -- Remove network
    storage.networks[name] = nil
    storage.link_id_to_network[link_id] = nil
    -- Invalidate network list for round-robin rebuild
    storage.network_list = nil
end

--- Get player data (create if needed)
---@param player_index number
---@return table player_data
function M.get_player_data(player_index)
    if not storage.player_data[player_index] then
        storage.player_data[player_index] = {
            opened_chest = nil,  -- LuaEntity (global-chest)
            opened_provider_chest = nil,  -- LuaEntity (global-provider-chest)
            opened_network_gui = false,
            pinned_items = {},  -- { ["iron-plate"] = true }
            pin_hud_elements = {},  -- cache HUD element references
            inventory_grid_cache = {},  -- cache grid element references
            auto_pin_low_stock_enabled = false,  -- auto-pin low stock items
            auto_pinned_items = {},  -- { ["iron-plate"] = true }
            auto_pin_hud_elements = {}  -- cache auto-pin HUD element references
        }
    end
    -- Migration: ensure new fields exist for existing player data
    local pdata = storage.player_data[player_index]
    if not pdata.pinned_items then pdata.pinned_items = {} end
    if not pdata.pin_hud_elements then pdata.pin_hud_elements = {} end
    if not pdata.inventory_grid_cache then pdata.inventory_grid_cache = {} end
    if pdata.opened_provider_chest == nil then pdata.opened_provider_chest = nil end
    if pdata.auto_pin_low_stock_enabled == nil then pdata.auto_pin_low_stock_enabled = false end
    if not pdata.auto_pinned_items then pdata.auto_pinned_items = {} end
    if not pdata.auto_pin_hud_elements then pdata.auto_pin_hud_elements = {} end
    -- Flag to force HUD refresh on next update (set on migration/load)
    if pdata.hud_needs_refresh == nil then pdata.hud_needs_refresh = true end
    return pdata
end

--- Clean up zero quantities in global inventory
function M.cleanup_inventory()
    for item_name, count in pairs(storage.inventory) do
        if count <= 0 then
            storage.inventory[item_name] = nil
        end
    end
end

--- Reassign all chests from one network to another (or default)
--- Used when deleting a network that still has chests
---@param old_network_name string Network being deleted
---@param new_network_name string|nil Target network (nil = default)
---@return number count Number of chests reassigned
function M.reassign_network_chests(old_network_name, new_network_name)
    local old_link_id = M.get_link_id(old_network_name)
    local target_network = new_network_name or constants.DEFAULT_NETWORK_NAME
    local new_link_id = M.get_link_id(target_network)

    -- Ensure target network exists
    M.get_or_create_network(target_network)

    local count = 0

    -- Scan all surfaces for chests with the old link_id
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = constants.GLOBAL_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid and chest.link_id == old_link_id then
                chest.link_id = new_link_id
                count = count + 1
            end
        end
    end

    -- Update target network chest count
    if storage.networks[target_network] then
        storage.networks[target_network].chest_count =
            (storage.networks[target_network].chest_count or 0) + count
    end

    return count
end

--- Register a provider chest (called when built)
---@param entity LuaEntity
function M.register_provider_chest(entity)
    if not entity or not entity.valid then return end

    storage.provider_chests[entity.unit_number] = {
        entity = entity,
        requests = {}
    }
end

--- Unregister a provider chest (called when destroyed)
---@param unit_number number
function M.unregister_provider_chest(unit_number)
    storage.provider_chests[unit_number] = nil
end

--- Get provider chest data
---@param unit_number number
---@return table|nil data Provider chest data or nil
function M.get_provider_data(unit_number)
    return storage.provider_chests[unit_number]
end

--- Set a request on a provider chest
---@param unit_number number
---@param item_name string
---@param quantity number
function M.set_provider_request(unit_number, item_name, quantity)
    local data = storage.provider_chests[unit_number]
    if not data then return end

    if quantity and quantity > 0 then
        data.requests[item_name] = quantity
    else
        data.requests[item_name] = nil
    end
end

--- Remove a request from a provider chest
---@param unit_number number
---@param item_name string
function M.remove_provider_request(unit_number, item_name)
    local data = storage.provider_chests[unit_number]
    if not data then return end

    data.requests[item_name] = nil
end

--- Rescan all provider chests on all surfaces
--- Called on configuration changed to fix any desync
function M.rescan_provider_chests()
    -- Ensure storage exists
    storage.provider_chests = storage.provider_chests or {}

    -- Clean up invalid entries
    for unit_number, data in pairs(storage.provider_chests) do
        if not data.entity or not data.entity.valid then
            storage.provider_chests[unit_number] = nil
        end
    end

    -- Scan all surfaces for provider chests
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid and not storage.provider_chests[chest.unit_number] then
                M.register_provider_chest(chest)
            end
        end
    end
end

return M
