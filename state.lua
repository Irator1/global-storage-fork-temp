local constants = require("constants")
local quality = require("quality")

local M = {}

--- Allocate the next unique link_id for a new network
--- Uses a sequential counter stored in storage.next_link_id
--- Link_id 0 means "no network" in linked containers, so we start at 1
---@return number link_id
function M.allocate_link_id()
    local id = storage.next_link_id or 1
    storage.next_link_id = id + 1
    return id
end

--- Initialize storage structure for new game
function M.init()
    storage.networks = storage.networks or {}
    storage.inventory = storage.inventory or {}
    storage.limits = storage.limits or {}
    storage.previous_limits = storage.previous_limits or {}
    storage.link_id_to_network = storage.link_id_to_network or {}
    storage.player_data = storage.player_data or {}
    storage.provider_chests = storage.provider_chests or {}
    storage.chest_networks = storage.chest_networks or {}

    -- Sequential link_id counter (starts at 1, 0 = no network)
    storage.next_link_id = storage.next_link_id or 1

    -- Rebuild reverse mapping from existing networks
    for name, network in pairs(storage.networks) do
        -- Register all link_ids in reverse mapping
        for _, lid in ipairs(network.link_ids) do
            if lid then
                storage.link_id_to_network[lid] = name
                -- Ensure counter stays ahead of all existing IDs
                if lid >= storage.next_link_id then
                    storage.next_link_id = lid + 1
                end
            end
        end
    end

    -- Reset round-robin state for rebuild
    storage.network_list = nil
    storage.network_index = 1
end

--- Recalculate chest_count for all networks by scanning all surfaces
--- Also rebuilds chest_networks tracking table
--- Called on configuration changed to fix any desync
function M.recalculate_chest_counts()
    -- Reset all counts to 0
    for _, network in pairs(storage.networks) do
        network.chest_count = 0
    end

    -- Reset chest tracking
    storage.chest_networks = {}

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
                        -- Also rebuild chest tracking
                        storage.chest_networks[chest.unit_number] = network_name
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
        local link_id = M.allocate_link_id()

        storage.networks[name] = {
            chest_count = 0,
            requests = {},
            manual = manual or false,
            link_id = link_id,
            link_ids = {link_id},
            buffer_count = 1,
            next_buffer_assign = 1,
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

--- Set tracked network for a chest (by unit_number)
---@param unit_number number
---@param network_name string
function M.set_chest_tracked_network(unit_number, network_name)
    storage.chest_networks = storage.chest_networks or {}
    storage.chest_networks[unit_number] = network_name
end

--- Get tracked network for a chest (by unit_number)
---@param unit_number number
---@return string|nil network_name
function M.get_chest_tracked_network(unit_number)
    if not storage.chest_networks then return nil end
    return storage.chest_networks[unit_number]
end

--- Remove tracking for a chest (by unit_number)
---@param unit_number number
function M.remove_chest_tracking(unit_number)
    if not storage.chest_networks then return end
    storage.chest_networks[unit_number] = nil
end

--- Delete a network and transfer its items to global pool
---@param name string Network name
---@param force LuaForce Force to access linked inventory
function M.delete_network(name, force)
    local network = storage.networks[name]
    if not network then return end

    -- Transfer items from ALL linked inventories to global pool
    local link_ids = network.link_ids
    for _, lid in ipairs(link_ids) do
        if lid and lid ~= 0 then
            local linked_inv = force.get_linked_inventory(constants.GLOBAL_CHEST_ENTITY_NAME, lid)
            if linked_inv then
                local contents = linked_inv.get_contents()
                for _, item in pairs(contents) do
                    local item_key = quality.key_from_contents(item)
                    local count = item.count
                    local current = storage.inventory[item_key] or 0
                    -- Bypass limits on deletion: never lose items
                    storage.inventory[item_key] = current + count
                    linked_inv.remove(quality.make_stack(item_key, count))
                end
            end
            -- Remove reverse mapping for this link_id
            storage.link_id_to_network[lid] = nil
        end
    end

    -- Remove network
    storage.networks[name] = nil
    -- Invalidate network list for round-robin rebuild
    storage.network_list = nil
end

--- Remove the last buffer from a network
--- Drains items from the removed buffer to global pool, reassigns chests to remaining buffers
---@param name string Network name
---@return boolean success
function M.remove_network_buffer(name)
    local network = storage.networks[name]
    if not network then return false end

    local link_ids = network.link_ids
    if not link_ids or #link_ids <= 1 then return false end -- Can't remove last buffer

    -- Remove the last link_id
    local removed_lid = link_ids[#link_ids]
    link_ids[#link_ids] = nil
    network.buffer_count = #link_ids

    -- Fix next_buffer_assign if it's now out of range
    if network.next_buffer_assign and network.next_buffer_assign > #link_ids then
        network.next_buffer_assign = 1
    end

    -- Drain items from the removed buffer's linked inventory to global pool
    -- Get force (first force with players)
    local force = nil
    for _, f in pairs(game.forces) do
        if #f.players > 0 then
            force = f
            break
        end
    end

    if force and removed_lid and removed_lid ~= 0 then
        local linked_inv = force.get_linked_inventory(constants.GLOBAL_CHEST_ENTITY_NAME, removed_lid)
        if linked_inv then
            local contents = linked_inv.get_contents()
            for _, item in pairs(contents) do
                -- Bypass limits: never lose items during buffer removal
                local item_key = quality.key_from_contents(item)
                storage.inventory[item_key] = (storage.inventory[item_key] or 0) + item.count
                linked_inv.remove(quality.make_stack(item_key, item.count))
            end
        end
    end

    -- Reassign any chests using the removed link_id to the first buffer
    local target_lid = link_ids[1]
    if removed_lid and removed_lid ~= 0 and target_lid then
        for _, surface in pairs(game.surfaces) do
            local chests = surface.find_entities_filtered({
                name = constants.GLOBAL_CHEST_ENTITY_NAME
            })
            for _, chest in pairs(chests) do
                if chest.valid and chest.link_id == removed_lid then
                    chest.link_id = target_lid
                end
            end
        end
    end

    -- Remove reverse mapping
    if removed_lid then
        storage.link_id_to_network[removed_lid] = nil
    end

    return true
end

--- Add buffers to a network (increase buffer_count)
--- Allocates new link_ids and registers them
---@param name string Network name
---@param new_count number Target buffer count (must be > current)
---@return boolean success
function M.set_network_buffer_count(name, new_count)
    local network = storage.networks[name]
    if not network then return false end

    new_count = math.max(1, math.min(new_count, constants.MAX_BUFFER_COUNT))

    local current = #network.link_ids
    if new_count <= current then return false end -- Only allow increasing

    -- Allocate additional link_ids
    for _ = current + 1, new_count do
        local new_lid = M.allocate_link_id()
        network.link_ids[#network.link_ids + 1] = new_lid
        storage.link_id_to_network[new_lid] = name
    end

    network.buffer_count = new_count
    return true
end

--- Get the next link_id to assign a chest to (round-robin across buffers)
---@param network table Network data
---@return number link_id
function M.get_next_buffer_link_id(network)
    local link_ids = network.link_ids
    if #link_ids == 1 then
        return link_ids[1]
    end

    local idx = network.next_buffer_assign or 1
    if idx > #link_ids then idx = 1 end
    local lid = link_ids[idx]
    network.next_buffer_assign = (idx % #link_ids) + 1
    return lid
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
    -- Ensure all fields exist (defensive, in case structure was extended)
    local pdata = storage.player_data[player_index]
    if not pdata.pinned_items then pdata.pinned_items = {} end
    if not pdata.pin_hud_elements then pdata.pin_hud_elements = {} end
    if not pdata.inventory_grid_cache then pdata.inventory_grid_cache = {} end
    if pdata.auto_pin_low_stock_enabled == nil then pdata.auto_pin_low_stock_enabled = false end
    if not pdata.auto_pinned_items then pdata.auto_pinned_items = {} end
    if not pdata.auto_pin_hud_elements then pdata.auto_pin_hud_elements = {} end
    -- Flag to force HUD refresh on next update (set on migration/load)
    if pdata.hud_needs_refresh == nil then pdata.hud_needs_refresh = true end
    return pdata
end

--- Reassign all chests from one network to another (or default)
--- Used when deleting a network that still has chests
---@param old_network_name string Network being deleted
---@param new_network_name string|nil Target network (nil = default)
---@return number count Number of chests reassigned
function M.reassign_network_chests(old_network_name, new_network_name)
    local old_network = storage.networks[old_network_name]
    if not old_network then return 0 end

    -- Collect all link_ids from old network
    local old_link_ids = old_network.link_ids
    local old_lid_set = {}
    for _, lid in ipairs(old_link_ids) do
        if lid and lid ~= 0 then
            old_lid_set[lid] = true
        end
    end
    if not next(old_lid_set) then return 0 end

    local target_network = new_network_name or constants.DEFAULT_NETWORK_NAME

    -- Ensure target network exists (allocates link_id if new)
    local target_net = M.get_or_create_network(target_network)
    if not target_net then return 0 end
    -- Assign chests to a buffer in the target network
    local count = 0

    -- Scan all surfaces for chests with any of the old link_ids
    for _, surface in pairs(game.surfaces) do
        local chests = surface.find_entities_filtered({
            name = constants.GLOBAL_CHEST_ENTITY_NAME
        })

        for _, chest in pairs(chests) do
            if chest.valid and old_lid_set[chest.link_id] then
                local new_lid = M.get_next_buffer_link_id(target_net)
                chest.link_id = new_lid
                M.set_chest_tracked_network(chest.unit_number, target_network)
                count = count + 1
            end
        end
    end

    -- Update target network chest count
    target_net.chest_count = (target_net.chest_count or 0) + count

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
