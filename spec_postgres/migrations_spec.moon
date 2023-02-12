import configure_postgres, bind_query_log from require "spec_postgres.helpers"

import drop_tables from require "lapis.spec.db"

describe "lapis.db.migrations", ->
  configure_postgres!

  local query_log

  bind_query_log -> query_log

  before_each ->
    import LapisMigrations from require "lapis.db.migrations"
    drop_tables LapisMigrations\table_name!
    query_log = {}

  before_each ->
    logger = require "lapis.logging"
    -- silence logging
    stub(logger, "migration_summary").invokes (query) ->
    stub(logger, "migration").invokes (query) ->
    stub(logger, "notice").invokes (query) ->

  it "creates migrations table", ->
    migrations = require "lapis.db.migrations"
    migrations.create_migrations_table!

    assert.same {
      [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
    }, query_log

  it "runs blank migrations", ->
    migrations = require "lapis.db.migrations"
    migrations.run_migrations {}

    assert.same {
      [[SELECT COUNT(*) as c from pg_class where relname = 'lapis_migrations']]
      [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
      [[SELECT * FROM "lapis_migrations" ]]
    }, query_log

  it "runs blank migrations in transaction", ->
    migrations = require "lapis.db.migrations"
    count = 0
    m = { -> count += 1 }

    migrations.run_migrations m, nil, transaction: "individual"
    migrations.run_migrations m, nil, transaction: "global"

    assert.same 1, count, "Migrations run"

    assert.same {
      [[SELECT COUNT(*) as c from pg_class where relname = 'lapis_migrations']]
      [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
      [[SELECT * FROM "lapis_migrations" ]]
      [[BEGIN]]
      [[INSERT INTO "lapis_migrations" ("name") VALUES ('1') RETURNING "name"]]
      [[COMMIT]]
      [[BEGIN]]
      [[SELECT COUNT(*) as c from pg_class where relname = 'lapis_migrations']]
      [[SELECT * FROM "lapis_migrations" ]]
      [[COMMIT]]
    }, query_log

