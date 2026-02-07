local M = {}

-- Entity
M.GLOBAL_CHEST_ENTITY_NAME = "global-chest"
M.GLOBAL_PROVIDER_CHEST_ENTITY_NAME = "global-provider-chest"
M.DEFAULT_NETWORK_NAME = "global-storage-default"

-- Hotkeys
M.NETWORK_GUI_HOTKEY = "global-network-hotkey"

-- GUI element names
M.GUI = {
    -- Chest GUI - Relative panel (appears next to vanilla linked container UI)
    CHEST_RELATIVE_PANEL = "gn_chest_panel",
    CHEST_FRAME = "gn_chest_frame",
    CHEST_NETWORK_ID_FIELD = "gn_chest_network_id",
    CHEST_NETWORK_ID_LABEL = "gn_chest_network_id_label",
    CHEST_NETWORK_EDIT_BUTTON = "gn_chest_network_edit",
    CHEST_NETWORK_CONFIRM_BUTTON = "gn_chest_network_confirm",
    CHEST_NETWORK_CANCEL_BUTTON = "gn_chest_network_cancel",
    CHEST_NETWORK_LIST_SCROLL = "gn_chest_network_list_scroll",
    CHEST_NETWORK_LIST_BUTTON = "gn_chest_network_list_btn",
    CHEST_NETWORK_DISPLAY_FLOW = "gn_chest_network_display",
    CHEST_NETWORK_EDIT_FLOW = "gn_chest_network_edit_flow",
    CHEST_REQUEST_SLOT = "gn_chest_request_slot",
    CHEST_REQUEST_SPRITE_BUTTON = "gn_chest_request_sprite",
    CHEST_REQUEST_SLOT_FLOW = "gn_chest_request_slot_flow",

    -- Request popup
    CHEST_REQUEST_POPUP = "gn_chest_request_popup",
    CHEST_REQUEST_MIN_FIELD = "gn_chest_request_min",
    CHEST_REQUEST_MAX_FIELD = "gn_chest_request_max",
    CHEST_REQUEST_MIN_SLIDER = "gn_chest_request_min_slider",
    CHEST_REQUEST_MAX_SLIDER = "gn_chest_request_max_slider",
    CHEST_REQUEST_CONFIRM = "gn_chest_request_confirm",
    CHEST_REQUEST_CANCEL = "gn_chest_request_cancel",

    -- Network GUI (Shift+G)
    NETWORK_FRAME = "gn_network_frame",
    NETWORK_TABS = "gn_network_tabs",

    -- Network list tab
    NETWORKS_TAB = "gn_networks_tab",
    NETWORKS_TABLE = "gn_networks_table",
    NETWORKS_SCROLL = "gn_networks_scroll",
    NETWORK_DELETE_BUTTON = "gn_network_delete",

    -- Global inventory tab
    INVENTORY_TAB = "gn_inventory_tab",
    INVENTORY_SCROLL = "gn_inventory_scroll",
    INVENTORY_ADD_LIMIT_BUTTON = "gn_inventory_add_limit",
    INVENTORY_FILTER_NO_LIMIT_CHECKBOX = "gn_inventory_filter_no_limit",

    -- Dynamic element prefixes (for live updates)
    NETWORK_CHEST_COUNT_LABEL = "gn_net_chests_",
    NETWORK_REQUEST_COUNT_LABEL = "gn_net_reqs_",
    NETWORK_STATUS_LABEL = "gn_net_status_",

    -- Inventory grid (new compact view)
    INVENTORY_GRID = "gn_inventory_grid",
    INVENTORY_GRID_CELL = "gn_inv_cell_",  -- prefix + item_name

    -- Inventory edit popup
    INVENTORY_EDIT_POPUP = "gn_inventory_edit_popup",
    INVENTORY_EDIT_LIMIT_FIELD = "gn_inv_edit_limit",
    INVENTORY_EDIT_UNLIMITED_CB = "gn_inv_edit_unlimited",
    INVENTORY_EDIT_PIN_CB = "gn_inv_edit_pin",
    INVENTORY_EDIT_CONFIRM = "gn_inv_edit_confirm",
    INVENTORY_EDIT_REMOVE = "gn_inv_edit_remove",

    -- HUD pins
    PIN_HUD_FRAME = "gn_pin_hud_frame",
    PIN_HUD_FLOW = "gn_pin_hud_flow_",  -- prefix + item_name
    PIN_HUD_LABEL = "gn_pin_hud_label_",  -- prefix + item_name

    -- Delete network confirmation popup
    NETWORK_DELETE_CONFIRM_POPUP = "gn_network_delete_confirm",
    NETWORK_DELETE_CONFIRM_YES = "gn_network_delete_yes",
    NETWORK_DELETE_CONFIRM_NO = "gn_network_delete_no",

    -- Provider chest GUI - Relative panel
    PROVIDER_RELATIVE_PANEL = "gn_provider_panel",
    PROVIDER_FRAME = "gn_provider_frame",
    PROVIDER_REQUEST_FLOW = "gn_provider_request_flow",
    PROVIDER_REQUEST_SLOT = "gn_provider_request_slot",
    PROVIDER_REQUEST_SPRITE_BUTTON = "gn_provider_request_sprite",
    PROVIDER_REQUEST_POPUP = "gn_provider_request_popup",
    PROVIDER_REQUEST_QUANTITY_FIELD = "gn_provider_request_qty",
    PROVIDER_REQUEST_QUANTITY_SLIDER = "gn_provider_request_qty_slider",
    PROVIDER_REQUEST_CONFIRM = "gn_provider_request_confirm",
    PROVIDER_REQUEST_CANCEL = "gn_provider_request_cancel",

    -- Player logistics tab
    PLAYER_LOGISTICS_TAB = "gn_player_logistics_tab",
    PLAYER_LOGISTICS_ENABLED_CHECKBOX = "gn_player_logistics_enabled",

    -- Auto-pin low stock
    AUTO_PIN_LOW_STOCK_CHECKBOX = "gn_auto_pin_low_stock",
    PIN_HUD_MANUAL_SECTION = "gn_pin_hud_manual",
    PIN_HUD_AUTO_SECTION = "gn_pin_hud_auto",
    PIN_HUD_AUTO_HEADER = "gn_pin_hud_auto_header",
    AUTO_PIN_HUD_FLOW = "gn_auto_pin_hud_flow_",
    AUTO_PIN_HUD_LABEL = "gn_auto_pin_hud_label_",

    -- Network buffer controls
    NETWORK_BUFFER_LABEL = "gn_net_buf_label",         -- prefix + _network_name
    NETWORK_BUFFER_ADD_BUTTON = "gn_net_buf_add",      -- prefix + _network_name
    NETWORK_BUFFER_REMOVE_BUTTON = "gn_net_buf_rem",   -- prefix + _network_name
}

-- Processing
M.PROCESS_INTERVAL = 10  -- ticks between processing runs
M.NETWORKS_PER_TICK = 20 -- networks processed per tick (round-robin)

-- Limits
M.UNLIMITED = -1  -- Special value: no limit (accept all)

-- Copy-paste network naming
M.COPY_PASTE_NETWORK_PREFIX = "Req:"  -- prefix for auto-generated ingredient networks

-- Multi-buffer (inventory sharding)
M.MAX_BUFFER_COUNT = 16       -- maximum buffers per network

-- Auto-pin thresholds
M.LOW_STOCK_THRESHOLD = 0.10  -- 10%
M.AUTO_PIN_MAX_ITEMS = 10

return M
