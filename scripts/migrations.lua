local migrate = require("__flib__.migration")

---@param MigrationsTable
local migration_data = {
}


function on_configuration_changed(event)
    migrate.on_config_changed(event, migration_data)
end