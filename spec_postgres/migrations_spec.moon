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
      [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
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
      [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
      [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
      [[SELECT * FROM "lapis_migrations" ]]
      [[BEGIN]]
      [[INSERT INTO "lapis_migrations" ("name") VALUES ('1') RETURNING "name"]]
      [[COMMIT]]
      [[BEGIN]]
      [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
      [[SELECT * FROM "lapis_migrations" ]]
      [[COMMIT]]
    }, query_log


  describe "no_transaction", ->
    local count, m

    before_each ->
      import no_transaction from require "lapis.db.migrations"
      count = 0
      m = {
        -> count += 1
        no_transaction -> count += 1
        -> count += 1
      }

    it "passes migration name to the wrapped function", ->
      import no_transaction from require "lapis.db.migrations"
      migrations = require "lapis.db.migrations"

      local args
      migrations.run_migrations {
        [1790452452]: no_transaction (...) -> args = {...}
      }

      assert.same {1790452452}, args

    it "commits the global transaction around it", ->
      migrations = require "lapis.db.migrations"
      migrations.run_migrations m, nil, transaction: "global"

      assert.same 3, count, "Migrations run"

      assert.same {
        [[BEGIN]]
        [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
        [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
        [[SELECT * FROM "lapis_migrations" ]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('1') RETURNING "name"]]
        [[COMMIT]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('2') RETURNING "name"]]
        [[BEGIN]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('3') RETURNING "name"]]
        [[COMMIT]]
      }, query_log

    it "skips the transaction in individual mode", ->
      migrations = require "lapis.db.migrations"
      migrations.run_migrations m, nil, transaction: "individual"

      assert.same 3, count, "Migrations run"

      assert.same {
        [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
        [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
        [[SELECT * FROM "lapis_migrations" ]]
        [[BEGIN]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('1') RETURNING "name"]]
        [[COMMIT]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('2') RETURNING "name"]]
        [[BEGIN]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('3') RETURNING "name"]]
        [[COMMIT]]
      }, query_log

    it "stops a dry run before it", ->
      migrations = require "lapis.db.migrations"
      migrations.run_migrations m, nil, dry_run: true

      assert.same 1, count, "Migrations run"

      assert.same {
        [[BEGIN]]
        [[SELECT COUNT(*) AS c FROM pg_class WHERE relname = 'lapis_migrations']]
        [[CREATE TABLE "lapis_migrations" (
  "name" character varying(255) NOT NULL,
  PRIMARY KEY(name)
)]]
        [[SELECT * FROM "lapis_migrations" ]]
        [[INSERT INTO "lapis_migrations" ("name") VALUES ('1') RETURNING "name"]]
        [[ROLLBACK]]
      }, query_log
