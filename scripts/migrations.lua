local migrate = require("__flib__.migration")

---@param MigrationsTable
local migration_data = {
    ["1.1.0"] = function ()
        local SCT_Train_Stops = global.Train_Stops
        for id, train_stop in pairs (SCT_Train_Stops) do
            update_train_stop_signals(id, train_stop.Train_Stop)
        end
    end
}


function on_configuration_changed(event)
    migrate.on_config_changed(event, migration_data)
end