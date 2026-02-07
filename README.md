Original mod description further down.


!!!!!!!!!!!!!!  With some help from AI, these are the changes:


With some help from AI, these are the changes:

# Feature: Multi-buffer networks, copy-paste configuration, configurable chest size, and UI improvements

**v0.1.2 → v0.3.2**

This PR adds several features to improve throughput and usability for large bases, along with UI sizing improvements and minor code quality fixes. No changes to the core processing model — the processor still uses the same fixed 20-networks-per-cycle round-robin and processes all provider chests every cycle.

---

## Changes

### 1. Sequential link_id allocation (replaces hash-based)

**Problem:** The original `get_link_id()` uses a hash function on the network name. Hash collisions are possible — two different network names could produce the same `link_id`, causing unrelated networks to silently share inventory.

**Solution:** Replace with a monotonically incrementing counter (`storage.next_link_id`). Each new network gets the next integer, starting at 1. Collisions are impossible.

**Files changed:** `state.lua`
- `get_link_id(name)` (hash function) → `allocate_link_id()` (sequential counter)
- `init()` rebuilds the reverse mapping (`link_id_to_network`) from existing networks on load and ensures the counter stays ahead of all allocated IDs

### 2. Multi-buffer networks (inventory sharding)

**Problem:** Each network has a single linked inventory shared by all its chests. For megabases with hundreds of chests on one network, this single inventory becomes a throughput bottleneck — all chests contend for the same slots.

**Solution:** Networks can now have multiple `link_id`s (buffers). Chests are distributed across buffers in round-robin when placed. The processor iterates all buffers for each network. Users add/remove buffers via `[+]`/`[-]` buttons in the Networks tab.

**Performance impact:** For single-buffer networks (the default and vast majority), the only overhead vs. the original is one `ipairs()` call over a 1-element table — negligible compared to the engine-side `get_linked_inventory()` and `get_contents()` calls that dominate per-network cost. Multi-buffer networks scale linearly with buffer count (N buffers = N× engine calls), which is the expected trade-off for throughput.

**Files changed:**
- `state.lua` — New fields on networks: `link_ids` (array), `buffer_count`, `next_buffer_assign`. New functions: `set_network_buffer_count()`, `remove_network_buffer()`, `get_next_buffer_link_id()`
- `processor.lua` — Extracted `process_single_buffer()` from the inline processing code. `process_network()` iterates `network.link_ids`. Also caches `storage.inventory`/`storage.limits` as locals for minor Lua performance gain
- `network.lua` — `set_chest_network()` uses `get_next_buffer_link_id()` for round-robin buffer assignment. Now returns `boolean` instead of `nil`
- `network_gui.lua` — Buffers column in Networks tab with `[+]`/`[-]` buttons. New `rebuild_networks_tab()` function
- `chest_gui.lua` — Shows which buffer a chest belongs to (e.g., `buf 2/3`) in the network name display
- `constants.lua` — New constants: `MAX_BUFFER_COUNT`, GUI element names for buffer controls
- `locale/en/locale.cfg` — New strings: `gn-buffers`, `gn-buffer-add-tooltip`, `gn-buffer-remove-tooltip`

### 3. Copy-paste from assemblers auto-configures network by ingredients

**Problem:** Setting up a chest for an assembler requires manually typing a network name and adding item requests one by one.

**Solution:** Copy-paste (Shift+click) from an assembling machine or furnace to a global chest now:
1. Creates a network named by sorted ingredients (e.g., `Req:copper-cable+iron-plate` for electronic circuits)
2. Sets item requests to one stack size each (min = max = stack_size) — only for brand new networks, not existing ones
3. Sets the inventory bar to limit slots to the number of ingredients + 1

**Files changed:**
- `events.lua` — New `build_ingredient_network_name()` function. `on_entity_settings_pasted()` uses ingredient-based names instead of recipe names
- `constants.lua` — New constant: `COPY_PASTE_NETWORK_PREFIX`

### 4. Configurable chest inventory size (startup setting)

**Problem:** Chest inventory size is hardcoded.

**Solution:** New startup setting `global-storage-chest-slots` (default 48, range 1–256) controls the number of inventory slots in each global chest.

**New file:** `settings.lua`
**Files changed:**
- `data.lua` — Reads `settings.startup["global-storage-chest-slots"].value` to set `inventory_size`
- `locale/en/locale.cfg` — New strings: `global-storage-chest-slots` name and description

### 5. Remove items from global inventory

**Problem:** Items that accidentally enter the global pool (e.g., upgrade-planner, blueprints, or other non-storable items) cannot be removed from the Global Inventory list. They stay visible with 0 stock forever.

**Solution:** A red "Remove" button in the item edit popup (the dialog opened by clicking an item in the Global Inventory tab). Clicking it removes the item from `storage.inventory`, `storage.limits`, and `storage.previous_limits`, clears any HUD pins for that item across all players, and destroys associated HUD elements immediately. The item will only reappear if the processor finds it physically present in a linked chest again.

**Files changed:**
- `network_gui.lua` — New click handler for `INVENTORY_EDIT_REMOVE` button. Red button added to the item edit popup beside the OK button
- `constants.lua` — New constant: `INVENTORY_EDIT_REMOVE`
- `locale/en/locale.cfg` — New strings: `gn-remove-item`, `gn-remove-item-tooltip`

### 6. UI sizing improvements

**Problem:** The chest-relative "Global Network" panel and the Shift+G "Global Network" menu are too small for comfortable use with many networks, requests, or inventory items.

**Solution:**

**Chest panel (relative GUI, right side of chest):**
- Outer frame minimum width: 380px (was unconstrained/content-driven)
- Network name textfield: 220px (was 150px)
- Network list scroll when editing: 325px height (was 120px) — shows many more networks
- Requests scroll area: 300px height (was 200px)
- Requests layout changed from horizontal flow to 7-column wrapping table — items wrap into rows instead of extending off-screen
- Empty request slots now include spacer labels matching filled-slot height for proper grid alignment
- Panel always destroys and recreates on join/config change so layout updates apply to existing saves

**Shift+G menu (Global Network window):**
- Frame minimum width: 550px (was 500px)
- Networks tab scroll: 600px height (was 400px)
- Inventory tab scroll: 600px height, 520px width (was 400px/480px)

**Files changed:**
- `chest_gui.lua` — Width, height, layout changes as described above. Panel recreation on every `create_relative_panel` call
- `network_gui.lua` — Frame width, scroll heights and widths increased

### 7. Minor code quality fixes

- Removed duplicate `local player_data` variable declarations in `events.lua` `on_gui_closed` (shadowed outer variable, caused redundant `get_player_data()` calls)
- Removed empty migration block in `control.lua` `on_configuration_changed`
- Cleaned up stale comments

---

## Files changed summary

| File | Change type |
|---|---|
| `settings.lua` | **New** — startup setting for chest inventory size |
| `processor.lua` | Modified — extracted `process_single_buffer()`, multi-buffer iteration, local caching |
| `state.lua` | Modified — sequential link_id allocation, buffer management functions, network fields |
| `events.lua` | Modified — ingredient-based copy-paste naming, removed duplicate variable |
| `network.lua` | Modified — round-robin buffer assignment in `set_chest_network()` |
| `network_gui.lua` | Modified — buffer controls, remove-item button, UI sizing |
| `chest_gui.lua` | Modified — buffer info display, UI sizing, request grid layout, panel recreation |
| `constants.lua` | Modified — new constants for buffers, copy-paste, remove button, GUI elements |
| `data.lua` | Modified — reads chest-slots setting |
| `control.lua` | Modified — removed empty migration block |
| `locale/en/locale.cfg` | Modified — new localization strings |
| `info.json` | Modified — version bump |

---

## Not changed

- Core processing model (20 networks/cycle round-robin, all providers every cycle)
- `data-final-fixes.lua`
- `provider_gui.lua`
- `player_logistics.lua`
- `thumbnail.png`


!!!!!!!!!!!!!!!!!!!!!!!!    Original mod description:



# Global Network

A global item storage and logistics system for Factorio 2.0+. Manage a centralized inventory pool with network-based requests, perfect for megabases.

---

## Core Concept

Global Network provides a **shared global inventory** that all your chests can access. Instead of managing individual chest contents, you define **networks** with item requests, and the mod automatically distributes items to where they're needed.

**Key insight:** Requests are defined at the **network level**, not per-chest. This means the mod processes dozens of networks instead of thousands of individual chests, making it highly performant for large bases.

---

## Chests

### Global Chest

A linked container that shares its inventory with all other Global Chests on the same network.

- **Network ID**: Text-based identifier (e.g., "iron-gear-wheel", "main-storage", "mall")
- **Shared Inventory**: All chests with the same network ID share the exact same inventory
- **Requests**: Define min/max quantities per item at the network level

**How it works:**
- Items **above max** are collected into the global pool
- Items **below min** are supplied from the global pool

### Global Provider Chest

A passive provider chest that pulls items FROM the global pool and makes them available to logistics bots.

- **Per-chest requests**: Each provider chest has its own item requests
- **Bot integration**: Works with your existing logistics network
- **Bridge**: Connects global storage to your robot logistics

---

## Global Inventory

The central item pool shared across all networks. Access it via **Shift+G**.

### Limits System

Every item has a storage limit that controls how much can be stored globally:

| Limit | Behavior |
|-------|----------|
| **0 (Blocked)** | Item cannot enter global storage |
| **Numeric** | Stores up to that amount |
| **Unlimited** | No limit on storage |

New items appear with a limit of 0 (blocked) until you configure them. This prevents unwanted items from flooding your storage.

---

## Network Management GUI (Shift+G)

Press **Shift+G** to open the management interface with three tabs:

### Networks Tab
- View all networks with their chest count and request count
- See status: **Active** (has chests) or **Ghost** (no chests, keeps configuration)
- Delete networks (chests are reassigned to default network)

### Global Inventory Tab
- Grid view of all items in global storage
- Click any item to edit its limit and pin settings
- Filter to show only blocked items (limit = 0)
- Add limits for new items before they arrive

### Player Tab
- Enable/disable player logistics integration
- Toggle auto-pin for low stock items

---

## Features

### Copy-Paste from Assemblers

Copy settings from an assembling machine or furnace and paste onto a Global Chest:

1. The chest joins a network named after the recipe (e.g., "iron-gear-wheel")
2. Recipe ingredients are automatically added as requests with stack-size quantities
3. Inventory slots are limited to inputs + output

This makes setting up production lines extremely fast.

### Player Logistics Integration

When enabled, the global network integrates with your personal logistics:

- **Supply**: Items you request in your personal logistics are supplied from global storage
- **Trash Collection**: Items in your trash slots are automatically collected into global storage (bypasses limits)

### HUD Pins

Pin important items to your screen for at-a-glance monitoring:

- **Manual pins**: Click any item in the inventory grid and check "Pin to HUD"
- **Auto-pin low stock**: Automatically shows items below 10% of their limit (up to 10 items)

Pinned items display current quantity and limit on the left side of your screen.

### Network-Based Architecture

Unlike mods that process every chest individually, Global Network processes **networks**:

- All chests with the same network ID share one linked inventory
- The mod only needs to check each network once, not each chest
- Scales to thousands of chests without performance impact
- Round-robin processing distributes load across ticks

---

## Quick Start

1. **Craft Global Chests** and place them
2. **Open a chest** and set a Network ID (e.g., "iron")
3. **Add requests** with min/max quantities
4. **Press Shift+G** to open the network GUI
5. **Set limits** for items you want to store globally
6. Items automatically flow between chests and global storage

### Example Setup

**Iron plate distribution:**
1. Place Global Chests at your smelter output and assembler inputs
2. Set all to network "iron"
3. Add request: Iron Plate, min=100, max=1000
4. Set global limit for iron-plate to 50000 (or unlimited)

Items above 1000 are collected to global storage. When any chest drops below 100, items are supplied from global storage.

---

## Hotkeys

| Key | Action |
|-----|--------|
| **Shift+G** | Toggle Network Management GUI |

---

## Tips

- **Use meaningful network names** like "iron-production", "copper-bus", "mall-circuits"
- **Set limits before items arrive** to prevent blocking
- **Use unlimited** for common materials you always want to accept
- **Keep limits at 0** for items you don't want in global storage
- **Copy-paste from assemblers** is the fastest way to set up production
- **Provider chests** are great for mall setups where bots deliver finished products

---

## Compatibility

- **Factorio Version**: 2.0+
- **Multiplayer**: Supported
- **Safe to add mid-game**: Yes

---

## Technical Notes

- Processing runs every 10 ticks with round-robin distribution
- Uses Factorio's native linked-container system for shared inventories
- Network ID is hashed to link_id for the linked container system
- Ghost networks (no chests) retain their configuration for later use
