data:extend({
    -- Chest inventory size (startup - requires restart)
    {
        type = "int-setting",
        name = "global-storage-chest-slots",
        setting_type = "startup",
        default_value = 48,
        minimum_value = 1,
        maximum_value = 256,
        order = "a[chest]-a[slots]"
    },
})
