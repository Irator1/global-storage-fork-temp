--- Quality support helpers for Global Storage
--- Provides composite key functions to distinguish items by quality level.
--- Normal quality items use plain names (backward compatible with existing saves).
--- Quality variants use "item_name:quality" composite keys.
local M = {}

--- Separator used in composite keys (e.g., "iron-plate:rare")
local SEP = ":"

--- Make a composite item key from name and quality
--- Normal quality returns plain name for backward compatibility
---@param name string Item prototype name
---@param quality string|nil Quality name ("normal", "uncommon", "rare", "epic", "legendary")
---@return string key Composite key
function M.make_key(name, quality)
    if not quality or quality == "normal" or quality == "" then
        return name
    end
    return name .. SEP .. quality
end

--- Parse a composite key into item name and quality
---@param key string Composite key (e.g., "iron-plate" or "iron-plate:rare")
---@return string name Item prototype name
---@return string quality Quality name
function M.parse_key(key)
    local sep_pos = key:find(SEP, 1, true)
    if sep_pos then
        return key:sub(1, sep_pos - 1), key:sub(sep_pos + 1)
    end
    return key, "normal"
end

--- Get just the item name from a composite key
---@param key string Composite key
---@return string name Item prototype name
function M.get_name(key)
    local sep_pos = key:find(SEP, 1, true)
    if sep_pos then
        return key:sub(1, sep_pos - 1)
    end
    return key
end

--- Get just the quality from a composite key
---@param key string Composite key
---@return string quality Quality name
function M.get_quality(key)
    local sep_pos = key:find(SEP, 1, true)
    if sep_pos then
        return key:sub(sep_pos + 1)
    end
    return "normal"
end

--- Check if a key represents a non-normal quality item
---@param key string Composite key
---@return boolean has_quality True if quality is not "normal"
function M.has_quality(key)
    return key:find(SEP, 1, true) ~= nil
end

--- Make an item stack table suitable for LuaInventory.insert()/remove()
---@param key string Composite key
---@param count number Item count
---@return table stack {name=string, quality=string|nil, count=number}
function M.make_stack(key, count)
    local name, quality = M.parse_key(key)
    if quality == "normal" then
        return { name = name, count = count }
    end
    return { name = name, quality = quality, count = count }
end

--- Make an item filter table suitable for LuaInventory.get_item_count()
---@param key string Composite key
---@return table|string filter Item filter (table with quality, or plain string for normal)
function M.make_filter(key)
    local name, quality = M.parse_key(key)
    if quality == "normal" then
        return name
    end
    return { name = name, quality = quality }
end

--- Build a composite key from a get_contents() entry
--- get_contents() returns {name=string, quality=string, count=number}
---@param item table Entry from get_contents() with .name, .quality, .count
---@return string key Composite key
function M.key_from_contents(item)
    return M.make_key(item.name, item.quality)
end

--- Get a tooltip string for an item key including quality info
---@param key string Composite key
---@return string tooltip Human-readable item + quality string
function M.tooltip(key)
    local name, quality = M.parse_key(key)
    if quality == "normal" then
        return name
    end
    return name .. " (" .. quality .. ")"
end

--- Convert an elem_value from a "item-with-quality" choose-elem-button to a composite key
--- The elem_value is a table {name=string, quality=string} or nil
---@param elem_value table|nil Value from choose-elem-button
---@return string|nil key Composite key or nil
function M.key_from_elem_value(elem_value)
    if not elem_value then return nil end
    if type(elem_value) == "string" then
        -- Fallback for plain item elem_type
        return elem_value
    end
    return M.make_key(elem_value.name, elem_value.quality)
end

--- Convert a composite key to a GUI-safe element name suffix
--- Replaces the colon separator with double-underscore to avoid potential GUI issues
---@param key string Composite key
---@return string safe_name GUI-safe name
function M.gui_name(key)
    return key:gsub(SEP, "__")
end

--- Convert a composite key to an elem_value table for "item-with-quality" choose-elem-button
---@param key string Composite key
---@return table elem_value {name=string, quality=string}
function M.key_to_elem_value(key)
    local name, quality = M.parse_key(key)
    return { name = name, quality = quality }
end

return M
