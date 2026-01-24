local constants = require("constants")

-- Add global chest as pastable target for all assembling machines
-- This allows copy-paste from assemblers to auto-configure the chest
local function add_global_chest_as_pastable_target()
    local chest_proto = data.raw["linked-container"][constants.GLOBAL_CHEST_ENTITY_NAME]
    if not chest_proto then return end

    local chest_paste_targets = chest_proto.additional_pastable_entities or {}

    for _, assembler in pairs(data.raw["assembling-machine"]) do
        -- Add chest as pastable target for assembler
        local entities = assembler.additional_pastable_entities or {}
        table.insert(entities, constants.GLOBAL_CHEST_ENTITY_NAME)
        assembler.additional_pastable_entities = entities

        -- Add assembler as pastable target for chest
        table.insert(chest_paste_targets, assembler.name)
    end

    -- Also add furnaces
    for _, furnace in pairs(data.raw["furnace"]) do
        local entities = furnace.additional_pastable_entities or {}
        table.insert(entities, constants.GLOBAL_CHEST_ENTITY_NAME)
        furnace.additional_pastable_entities = entities

        table.insert(chest_paste_targets, furnace.name)
    end

    chest_proto.additional_pastable_entities = chest_paste_targets
end

add_global_chest_as_pastable_target()
