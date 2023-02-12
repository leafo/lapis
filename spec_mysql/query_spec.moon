
db = require "lapis.db.mysql"
schema = require "lapis.db.mysql.schema"

import configure_mysql, bind_query_log from require "spec_mysql.helpers"
import drop_tables from require "lapis.spec.db"
import create_table, drop_table, types from schema

describe "model", ->
  configure_mysql!

  local query_log
  bind_query_log -> query_log

  before_each ->
    query_log = {}

  it "runs query", ->
    assert.truthy db.query [[
      select * from information_schema.tables
      where table_schema = "lapis_test"
    ]]

  it "runs query with interpolation", ->
    assert.truthy db.query [[
      select * from information_schema.tables
      where table_schema = ?
    ]], "lapis_test"

  it "creates a table", ->
    drop_table "hello_worlds"
    create_table "hello_worlds", {
      {"id", types.id}
      {"name", types.varchar}
    }

    assert.same 1, #db.query [[
      select * from information_schema.tables
      where table_schema = "lapis_test" and table_name = "hello_worlds"
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

    assert.same {
      [[DROP TABLE IF EXISTS `hello_worlds`;]]
      [[CREATE TABLE `hello_worlds` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `name` VARCHAR(255) NOT NULL
) CHARSET=UTF8;]]
      [[      select * from information_schema.tables
      where table_schema = "lapis_test" and table_name = "hello_worlds"
    ]]
      [[INSERT INTO `hello_worlds` (`name`) VALUES ('well well well')]]
      [[INSERT INTO `hello_worlds` (`name`) VALUES ('another one')]]
    }, query_log

  describe "with table", ->
    before_each ->
      drop_table "hello_worlds"
      create_table "hello_worlds", {
        {"id", types.id}
        {"name", types.varchar}
      }

      query_log = {}

    it "creates index and removes index", ->
      schema.create_index "hello_worlds", "id", "name", unique: true
      schema.drop_index "hello_worlds", "id", "name", unique: true

      assert.same {
        [[CREATE UNIQUE INDEX `hello_worlds_id_name_idx` ON `hello_worlds` (`id`, `name`);]]
        [[DROP INDEX `hello_worlds_id_name_idx` on `hello_worlds`;]]
      }, query_log

    it "adds column", ->
      schema.add_column "hello_worlds", "counter", schema.types.integer 123

      assert.same {
        [[ALTER TABLE `hello_worlds` ADD COLUMN `counter` INT(123) NOT NULL]]
      }, query_log


