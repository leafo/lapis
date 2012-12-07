
schema = require "lapis.db"
db = require "lapis.db"

table_name = "lapis_migrations"

create_migration_table ->
  import create_table, types from migrations

  create_table table_name, {
    {"file_name", types.varchar}
  }

apply_migrations = (dir) ->
  -- scan directory for migration files
  -- sort them
  -- apply them in order the missing ones

class Migration


{ :Migration, :create_migration_table }


