require "spec.helpers" -- for one_of


db = require "lapis.db.mysql"
schema = require "lapis.db.mysql.schema"

unpack = unpack or table.unpack

import sorted_pairs from require "spec.helpers"

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

