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
