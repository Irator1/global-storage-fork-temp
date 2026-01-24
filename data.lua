local constants = require("constants")

-- Custom subgroup for global storage items (own row in crafting menu)
local global_storage_subgroup = {
    type = "item-subgroup",
    name = "global-storage",
    group = "logistics",
    order = "ca[global-storage]"  -- After storage chests (c), before logistic-network (d)
}

-- Entity
local global_chest_entity = table.deepcopy(data.raw["linked-container"]["linked-chest"])
global_chest_entity.name = constants.GLOBAL_CHEST_ENTITY_NAME
global_chest_entity.inventory_type = "with_filters_and_bar"
global_chest_entity.minable.result = global_chest_entity.name

-- Item
local global_chest_item = table.deepcopy(data.raw["item"]["linked-chest"])
global_chest_item.name = constants.GLOBAL_CHEST_ENTITY_NAME
global_chest_item.place_result = global_chest_entity.name
global_chest_item.subgroup = "global-storage"
global_chest_item.order = "c[global-chest]"

-- Recipe
local global_chest_recipe = {
    name = global_chest_item.name,
    type = "recipe",
    enabled = true,
    energy_required = 0.5,
    ingredients = {
        { type = "item", name = "iron-plate", amount = 8 }
    },
    results = {{ type = "item", name = global_chest_item.name, amount = 1 }},
    subgroup = "global-storage",
    order = "c[global-chest]",
}

-- Hotkey for network GUI (Shift+G)
local network_gui_hotkey = {
    type = "custom-input",
    name = constants.NETWORK_GUI_HOTKEY,
    key_sequence = "SHIFT + G"
}

-- Global Provider Chest (passive provider that pulls from global storage)
local global_provider_entity = table.deepcopy(data.raw["logistic-container"]["passive-provider-chest"])
global_provider_entity.name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
global_provider_entity.minable.result = global_provider_entity.name
global_provider_entity.icon = "__base__/graphics/icons/passive-provider-chest.png"

local global_provider_item = table.deepcopy(data.raw["item"]["passive-provider-chest"])
global_provider_item.name = constants.GLOBAL_PROVIDER_CHEST_ENTITY_NAME
global_provider_item.place_result = global_provider_entity.name
global_provider_item.subgroup = "global-storage"
global_provider_item.order = "c[global-provider-chest]"

local global_provider_recipe = {
    name = global_provider_item.name,
    type = "recipe",
    enabled = false,
    energy_required = 0.5,
    ingredients = {
        { type = "item", name = "steel-chest", amount = 1 },
        { type = "item", name = "electronic-circuit", amount = 5 },
        { type = "item", name = "advanced-circuit", amount = 1 }
    },
    results = {{ type = "item", name = global_provider_item.name, amount = 1 }},
    subgroup = "global-storage",
    order = "c[global-provider-chest]",
}

data:extend({
    global_storage_subgroup,
    global_chest_item,
    global_chest_recipe,
    global_chest_entity,
    network_gui_hotkey,
    global_provider_item,
    global_provider_recipe,
    global_provider_entity,
})
