require "spec.helpers" -- for one_of


db = require "lapis.db.mysql"
schema = require "lapis.db.mysql.schema"

unpack = unpack or table.unpack

import sorted_pairs, with_query_fn from require "spec.helpers"

-- TODO: we can't test escape_literal with strings here because we need a
-- connection for escape function

value_table = { hello: db.FALSE, age: 34 }

TESTS = {
  -- lapis.db.mysql
  {
    -> db.format_date 0
    "1970-01-01 00:00:00"
  }
  {
    -> db.escape_identifier "dad"
    '`dad`'
  }
  {
    -> db.escape_identifier "select"
    '`select`'
  }

  {
    -> db.escape_identifier 'love`fish'
    '`love``fish`'
  }
  {
    -> db.escape_identifier db.raw "hello(world)"
    "hello(world)"
  }
  {
    -> db.escape_literal 3434
    "3434"
  }
  {
    -> db.interpolate_query "select * from cool where hello = ?", 123
    "select * from cool where hello = 123"
  }
  {
    -> db.encode_values(value_table)
    [[(`hello`, `age`) VALUES (FALSE, 34)]]
    [[(`age`, `hello`) VALUES (34, FALSE)]]
  }

  {
    -> db.encode_assigns(value_table)
    [[`hello` = FALSE, `age` = 34]]
    [[`age` = 34, `hello` = FALSE]]
  }

  {
    -> db.encode_assigns thing: db.NULL
    [[`thing` = NULL]]
  }

  {
    -> db.encode_clause thing: db.NULL
    [[`thing` IS NULL]]
  }

  {
    -> db.interpolate_query "update x set x = ?", db.raw"y + 1"
    "update x set x = y + 1"
  }

  {
    -> db.select "* from things where id = ?", db.TRUE
    [[SELECT * from things where id = TRUE]]
  }

  {
    -> db.insert "cats", age: 123, name: db.NULL
    [[INSERT INTO `cats` (`name`, `age`) VALUES (NULL, 123)]]
    [[INSERT INTO `cats` (`age`, `name`) VALUES (123, NULL)]]
  }

  {
    -> db.update "cats", { age: db.raw"age - 10" }, "name = ?", db.FALSE
    [[UPDATE `cats` SET `age` = age - 10 WHERE name = FALSE]]
  }

  {
    -> db.update "cats", { color: db.NULL }, { weight: 1200, length: 392 }
    [[UPDATE `cats` SET `color` = NULL WHERE `weight` = 1200 AND `length` = 392]]
    [[UPDATE `cats` SET `color` = NULL WHERE `length` = 392 AND `weight` = 1200]]
  }

  {
    -> db.delete "cats"
    [[DELETE FROM `cats`]]
  }

  {
    -> db.delete "cats", "name = ?", 777
    [[DELETE FROM `cats` WHERE name = 777]]
  }

  {
    -> db.delete "cats", name: 778
    [[DELETE FROM `cats` WHERE `name` = 778]]
  }

  {
    -> db.delete "cats", name: db.FALSE, dad: db.TRUE
    [[DELETE FROM `cats` WHERE `name` = FALSE AND `dad` = TRUE]]
    [[DELETE FROM `cats` WHERE `dad` = TRUE AND `name` = FALSE]]
  }

  {
    -> db.truncate "dogs"
    [[TRUNCATE `dogs`]]
  }


  -- lapis.db.mysql.schema
  {
    -> tostring schema.types.varchar
    "VARCHAR(255) NOT NULL"
  }

  {
    -> tostring schema.types.varchar 1024
    "VARCHAR(1024) NOT NULL"
  }

  {
    -> tostring schema.types.varchar primary_key: true, auto_increment: true
    "VARCHAR(255) NOT NULL AUTO_INCREMENT PRIMARY KEY"
  }

  {
    -> tostring schema.types.varchar null: true, default: 2000
    "VARCHAR(255) DEFAULT 2000"
  }


  {
    -> tostring schema.types.varchar 777, primary_key: true, auto_increment: true, default: 22
    "VARCHAR(777) NOT NULL DEFAULT 22 AUTO_INCREMENT PRIMARY KEY"
  }


  {
    -> tostring schema.types.varchar null: true, default: 2000, length: 88
    "VARCHAR(88) DEFAULT 2000"
  }

  {
    -> tostring schema.types.boolean
    "TINYINT(1) NOT NULL"
  }

  {
    -> tostring schema.types.id
    "INT NOT NULL AUTO_INCREMENT PRIMARY KEY"
  }

  {
    -> schema.create_index "things", "age"
    "CREATE INDEX `things_age_idx` ON `things` (`age`);"
  }

  {
    -> schema.create_index "things", "color", "height"
    "CREATE INDEX `things_color_height_idx` ON `things` (`color`, `height`);"
  }

  {
    -> schema.create_index "things", "color", "height", unique: true
    "CREATE UNIQUE INDEX `things_color_height_idx` ON `things` (`color`, `height`);"
  }

  {
    -> schema.create_index "things", "color", "height", unique: true, using: "BTREE"
    "CREATE UNIQUE INDEX `things_color_height_idx` USING BTREE ON `things` (`color`, `height`);"
  }

  {
    -> schema.drop_index "things", "age"
    "DROP INDEX `things_age_idx` on `things`;"
  }

  {
    -> schema.drop_index "items", "cat", "paw"
    "DROP INDEX `items_cat_paw_idx` on `items`;"
  }

  {
    -> schema.add_column "things", "age", schema.types.varchar 22
    "ALTER TABLE `things` ADD COLUMN `age` VARCHAR(22) NOT NULL"
  }

  {
    -> schema.drop_column "items", "cat"
    "ALTER TABLE `items` DROP COLUMN `cat`"
  }

  {
    -> schema.rename_column "items", "cat", "paw", schema.types.integer
    "ALTER TABLE `items` CHANGE COLUMN `cat` `paw` INT NOT NULL"
  }

  {
    -> schema.rename_table "goods", "sweets"
    "RENAME TABLE `goods` TO `sweets`"
  }

  {
    name: "schema.create_table"

    ->
      schema.create_table "top_posts", {
        {"id", schema.types.id}
        {"user_id", schema.types.integer null: true}
        {"title", schema.types.text null: false}
        {"body", schema.types.text null: false}
        {"created_at", schema.types.datetime}
        {"updated_at", schema.types.datetime}
      }

    [[CREATE TABLE `top_posts` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT,
  `title` TEXT NOT NULL,
  `body` TEXT NOT NULL,
  `created_at` DATETIME NOT NULL,
  `updated_at` DATETIME NOT NULL
) CHARSET=UTF8;]]
  }


  {
    name: "schema.create_table not exists"
    ->
      schema.create_table "tags", {
        {"id", schema.types.id}
        {"tag", schema.types.varchar}
      }, if_not_exists: true

    [[CREATE TABLE IF NOT EXISTS `tags` (
  `id` INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  `tag` VARCHAR(255) NOT NULL
) CHARSET=UTF8;]]
  }

}

local old_query_fn
describe "lapis.db.mysql", ->
  sorted_pairs!
  local snapshot

  before_each ->
    snapshot = assert\snapshot!
    -- make the query function just return the query so we can test what is
    -- generated
    stub(db.BACKENDS, "luasql").returns (q) -> q

  after_each ->
    snapshot\revert!

  for group in *TESTS
    name = "should match"
    if group.name
      name ..= " #{group.name}"

    it name, ->
      output = group[1]!
      if #group > 2
        assert.one_of output, { unpack group, 2 }
      else
        assert.same group[2], output


  describe "unsupported options", ->
    it "errors on db.insert returning", ->
      assert.has_error (-> db.insert "cats", { age: 1 }, "id"),
        "db.insert: returning and insert options are not supported by the MySQL backend"

    it "errors on db.update returning", ->
      assert.has_error (-> db.update "cats", { age: 1 }, { id: 1 }, "age"),
        "db.update: returning is not supported by the MySQL backend"

    it "errors on db.delete returning", ->
      assert.has_error (-> db.delete "cats", { id: 1 }, "age"),
        "db.delete: returning is not supported by the MySQL backend"

    describe "model", ->
      import Model from require "lapis.db.mysql.model"

      class Cats extends Model

      it "errors on create returning", ->
        assert.has_error (-> Cats\create { age: 1 }, returning: "*"),
          "Cats.create: returning is not supported by the MySQL backend"

      it "errors on create on_conflict", ->
        assert.has_error (-> Cats\create { age: 1 }, on_conflict: "do_nothing"),
          "Cats.create: on_conflict is not supported by the MySQL backend"

      it "errors on update returning without changing the instance", ->
        cat = Cats\load { id: 1, age: 1 }
        assert.has_error (-> cat\update { age: 2 }, returning: "*"),
          "Cats.update: returning is not supported by the MySQL backend"

        assert.same 1, cat.age

  describe "model update where", ->
    import Model from require "lapis.db.mysql.model"

    class Cats extends Model

    it "adds where table to the update condition", ->
      cat = Cats\load { id: 1, age: 1 }
      _, query = cat\update { age: 2 }, where: { age: 1 }
      assert.same "UPDATE `cats` SET `age` = 2 WHERE `id` = 1 AND (`age` = 1)", query

    it "adds where clause to the update condition", ->
      cat = Cats\load { id: 1, age: 1 }
      _, query = cat\update { age: 2 }, where: db.clause { {"age < ?", 10} }
      assert.same "UPDATE `cats` SET `age` = 2 WHERE `id` = 1 AND (age < 10)", query

  describe "model update result", ->
    import Model from require "lapis.db.mysql.model"

    class Cats extends Model

    local queries, affected_rows, restore_query

    before_each ->
      queries = {}
      affected_rows = 1
      query = (q) ->
        table.insert queries, q
        { :affected_rows }

      restore_query = with_query_fn query, nil, db

    after_each ->
      restore_query!

    it "stores values into the instance after update", ->
      cat = Cats\load { id: 1, age: 1, name: "leo" }
      assert.true (cat\update { age: 2, name: db.NULL })
      assert.same { "UPDATE `cats` SET `age` = 2, `name` = NULL WHERE `id` = 1" }, queries
      assert.same { id: 1, age: 2 }, { k, v for k, v in pairs cat }

    it "doesn't change the instance when where matches no rows", ->
      affected_rows = 0
      cat = Cats\load { id: 1, age: 1 }
      assert.false (cat\update { age: 3 }, where: { age: 2 })
      assert.same 1, cat.age

    it "doesn't change the instance when a constraint fails", ->
      class ConstrainedCats extends Model
        @table_name: => "cats"
        @constraints: {
          age: (value) => "age too high" if value > 10
        }

      cat = ConstrainedCats\load { id: 1, age: 1 }
      assert.same { nil, "age too high" }, { cat\update { age: 20 } }
      assert.same 1, cat.age
      assert.same {}, queries

    it "stores updated_at into the instance", ->
      -- raw since escaping a string literal needs a connection
      now = db.raw "NOW()"
      stub(db, "format_date").returns now

      class TimestampCats extends Model
        @table_name: => "cats"
        @timestamp: true

      cat = TimestampCats\load { id: 1, age: 1 }
      assert.true (cat\update { age: 2 })
      assert.same { "UPDATE `cats` SET `age` = 2, `updated_at` = NOW() WHERE `id` = 1" }, queries
      assert.equal now, cat.updated_at
