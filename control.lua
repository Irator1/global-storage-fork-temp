local constants = require("constants")
local state = require("state")
local events = require("events")
local processor = require("processor")
local chest_gui = require("chest_gui")
local network_gui = require("network_gui")
local provider_gui = require("provider_gui")

-- Initialize storage on new game
script.on_init(function()
    state.init()
    events.init_player_guis()
end)

-- Restore state on load
script.on_load(function()
    -- Nothing special needed, storage is automatically restored
end)

-- Handle configuration changes (migrations, mod updates)
script.on_configuration_changed(function(data)
    state.init()  -- Ensure all storage fields exist
    state.recalculate_chest_counts()  -- Fix chest_count for all networks
    state.rescan_provider_chests()  -- Re-register provider chests

    -- Force HUD refresh for all players on configuration change
    for _, player in pairs(game.players) do
        local pdata = state.get_player_data(player.index)
        pdata.hud_needs_refresh = true
    end

    events.init_player_guis()  -- Recreate relative panels for all players
end)

-- Register all event handlers
events.register()

-- Centralized GUI event registration (to avoid conflicts)
script.on_event(defines.events.on_gui_click, function(event)
    chest_gui.on_gui_click(event)
    network_gui.on_gui_click(event)
    provider_gui.on_gui_click(event)
end)

script.on_event(defines.events.on_gui_elem_changed, function(event)
    chest_gui.on_gui_elem_changed(event)
    network_gui.on_gui_elem_changed(event)
    provider_gui.on_gui_elem_changed(event)
end)

script.on_event(defines.events.on_gui_text_changed, function(event)
    chest_gui.on_gui_text_changed(event)
    network_gui.on_gui_text_changed(event)
    provider_gui.on_gui_text_changed(event)
end)

script.on_event(defines.events.on_gui_value_changed, function(event)
    chest_gui.on_gui_value_changed(event)
    provider_gui.on_gui_value_changed(event)
end)

script.on_event(defines.events.on_gui_checked_state_changed, function(event)
    network_gui.on_gui_checked_state_changed(event)
end)

script.on_event(defines.events.on_gui_confirmed, function(event)
    chest_gui.on_gui_confirmed(event)
    network_gui.on_gui_confirmed(event)
    provider_gui.on_gui_confirmed(event)
end)

-- Process distribution every N ticks
script.on_nth_tick(constants.PROCESS_INTERVAL, function()
    processor.process()
end)

-- Refresh open GUIs every 30 ticks (~0.5 second)
script.on_nth_tick(30, function()
    events.refresh_open_guis()
end)
