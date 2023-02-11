import setup_db, teardown_db from require "spec_mysql.helpers"

import drop_tables from require "lapis.spec.db"

describe "lapis.db.migrations", ->
  setup ->
    setup_db!

  teardown ->
    teardown_db!

  before_each ->
    import LapisMigrations from require "lapis.db.migrations"
    drop_tables LapisMigrations\table_name!

  it "creates migrations table", ->
    migrations = require "lapis.db.migrations"
    migrations.create_migrations_table!

  it "runs blank migrations", ->
    migrations = require "lapis.db.migrations"
    migrations.run_migrations {}

  it "runs some migrations", ->
    migrations = require "lapis.db.migrations"

    count = 0

    m = { => count += 1 }

    migrations.run_migrations m
    migrations.run_migrations m

    assert.same 1, count, "Migration should only run once"

  it "runs migrations in transaction", ->
    migrations = require "lapis.db.migrations"

    count = 0
    m = { => count += 1 }
 
    migrations.run_migrations m, nil, transaction: "individual"
    migrations.run_migrations m, nil, transaction: "global"

    assert.same 1, count, "Migration should only run once"



