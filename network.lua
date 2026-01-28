local state = require("state")
local constants = require("constants")

local M = {}

--- Set a request on a network
---@param network_name string
---@param item_name string
---@param min number Minimum quantity to maintain
---@param max number Maximum quantity before returning to pool
function M.set_request(network_name, item_name, min, max)
    local network = state.get_or_create_network(network_name)
    if not network then return end

    if min <= 0 and max <= 0 then
        network.requests[item_name] = nil
    else
        network.requests[item_name] = {
            min = math.max(0, min or 0),
            max = math.max(0, max or 0)
        }
    end
end

--- Remove a request from a network
---@param network_name string
---@param item_name string
function M.remove_request(network_name, item_name)
    local network = storage.networks[network_name]
    if network then
        network.requests[item_name] = nil
    end
end

--- Get all requests for a network
---@param network_name string
---@return table|nil requests
function M.get_requests(network_name)
    local network = storage.networks[network_name]
    if network then
        return network.requests
    end
    return nil
end

--- Change a chest's network (update link_id)
--- Note: items stay in old network (linked container behavior)
---@param chest LuaEntity
---@param new_network_name string
---@param manual boolean|nil If true, marks network as manually created (shown in list)
function M.set_chest_network(chest, new_network_name, manual)
    if not chest or not chest.valid then return end

    -- Get old network from our tracking (not from link_id which may be stale after copy-paste)
    local old_network_name = state.get_chest_tracked_network(chest.unit_number)

    -- Decrement old network chest count
    if old_network_name and storage.networks[old_network_name] then
        storage.networks[old_network_name].chest_count =
            math.max(0, (storage.networks[old_network_name].chest_count or 0) - 1)
    end

    -- Set new link_id and update tracking
    if new_network_name and new_network_name ~= "" then
        local new_link_id = state.get_link_id(new_network_name)
        chest.link_id = new_link_id
        state.set_chest_tracked_network(chest.unit_number, new_network_name)

        -- Create network if needed and increment chest count
        local network = state.get_or_create_network(new_network_name, manual)
        if network then
            network.chest_count = (network.chest_count or 0) + 1
        end
    else
        chest.link_id = 0
        state.remove_chest_tracking(chest.unit_number)
    end
end

--- Get the network name for a chest
---@param chest LuaEntity
---@return string|nil network_name
function M.get_chest_network_name(chest)
    if not chest or not chest.valid then return nil end
    local link_id = chest.link_id
    if link_id == 0 then return nil end
    return state.get_network_name(link_id)
end

--- Increment chest count for a network (called when chest built with existing link_id)
---@param link_id number
---@param unit_number number
function M.on_chest_built(link_id, unit_number)
    local network_name = state.get_network_name(link_id)
    if network_name and storage.networks[network_name] then
        storage.networks[network_name].chest_count =
            (storage.networks[network_name].chest_count or 0) + 1
        state.set_chest_tracked_network(unit_number, network_name)
    end
end

--- Decrement chest count for a network (called when chest destroyed)
---@param link_id number
function M.on_chest_destroyed(link_id)
    local network_name = state.get_network_name(link_id)
    if network_name and storage.networks[network_name] then
        storage.networks[network_name].chest_count =
            math.max(0, (storage.networks[network_name].chest_count or 0) - 1)
    end
end

--- Set global limit for an item
---@param item_name string
---@param limit number|nil Set to nil to remove (block), -1 for unlimited, >0 for numeric limit
function M.set_limit(item_name, limit)
    if limit == constants.UNLIMITED then
        storage.limits[item_name] = constants.UNLIMITED
    elseif limit and limit > 0 then
        storage.limits[item_name] = limit
    else
        storage.limits[item_name] = nil  -- Blocked
    end
end

--- Get global limit for an item
---@param item_name string
---@return number|nil limit
function M.get_limit(item_name)
    return storage.limits[item_name]
end

--- Add items to global inventory (respects limits)
--- nil = blocked, -1 = unlimited, >0 = numeric limit
---@param item_name string
---@param count number
---@return number added Actual amount added
function M.add_to_inventory(item_name, count)
    local current = storage.inventory[item_name] or 0
    local limit = storage.limits[item_name]

    local to_add = 0
    if limit == nil then
        to_add = 0  -- No limit defined = blocked
    elseif limit == constants.UNLIMITED then
        to_add = count  -- Unlimited
    elseif limit > 0 then
        to_add = math.min(count, math.max(0, limit - current))
    end

    if to_add > 0 then
        storage.inventory[item_name] = current + to_add
    end

    return to_add
end

--- Remove items from global inventory
---@param item_name string
---@param count number
---@return number removed Actual amount removed
function M.remove_from_inventory(item_name, count)
    local current = storage.inventory[item_name] or 0
    local to_remove = math.min(count, current)

    if to_remove > 0 then
        storage.inventory[item_name] = current - to_remove
        if storage.inventory[item_name] <= 0 then
            storage.inventory[item_name] = nil
        end
    end

    return to_remove
end

return M
