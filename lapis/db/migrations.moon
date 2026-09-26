
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

-- marks a migration to be run outside of a transaction, for statements that
-- can't run in one, eg. Postgres's CREATE INDEX CONCURRENTLY
NO_TRANSACTION_MT = {
  __call: (...) => @fn ...
}

no_transaction = (fn) ->
  assert type(fn) == "function", "no_transaction: expected function"
  setmetatable { :fn }, NO_TRANSACTION_MT

is_no_transaction = (m) ->
  getmetatable(m) == NO_TRANSACTION_MT

run_migrations = (migrations, prefix, options={}) ->
  assert type(migrations) == "table", "expecting a table of migrations for run_migrations"

  {:dry_run, :transaction} = options

  if dry_run
    transaction or= "global"

  if transaction == "global"
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
      if is_no_transaction fn
        if dry_run
          logger.notice "Stopping dry run at `#{name}`, it must run outside of a transaction"
          break

        logger.migration name
        logger.notice "Running `#{name}` outside of a transaction"

        if transaction == "global"
          commit_transaction!

        fn name
        LapisMigrations\create name

        if transaction == "global"
          start_transaction!

        count += 1
        continue

      logger.migration name

      if transaction == "individual"
        start_transaction!

      fn name
      LapisMigrations\create name

      if transaction == "individual"
        if dry_run
          rollback_transaction!
        else
          commit_transaction!

      count += 1

  logger.migration_summary count

  if transaction == "global"
    if dry_run
      rollback_transaction!
    else
      commit_transaction!

  return

{ :create_migrations_table, :run_migrations, :no_transaction, :LapisMigrations }

