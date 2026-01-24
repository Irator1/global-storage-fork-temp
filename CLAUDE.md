# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is **Global Network**, a Factorio mod that adds a networked item storage and logistics system. Players can manage a global inventory pool with per-network requests and per-item storage limits.

- **Mod ID:** `global-storage`
- **Version:** 0.1.0
- **Factorio Version:** 2.0+
- **No build/test system** - the mod runs directly from this directory in Factorio's mods folder

## Key Concept: Network-Based Requests

**Performance optimization for megabases:** Requests are defined at the **network level**, not per-chest. All chests with the same network ID (link_id) share the same inventory via Factorio's linked-container system. The processor loops over networks (dozens) instead of individual chests (potentially thousands).

## Architecture

### Global State Structure (`storage` table)
```lua
storage.networks = {
    ["iron-gear-wheel"] = {
        chest_count = 5,           -- Number of chests with this network ID
        link_id = 12345,           -- Cached hash for performance
        requests = {
            ["iron-plate"] = { min = 100, max = 200 }
        }
    }
}
storage.inventory = {}             -- Global item pool (item_name → quantity)
storage.limits = {}                -- Per-item storage limits (nil=blocked, -1=unlimited, >0=numeric)
storage.previous_limits = {}       -- Remembers last numeric limit when switching to unlimited
storage.link_id_to_network = {}    -- Reverse mapping: link_id → network_name
storage.player_data = {}           -- Per-player UI state (pinned items, opened GUIs, HUD caches)
storage.provider_chests = {}       -- Provider chests: { [unit_number] = { entity, requests } }
storage.network_list = {}          -- Cached list of network names for round-robin processing
storage.network_index = 1          -- Current position in round-robin
```

### Core Modules

| File | Purpose |
|------|---------|
| `control.lua` | Entry point, event registration, nth_tick processing |
| `data.lua` | Entity/item/recipe/hotkey definitions (global-chest, global-provider-chest) |
| `data-final-fixes.lua` | Copy-paste compatibility for assemblers/furnaces |
| `constants.lua` | GUI element names, entity names, config values, processing intervals |
| `state.lua` | Storage initialization, hash function, network/provider chest management |
| `network.lua` | Network operations (requests, limits, chest network assignment) |
| `processor.lua` | Item distribution logic with round-robin processing |
| `events.lua` | All event handlers (build, destroy, paste, GUI open/close, hotkey) |
| `player_logistics.lua` | Player inventory logistics (personal requests, trash collection) |

### GUI Modules

| File | Purpose |
|------|---------|
| `chest_gui.lua` | Chest configuration (network ID, view/edit requests) - relative panel |
| `network_gui.lua` | Network management + global inventory + player logistics (Shift+G) |
| `provider_gui.lua` | Provider chest configuration (per-chest item requests) - relative panel |

### Two Chest Types

1. **`global-chest`** (linked-container): Shares inventory via network ID. All chests with same network ID share the same linked inventory. Requests are defined per-network.

2. **`global-provider-chest`** (logistic-container): Passive provider that pulls items FROM the global pool. Requests are defined per-chest.

### Data Flow

1. **Networks define requests** with min/max quantities per item
2. **Chests join networks** via text-based network ID (hashed to link_id)
3. **`processor.lua` runs every 10 ticks (round-robin, 20 networks per tick):**
   - For each network, gets linked inventory via `force.get_linked_inventory()`
   - Collects surplus items (above max) into `storage.inventory` (respects limits)
   - Distributes needed items (below min) from `storage.inventory`
4. **Provider chests** are filled from the global pool according to their per-chest requests
5. **Player logistics** fills player inventory from global pool based on personal logistics, collects trash
6. **Copy/paste from assemblers** auto-configures network requests from recipe ingredients

### Limits System

- `nil` = New item, blocked (appears in GUI with 0 limit)
- `0` = Explicitly blocked
- `-1` = Unlimited (use `constants.UNLIMITED`)
- `>0` = Numeric limit

### Hash Function (Network ID → Link ID)

```lua
function get_link_id(name)
    local hash = 0
    for i = 1, #name do
        hash = (hash * i + string.byte(name, i) * i) % (2^32)
    end
    return hash
end
```

### Module Pattern

All modules use:
```lua
local M = {}
-- functions
return M
```

**Important:** All `require()` calls must be at the top of files, not inside functions.

## Hotkeys

- **Shift+G** - Toggle network management GUI

## GUI Event Handling

GUI events are centralized in `control.lua` to avoid conflicts. Each GUI module exposes handler functions (`on_gui_click`, `on_gui_elem_changed`, `on_gui_text_changed`, `on_gui_value_changed`, `on_gui_confirmed`, `on_gui_checked_state_changed`) that are called from the central handlers.

## Key Files for Common Changes

- **Adding new GUI elements:** Update `constants.lua` with new element names, then the relevant `*_gui.lua` file
- **Changing distribution logic:** Modify `processor.lua`
- **Changing network/request logic:** Modify `network.lua` or `state.lua`
- **Entity/item properties:** Edit `data.lua`
- **Event handling:** Add handlers in `events.lua`, register in `M.register()`
- **Copy-paste behavior:** Modify `on_entity_settings_pasted` in `events.lua`
- **Player logistics behavior:** Modify `player_logistics.lua`
- **Provider chest behavior:** Modify `provider_gui.lua` (GUI) and `processor.lua` (processing)

## Factorio 2.0 Notes

- Uses `storage` instead of `global` for persistent data
- Uses `force.get_linked_inventory(prototype_name, link_id)` for efficient network inventory access
- `inventory.get_contents()` returns `{ { name = "item", count = N }, ... }` format
- Relative GUIs use `anchor` with `defines.relative_gui_type.container_gui` and entity name filter
