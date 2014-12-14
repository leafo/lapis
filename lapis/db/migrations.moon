
db = require "lapis.db"
logger = require "lapis.logging"
import Model from require "lapis.db.model"

class LapisMigrations extends Model
  @primary_key: "name"

  @exists: (name) =>
    @find tostring name

  @create: (name) =>
    Model.create @, { name: tostring name }

create_migrations_table = (table_name=LapisMigrations\table_name!) ->
  schema = require "lapis.db.schema"
  import create_table, types, entity_exists from schema
  create_table table_name, {
    { "name", types.varchar }
    "PRIMARY KEY(name)"
  }

run_migrations = (migrations) ->
  import entity_exists from require "lapis.db.schema"
  unless entity_exists LapisMigrations\table_name!
    logger.notice "Table `#{LapisMigrations\table_name!}` does not exist, creating"
    create_migrations_table!

  tuples = [{k,v} for k,v in pairs migrations]
  table.sort tuples, (a, b) -> a[1] < b[1]

  exists = { m.name, true for m in *LapisMigrations\select! }

  count = 0
  for _, {name, fn} in ipairs tuples
    unless exists[tostring name]
      logger.migration name
      fn name
      LapisMigrations\create name
      count += 1

  logger.migration_summary count

{ :create_migrations_table, :run_migrations, :LapisMigrations }

