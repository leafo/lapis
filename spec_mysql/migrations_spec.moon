
import drop_tables from require "lapis.spec.db"

import configure_mysql, bind_query_log from require "spec_mysql.helpers"

describe "lapis.db.migrations", ->
  configure_mysql!

  local query_log
  bind_query_log -> query_log

  before_each ->
    import LapisMigrations from require "lapis.db.migrations"
    drop_tables LapisMigrations\table_name!
    query_log = {}

  before_each ->
    logger = require "lapis.logging"
    stub(logger, "migration_summary").invokes (query) ->
    stub(logger, "migration").invokes (query) ->
    stub(logger, "notice").invokes (query) ->

  it "creates migrations table", ->
    migrations = require "lapis.db.migrations"
    migrations.create_migrations_table!

    assert.same {
      [[CREATE TABLE `lapis_migrations` (
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY(name)
) CHARSET=UTF8;]]
    }, query_log

  it "runs blank migrations", ->
    migrations = require "lapis.db.migrations"
    migrations.run_migrations {}

    assert.same {
      [[SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = 'lapis_test' AND table_name = 'lapis_migrations' LIMIT 1]]
      [[CREATE TABLE `lapis_migrations` (
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY(name)
) CHARSET=UTF8;]]
      [[SELECT * FROM `lapis_migrations` ]]
    }, query_log

  it "runs some migrations", ->
    migrations = require "lapis.db.migrations"

    count = 0

    m = { => count += 1 }

    migrations.run_migrations m
    migrations.run_migrations m

    assert.same 1, count, "Migration should only run once"

    assert.same {
      [[SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = 'lapis_test' AND table_name = 'lapis_migrations' LIMIT 1]]
      [[CREATE TABLE `lapis_migrations` (
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY(name)
) CHARSET=UTF8;]]
      [[SELECT * FROM `lapis_migrations` ]]
      [[INSERT INTO `lapis_migrations` (`name`) VALUES ('1')]]
      [[SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = 'lapis_test' AND table_name = 'lapis_migrations' LIMIT 1]]
      [[SELECT * FROM `lapis_migrations` ]]
    }, query_log

  it "runs migrations in transaction", ->
    migrations = require "lapis.db.migrations"

    count = 0
    m = { => count += 1 }
 
    migrations.run_migrations m, nil, transaction: "individual"
    migrations.run_migrations m, nil, transaction: "global"

    assert.same 1, count, "Migration should only run once"

    assert.same {
      [[SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = 'lapis_test' AND table_name = 'lapis_migrations' LIMIT 1]]
      [[CREATE TABLE `lapis_migrations` (
  `name` VARCHAR(255) NOT NULL,
  PRIMARY KEY(name)
) CHARSET=UTF8;]]
      [[SELECT * FROM `lapis_migrations` ]]
      [[START TRANSACTION]]
      [[INSERT INTO `lapis_migrations` (`name`) VALUES ('1')]]
      [[COMMIT]]
      [[START TRANSACTION]]
      [[SELECT COUNT(*) AS c FROM information_schema.tables WHERE table_schema = 'lapis_test' AND table_name = 'lapis_migrations' LIMIT 1]]
      [[SELECT * FROM `lapis_migrations` ]]
      [[COMMIT]]
    }, query_log

