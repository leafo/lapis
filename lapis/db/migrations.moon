
db = require "lapis.db"
logger = require "lapis.logging"
import Model from require "lapis.db.model"

class LapisMigrations extends Model
  primary_key: "name"

  @exists: (name) =>
    @find tostring name

  create: (name) =>
    Model.create @, { name: tostring name }

create_migrations_table = (table_name="lapis_migrations") ->
  schema = require "lapis.db.schema"
  import create_table, types from schema

  create_table table_name, {
    { "name", types.varchar }
    "PRIMARY KEY(name)"
  }

run_migrations = (migrations) ->
  tuples = [{k,v} for k,v in pairs migrations]
  table.sort tuples, (a, b) -> a[1] < b[1]

  for _, {name, fn} in ipairs tuples
    unless LapisMigrations\exists name
      logger.migration name
      fn name
      LapisMigrations\create name

{ :create_migrations_table, :run_migrations }

