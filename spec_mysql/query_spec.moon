
db = require "lapis.db.mysql"
schema = require "lapis.db.mysql.schema"

import setup_db, teardown_db from require "spec_mysql.helpers"
import drop_tables from require "lapis.spec.db"
import create_table, drop_table, types from schema


describe "model", ->
  setup ->
    setup_db!

  teardown ->
    teardown_db!

  it "should run raw_query", ->
    assert.truthy db.raw_query [[
      select * from information_schema.tables
      where table_schema = "lapis_test"
    ]]

  it "should run query", ->
    assert.truthy db.query [[
      select * from information_schema.tables
      where table_schema = ?
    ]], "lapis_test"

  it "should create a table", ->
    drop_table "hello_worlds"
    create_table "hello_worlds", {
      {"id", types.id}
      {"name", types.varchar}
    }

    assert.same 1, #db.raw_query [[
      select * from information_schema.tables
      where table_schema = "lapis_test"
    ]]

    db.insert "hello_worlds", {
      name: "well well well"
    }

    res = db.insert "hello_worlds", {
      name: "another one"
    }

    assert.same {
      affected_rows: 1
      last_auto_id: 2
    }, res

  describe "with table", ->
    before_each ->
      drop_table "hello_worlds"
      create_table "hello_worlds", {
        {"id", types.id}
        {"name", types.varchar}
      }

    it "should create index and remove index", ->
      schema.create_index "hello_worlds", "id", "name", unique: true
      schema.drop_index "hello_worlds", "id", "name", unique: true


    it "should add column", ->
      schema.add_column "hello_worlds", "counter", schema.types.integer 123


