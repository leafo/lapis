require "spec.helpers" -- for one_of

db = require "lapis.db.postgres"
schema = require "lapis.db.postgres.schema"

value_table = { hello: "world", age: 34 }

tests = {
  -- lapis.db.postgres
  {
    -> db.escape_identifier "dad"
    '"dad"'
  }
  {
    -> db.escape_identifier "select"
    '"select"'
  }
  {
    -> db.escape_identifier 'love"fish'
    '"love""fish"'
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
    -> db.escape_literal "cat's soft fur"
    "'cat''s soft fur'"
  }
  {
    -> db.interpolate_query "select * from cool where hello = ?", "world"
    "select * from cool where hello = 'world'"
  }

  {
    -> db.encode_values(value_table)
    [[("hello", "age") VALUES ('world', 34)]]
    [[("age", "hello") VALUES (34, 'world')]]
  }

  {
    -> db.encode_assigns(value_table)
    [["hello" = 'world', "age" = 34]]
    [["age" = 34, "hello" = 'world']]
  }

  {
    -> db.encode_assigns thing: db.NULL
    [["thing" = NULL]]
  }

  {
    -> db.encode_clause thing: db.NULL
    [["thing" IS NULL]]
  }

  {
    -> db.interpolate_query "update x set x = ?", db.raw"y + 1"
    "update x set x = y + 1"
  }

  {
    -> db.select "* from things where id = ?", "cool days"
    [[SELECT * from things where id = 'cool days']]
  }

  {
    -> db.insert "cats", age: 123, name: "catter"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123)]]
    [[INSERT INTO "cats" ("age", "name") VALUES (123, 'catter')]]
  }

  {
    -> db.update "cats", { age: db.raw"age - 10" }, "name = ?", "catter"
    [[UPDATE "cats" SET "age" = age - 10 WHERE name = 'catter']]
  }

  {
    -> db.update "cats", { age: db.raw"age - 10" }, { name: db.NULL }
    [[UPDATE "cats" SET "age" = age - 10 WHERE "name" IS NULL]]
  }

  {
    -> db.update "cats", { age: db.NULL }, { name: db.NULL }
    [[UPDATE "cats" SET "age" = NULL WHERE "name" IS NULL]]
  }

  {
    -> db.update "cats", { color: "red" }, { weight: 1200, length: 392 }
    [[UPDATE "cats" SET "color" = 'red' WHERE "weight" = 1200 AND "length" = 392]]
    [[UPDATE "cats" SET "color" = 'red' WHERE "length" = 392 AND "weight" = 1200]]
  }

  {
    -> db.update "cats", { color: "red" }, { weight: 1200, length: 392 }, "weight", "color"
    [[UPDATE "cats" SET "color" = 'red' WHERE "weight" = 1200 AND "length" = 392 RETURNING "weight", "color"]]
    [[UPDATE "cats" SET "color" = 'red' WHERE "length" = 392 AND "weight" = 1200 RETURNING "weight", "color"]]
  }

  {
    -> db.delete "cats"
    [[DELETE FROM "cats"]]
  }

  {
    -> db.delete "cats", "name = ?", "rump"
    [[DELETE FROM "cats" WHERE name = 'rump']]
  }

  {
    -> db.delete "cats", name: "rump"
    [[DELETE FROM "cats" WHERE "name" = 'rump']]
  }

  {
    -> db.delete "cats", name: "rump", dad: "duck"
    [[DELETE FROM "cats" WHERE "name" = 'rump' AND "dad" = 'duck']]
    [[DELETE FROM "cats" WHERE "dad" = 'duck' AND "name" = 'rump']]
  }

  {
    -> db.insert "cats", { hungry: true }
    [[INSERT INTO "cats" ("hungry") VALUES (TRUE)]]
  }


  {
    -> db.insert "cats", { age: 123, name: "catter" }, "age"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123) RETURNING "age"]]
    [[INSERT INTO "cats" ("age", "name") VALUES (123, 'catter') RETURNING "age"]]
  }

  {
    -> db.insert "cats", { age: 123, name: "catter" }, "age", "name"
    [[INSERT INTO "cats" ("name", "age") VALUES ('catter', 123) RETURNING "age", "name"]]
    [[INSERT INTO "cats" ("age", "name") VALUES (123, 'catter') RETURNING "age", "name"]]
  }


  -- lapis.db.postgres.schema

  {
    -> schema.add_column "hello", "dads", schema.types.integer
    [[ALTER TABLE "hello" ADD COLUMN "dads" integer NOT NULL DEFAULT 0]]
  }

  {
    -> schema.rename_column "hello", "dads", "cats"
    [[ALTER TABLE "hello" RENAME COLUMN "dads" TO "cats"]]
  }

  {
    -> schema.drop_column "hello", "cats"
    [[ALTER TABLE "hello" DROP COLUMN "cats"]]
  }

  {
    -> schema.rename_table "hello", "world"
    [[ALTER TABLE "hello" RENAME TO "world"]]
  }

  {
    -> tostring schema.types.integer
    "integer NOT NULL DEFAULT 0"
  }

  {
    -> tostring schema.types.integer null: true
    "integer DEFAULT 0"
  }

  {
    -> tostring schema.types.integer null: true, default: 100, unique: true
    "integer DEFAULT 100 UNIQUE"
  }

  {
    -> tostring schema.types.serial
    "serial NOT NULL"
  }

  {
    -> tostring schema.types.time
    "timestamp NOT NULL"
  }

  {
    -> tostring schema.types.time timezone: true
    "timestamp with time zone NOT NULL"
  }


  {
    ->
      import foreign_key, boolean, varchar, text from schema.types
      schema.create_table "user_data", {
        {"user_id", foreign_key}
        {"email_verified", boolean}
        {"password_reset_token", varchar null: true}
        {"data", text}
        "PRIMARY KEY (user_id)"
      }

    [[CREATE TABLE IF NOT EXISTS "user_data" (
  "user_id" integer NOT NULL,
  "email_verified" boolean NOT NULL DEFAULT FALSE,
  "password_reset_token" character varying(255),
  "data" text NOT NULL,
  PRIMARY KEY (user_id)
);]]
  }

  {
    -> schema.drop_table "user_data"
    [[DROP TABLE IF EXISTS "user_data";]]
  }

  {
    -> schema.drop_index "user_data", "one", "two", "three"
    [[DROP INDEX IF EXISTS "user_data_one_two_three_idx"]]
  }


  {
    -> db.parse_clause ""
    {}
  }

  {
    -> db.parse_clause "where something = TRUE"
    {
      where: "something = TRUE"
    }
  }

  {
    -> db.parse_clause "where something = TRUE order by things asc"
    {
      where: "something = TRUE "
      order: "things asc"
    }
  }


  {
    -> db.parse_clause "where something = 'order by cool' having yeah order by \"limit\" asc"
    {
      having: "yeah "
      where: "something = 'order by cool' "
      order: '"limit" asc'
    }
  }

  {
    -> db.parse_clause "where not exists(select 1 from things limit 100)"
    {
      where: "not exists(select 1 from things limit 100)"
    }
  }

  {
    -> db.parse_clause "order by color asc"
    {
      order: "color asc"
    }
  }

  {
    -> db.parse_clause "ORDER BY color asc"
    {
      order: "color asc"
    }
  }

  {
    -> db.parse_clause "group BY height"
    {
      group: "height"
    }
  }

  {
    -> db.parse_clause "where x = limitx 100"
    {
      where: "x = limitx 100"
    }
  }

  {
    -> db.parse_clause "join dads on color = blue where hello limit 10"
    {
      limit: "10"
      where: "hello "
      join: {
        {"join", " dads on color = blue "}
      }
    }
  }

  {
    -> db.parse_clause "inner join dads on color = blue left outer join hello world where foo"
    {
      where: "foo"
      join: {
        {"inner join", " dads on color = blue "}
        {"left outer join", " hello world "}
      }
    }
  }


  {
    -> schema.gen_index_name "hello", "world"
    "hello_world_idx"
  }

  {
    -> schema.gen_index_name "yes", "please", db.raw "upper(dad)"
    "yes_please_upper_dad_idx"
  }

  {
    -> db.encode_case("x", { a: "b" })
    [[CASE x
WHEN 'a' THEN 'b'
END]]
  }

  {
    -> db.encode_case("x", { a: "b", foo: true })
    [[CASE x
WHEN 'a' THEN 'b'
WHEN 'foo' THEN TRUE
END]]
    [[CASE x
WHEN 'foo' THEN TRUE
WHEN 'a' THEN 'b'
END]]
  }


  {
    -> db.encode_case("x", { a: "b" }, false)
    [[CASE x
WHEN 'a' THEN 'b'
ELSE FALSE
END]]
  }
}


local old_query_fn
describe "lapis.db.postgres", ->
  setup ->
    old_query_fn = db.set_backend "raw", (q) -> q

  teardown ->
    db.set_backend "raw", old_query_fn

  for group in *tests
    it "should match", ->
      output = group[1]!
      if #group > 2
        assert.one_of output, { unpack group, 2 }
      else
        assert.same group[2], output

  it "should create index", ->
    old_select = db.select
    db.select = -> { { c: 0 } }
    input = schema.create_index "user_data", "one", "two"
    assert.same input, [[CREATE INDEX "user_data_one_two_idx" ON "user_data" ("one", "two");]]
    db.select = old_select

  it "should create index with expression", ->
    old_select = db.select
    db.select = -> { { c: 0 } }
    input = schema.create_index "user_data", db.raw("lower(name)"), "height"
    assert.same input, [[CREATE INDEX "user_data_lower_name_height_idx" ON "user_data" (lower(name), "height");]]
    db.select = old_select


  it "should create not create duplicate index", ->
    old_select = db.select
    db.select = -> { { c: 1 } }
    input = schema.create_index "user_data", "one", "two"
    assert.same input, nil
    db.select = old_select

