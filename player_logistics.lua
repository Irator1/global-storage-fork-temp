local state = require("state")
local network_module = require("network")

local M = {}

--- Process a single player's logistics
---@param player LuaPlayer
local function process_player(player)
    local player_data = state.get_player_data(player.index)
    if not player_data.logistics_enabled then return end

    local character = player.character
    if not character or not character.valid then return end

    local main_inv = player.get_main_inventory()
    if not main_inv then return end

    -- 1. Build requests map from personal logistics
    local requests = {} -- { item_name = { min, max } }
    local logistic_point = character.get_requester_point()
    if logistic_point then
        for _, section in pairs(logistic_point.sections) do
            for i = 1, section.filters_count do
                local filter = section.get_slot(i)
                if filter and filter.value then
                    local item_name = filter.value.name or filter.value
                    if type(item_name) == "string" then
                        requests[item_name] = { min = filter.min or 0, max = filter.max }
                    end
                end
            end
        end
    end

    -- 2. SUPPLY: For each request, supply if current < min
    for item_name, req in pairs(requests) do
        if req.min and req.min > 0 then
            local current = main_inv.get_item_count(item_name)
            if current < req.min then
                local needed = req.min - current
                local removed = network_module.remove_from_inventory(item_name, needed)
                if removed > 0 then
                    main_inv.insert({ name = item_name, count = removed })
                end
            end
        end
    end

    -- 3. COLLECT TRASH: Empty trash into global pool (bypass limits)
    local trash_inv = player.get_inventory(defines.inventory.character_trash)
    if trash_inv then
        local contents = trash_inv.get_contents()
        for _, item in pairs(contents) do
            local removed = trash_inv.remove({ name = item.name, count = item.count })
            if removed > 0 then
                storage.inventory[item.name] = (storage.inventory[item.name] or 0) + removed
            end
        end
    end
end

--- Process all players' logistics
function M.process()
    for _, player in pairs(game.players) do
        if player.connected and player.character then
            process_player(player)
        end
    end
end

return M
