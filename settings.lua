data:extend({
    {
        type = "bool-setting",
        name = "SCT_enable_control",
        order = "aa",
        setting_type = "runtime-global",
        default_value = "true"
    },
    {
        type = "bool-setting",
        name = "SCT_poll_trains_only",
        order = "ac",
        setting_type = "runtime-global",
        default_value = "false"
    },
    {
        type = "bool-setting",
        name = "SCT_update_cargo_during_polls",
        order = "ad",
        setting_type = "runtime-global",
        default_value = "true"
    },
    {
        type = "int-setting",
        name = "SCT_delivery_timeout_time",
        order = "ba",
        setting_type = "runtime-global",
        default_value = 600,
        minimum_value = 120,
        maximum_value = 3600
    },
    {
        type = "int-setting",
        name = "SCT_delivery_removal_time",
        order = "bb",
        setting_type = "runtime-global",
        hidden = true,
        default_value = 3601
    },
    {
        type = "int-setting",
        name = "SCT_ticks_between_polls",
        order = "ca",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 120
    },
    {
        type = "int-setting",
        name = "SCT_Trains_per_poll",
        order = "cb",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 0,
        maximum_value = 15
    },
    {
        type = "int-setting",
        name = "SCT_Train_Stops_per_poll",
        order = "cc",
        setting_type = "runtime-global",
        default_value = 1,
        minimum_value = 1,
        maximum_value = 15
    }
})