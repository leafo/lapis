
logger = require "lapis.logging"

-- Note: Keep in mind this build a model for the default database configuration
import Model from require "lapis.db.model"

class LapisMigrations extends Model
  @primary_key: "name"

  @exists: (name) =>
    @find tostring name

  @create: (name) =>
    super name: tostring name

create_migrations_table = (table_name=LapisMigrations\table_name!) ->
  schema = require "lapis.db.schema"
  import create_table, types, entity_exists from schema
  create_table table_name, {
    { "name", types.varchar or types.text }
    "PRIMARY KEY(name)"
  }

-- TODO: we need to guarantee we are getting isolated connection here in case
-- transactions are run in a polled connection context
start_transaction = ->
  db = require "lapis.db"
  switch db.__type
    when "mysql"
      db.query "START TRANSACTION"
    else
      db.query "BEGIN"

commit_transaction = ->
  db = require "lapis.db"
  db.query "COMMIT"

rollback_transaction = ->
  db = require "lapis.db"
  db.query "ROLLBACK"

run_migrations = (migrations, prefix, options={}) ->
  assert type(migrations) == "table", "expecting a table of migrations for run_migrations"

  if options.transaction == "global"
    start_transaction!

  import entity_exists from require "lapis.db.schema"
  unless entity_exists LapisMigrations\table_name!
    logger.notice "Table `#{LapisMigrations\table_name!}` does not exist, creating"
    create_migrations_table!

  tuples = [{k,v} for k,v in pairs migrations]
  table.sort tuples, (a, b) -> a[1] < b[1]

  exists = { m.name, true for m in *LapisMigrations\select! }

  count = 0
  for _, {name, fn} in ipairs tuples
    if prefix
      assert type(prefix) == "string", "got a prefix for `run_migrations` but it was not a string"
      name = "#{prefix}_#{name}"

    unless exists[tostring name]
      logger.migration name

      if options.transaction == "individual"
        start_transaction!

      fn name
      LapisMigrations\create name

      if options.transaction == "individual"
        commit_transaction!

      count += 1

  logger.migration_summary count

  if options.transaction == "global"
    commit_transaction!

  return

{ :create_migrations_table, :run_migrations, :LapisMigrations }

