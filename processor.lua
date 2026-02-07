local constants = require("constants")
local player_logistics = require("player_logistics")

local M = {}

-- Localize frequently used globals for minor Lua performance gain
local UNLIMITED = constants.UNLIMITED
local ENTITY_NAME = constants.GLOBAL_CHEST_ENTITY_NAME

--- Process a single linked inventory: collect surplus and distribute to meet requests
---@param linked_inv LuaInventory
---@param requests table Network requests {item_name = {min, max}}
---@param inv table Reference to storage.inventory
---@param limits table Reference to storage.limits
local function process_single_buffer(linked_inv, requests, inv, limits)
    local contents = linked_inv.get_contents()

    -- Build a lookup table for faster access
    local content_counts = {}
    for _, item in pairs(contents) do
        content_counts[item.name] = (content_counts[item.name] or 0) + item.count
    end

    -- 1. Collect surplus (items above max or not in requests)
    for item_name, count in pairs(content_counts) do
        local request = requests[item_name]
        local max_wanted = request and request.max or 0

        if count > max_wanted then
            local surplus = count - max_wanted

            -- Check global limit (nil = blocked, -1 = unlimited, >0 = numeric limit)
            local limit = limits[item_name]
            local current_global = inv[item_name] or 0

            local can_accept = 0
            if limit == nil then
                -- New item: create limit at 0 so it appears in GUI
                limits[item_name] = 0
                can_accept = 0  -- Blocked until player sets a limit
            elseif limit == UNLIMITED then
                can_accept = surplus  -- Unlimited
            elseif limit > 0 then
                can_accept = math.min(surplus, math.max(0, limit - current_global))
            end

            if can_accept > 0 then
                local removed = linked_inv.remove({ name = item_name, count = can_accept })
                if removed > 0 then
                    inv[item_name] = (inv[item_name] or 0) + removed
                end
            end
        end
    end

    -- 2. Distribute to meet minimum requests
    for item_name, request in pairs(requests) do
        local current = content_counts[item_name] or 0

        if current < request.min then
            local needed = request.min - current
            local available = inv[item_name] or 0
            local to_insert = math.min(needed, available)

            if to_insert > 0 then
                local inserted = linked_inv.insert({ name = item_name, count = to_insert })
                if inserted > 0 then
                    inv[item_name] = (inv[item_name] or 0) - inserted
                    if inv[item_name] <= 0 then
                        inv[item_name] = nil
                    end
                end
            end
        end
    end
end

--- Process a single network: collect surplus and distribute to meet requests
--- Multi-buffer aware: processes all link_ids belonging to the network
---@param network_name string
---@param network table Network data
---@param force LuaForce
---@param inv table Reference to storage.inventory
---@param limits table Reference to storage.limits
local function process_network(network_name, network, force, inv, limits)
    local requests = network.requests
    local link_ids = network.link_ids
    if not link_ids then return end

    for _, lid in ipairs(link_ids) do
        if lid and lid ~= 0 then
            local linked_inv = force.get_linked_inventory(ENTITY_NAME, lid)
            if linked_inv then
                process_single_buffer(linked_inv, requests, inv, limits)
            end
        end
    end
end

--- Rebuild network list for round-robin iteration
function M.rebuild_network_list()
    storage.network_list = {}
    for network_name in pairs(storage.networks) do
        storage.network_list[#storage.network_list + 1] = network_name
    end
    storage.network_index = 1
end

--- Process all provider chests: fill them from the global pool according to their requests
---@param inv table Reference to storage.inventory
local function process_provider_chests(inv)
    if not storage.provider_chests then return end

    for unit_number, data in pairs(storage.provider_chests) do
        if not data.entity or not data.entity.valid then
            -- Clean up invalid entries
            storage.provider_chests[unit_number] = nil
        else
            local chest_inv = data.entity.get_inventory(defines.inventory.chest)
            if chest_inv then
                -- Fill according to requests
                for item_name, target in pairs(data.requests) do
                    local current = chest_inv.get_item_count(item_name)
                    local needed = target - current
                    local available = inv[item_name] or 0

                    if needed > 0 and available > 0 then
                        local to_insert = math.min(needed, available)
                        local inserted = chest_inv.insert({name = item_name, count = to_insert})
                        if inserted > 0 then
                            inv[item_name] = inv[item_name] - inserted
                            if inv[item_name] <= 0 then
                                inv[item_name] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

--- Main processing function - called every PROCESS_INTERVAL ticks
--- Uses round-robin to distribute load across multiple ticks
function M.process()
    -- Get active force (first force with players)
    local active_force = nil
    for _, force in pairs(game.forces) do
        if #force.players > 0 then
            active_force = force
            break
        end
    end
    if not active_force then return end

    -- Rebuild network list if invalidated
    if not storage.network_list then
        M.rebuild_network_list()
    end

    local list = storage.network_list
    local total = #list
    if total == 0 then
        -- Still process player logistics even with no networks
        player_logistics.process()
        return
    end

    -- Cache storage tables as locals (minor Lua perf: local access faster than table field)
    local inv = storage.inventory
    local limits = storage.limits

    -- Process a batch of networks (round-robin)
    local start_index = storage.network_index or 1
    local count = 0
    local max_count = math.min(constants.NETWORKS_PER_TICK, total)

    while count < max_count do
        local network_name = list[start_index]
        if network_name then
            local network = storage.networks[network_name]
            if network then
                process_network(network_name, network, active_force, inv, limits)
            end
        end

        count = count + 1
        start_index = start_index + 1
        if start_index > total then
            start_index = 1  -- Wrap around
        end
    end

    -- Save position for next tick
    storage.network_index = start_index

    -- Process provider chests (fill from global pool)
    process_provider_chests(inv)

    -- Process player logistics (lightweight, runs every tick)
    player_logistics.process()
end

return M
