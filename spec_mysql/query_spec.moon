
import setup_db, teardown_db from require "spec_mysql.helpers"
import drop_tables from require "lapis.spec.db"
import raw_query from require "lapis.db.mysql"

import create_table from require "lapis.db.mysql.schema"

describe "model", ->
  setup ->
    setup_db!

  teardown ->
    teardown_db!

  it "should run query", ->
    assert.truthy raw_query [[
      select * from information_schema.tables
      where table_schema = "lapis_test"
    ]]

  it "should create a table", ->
    create_table "hello_worlds", {
      {"name", "varchar(255) NOT NULL"}
    }

    assert.same 1, #raw_query [[
      select * from information_schema.tables
      where table_schema = "lapis_test"
    ]]

