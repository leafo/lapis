unpack = unpack or table.unpack

TESTS = {
  -- lapis.db.postgres
  {
    (db) -> db.escape_identifier "dad"
    '"dad"'
  }
  {
    (db) -> db.escape_identifier "select"
    '"select"'
  }
  {
    (db) -> db.escape_identifier 'love"fish'
    '"love""fish"'
  }
  {
    (db) -> db.escape_identifier db.raw "hello(world)"
    "hello(world)"
  }
  {
    (db) -> db.escape_literal 3434
    "3434"
  }
  {
    (db) -> db.escape_literal "cat's soft fur"
    "'cat''s soft fur'"
  }
  {
    (db) -> db.escape_literal db.raw "upper(username)"
    "upper(username)"
  }
  {
    (db) -> db.escape_literal db.list {1,2,3,4,5}
    "(1, 2, 3, 4, 5)"
  }
  {
    (db) -> db.escape_literal db.list {"hello", "world", db.TRUE}
    "('hello', 'world', TRUE)"
  }

  {
    (db) -> db.escape_literal db.list {"foo", db.raw "lower(name)"}
    "('foo', lower(name))"
  }
}


describe "lapis.db.sqlite", ->
  local snapshot

  local db, schema
  local query_log

  before_each ->
    query_log = {}
    snapshot = assert\snapshot!

    env = require "lapis.environment"
    env.push {
      sqlite: {
        database: ":memory:"
      }
    }

    package.loaded["lapis.db.sqlite"] = nil
    package.loaded["lapis.db.sqlite.schema"] = nil

    db = require "lapis.db.sqlite"
    db\connect!

    schema = require "lapis.db.sqlite.schema"
    logger = require "lapis.logging"
    stub(logger, "query").invokes (query) ->
      table.insert query_log, query

  after_each ->
    snapshot\revert!

  describe "escape", ->
    for group in *TESTS
      it "matches", ->
        output = group[1] db
        if #group > 2
          assert.one_of output, { unpack group, 2 }
        else
          assert.same group[2], output

  it "sends query", ->
    assert.same {
      { cool: 100 }
    }, (db.query "select 100 as cool")

    assert.same {
      {
        a: 1
        b: 0
        c: "good's dog"
      }
    }, (db.query "select ? a, ? b, ? c", true, false, "good's dog")

    assert.same {
      [[select 100 as cool]]
      [[select TRUE a, FALSE b, 'good''s dog' c]]
    }, query_log

  it "db.insert", ->
    res = schema.create_table "my table", {
      {"id", schema.types.integer}
      {"name", schema.types.text default: "Hello World"}
      "PRIMARY KEY (id)"
    }, strict: true, without_rowid: true


    query_log = {}

    -- plain insert
    db.insert "my table", {
      id: 1
      name: "poppy"
    }

    -- returning by name
    assert.same {
      {
        id: 5
        name: "Hello World"
      }
    }, db.insert "my table", {
      id: 5
    }, "id", "name"

    -- aborting with conflict
    assert.has_error(
      -> db.insert "my table", { id: 5 }
      "UNIQUE constraint failed: my table.id"
    )

    -- ignoring conflict
    db.insert "my table", { id: 5 }, on_conflict: "do_nothing"

    -- returning and ignoring conflict
    assert.same {
      {
        id: 6
        name: "Hello World"
      }
    }, db.insert "my table", { id: 6 }, on_conflict: "do_nothing", returning: "*"

    assert.same {}, db.insert "my table", { id: 6 }, on_conflict: "do_nothing", returning: "*"

    assert.same {
      [[INSERT INTO "my table" ("id", "name") VALUES (1, 'poppy')]]
      [[INSERT INTO "my table" ("id") VALUES (5) RETURNING "id", "name"]]
      [[INSERT INTO "my table" ("id") VALUES (5)]]
      [[INSERT INTO "my table" ("id") VALUES (5) ON CONFLICT DO NOTHING]]
      [[INSERT INTO "my table" ("id") VALUES (6) ON CONFLICT DO NOTHING RETURNING *]]
      [[INSERT INTO "my table" ("id") VALUES (6) ON CONFLICT DO NOTHING RETURNING *]]
    }, query_log
  
  describe "lapis.db.sqlite.schema", ->
    it "creates and drops table", ->
      res = schema.create_table "my table", {
        {"id", schema.types.integer}
        {"name", schema.types.text default: "Hello World"}

        "PRIMARY KEY (id)"
      }, strict: true, without_rowid: true

      assert.same {}, res

      res = db.insert "my table", {
        id: 55
      }

      assert.same {}, res

      res = db.query [[select * from "my table"]]

      assert.same {
        {
          id: 55,
          name: "Hello World"
        }
      }, res


      res = db.query [[select * from sqlite_master WHERE type='table']]

      assert.same 1, #res
      assert.same "my table", res[1].name

      schema.drop_table "my table"

      assert.same {}, db.query [[select * from sqlite_master WHERE type='table']]

      assert.same {
        [[CREATE TABLE "my table" (
  "id" INTEGER NOT NULL,
  "name" TEXT NOT NULL DEFAULT 'Hello World',
  PRIMARY KEY (id)
) STRICT, WITHOUT ROWID]]
        [[INSERT INTO "my table" ("id") VALUES (55)]]
        [[select * from "my table"]]
        [[select * from sqlite_master WHERE type='table']]
        [[DROP TABLE IF EXISTS "my table"]]
        [[select * from sqlite_master WHERE type='table']]
      }, query_log

    it "creates and removes index", ->
      res = schema.create_table "my table", {
        {"id", schema.types.integer}
        {"name", schema.types.text default: "Hello World"}
        {"height", schema.types.real}

        "PRIMARY KEY (id)"
      }, strict: true

      schema.create_index "my table", "name", "height", unique: true

      assert.same {
        [[CREATE TABLE "my table" (
  "id" INTEGER NOT NULL,
  "name" TEXT NOT NULL DEFAULT 'Hello World',
  "height" REAL NOT NULL,
  PRIMARY KEY (id)
) STRICT]]
        [[CREATE UNIQUE INDEX "my table_name_height_idx" ON "my table" ("name", "height")]]
      }, query_log

      db.insert "my table", {
        id: 55
        name: "one"
        height: 2
      }

      assert.has_error(
        ->
          db.insert "my table", {
            id: 66
            name: "one"
            height: 2
          }
        "UNIQUE constraint failed: my table.name, my table.height"
      )

      assert.true schema.entity_exists "my table"
      assert.false schema.entity_exists "my_table"
      assert.true schema.entity_exists "my table_name_height_idx"


      schema.drop_index "my table", "name", "height"

      assert.false schema.entity_exists "my table_name_height_idx"

    it "adds and removes column", ->
      schema.create_table "some table", {
        {"id", schema.types.integer}
      }

      schema.add_column "some table", "name", schema.types.text default: "woop"
      schema.add_column "some table", "count", schema.types.numeric

      assert.has_error(
        -> schema.add_column "umm", "count", schema.types.numeric
        "no such table: umm"
      )

      db.insert "some table", {
        id: 12
        name: "yes"
        count: 55
      }

      assert.same {
        {
          id: 12
          name: "yes"
          count: 55
        }
      }, db.query 'select * from "some table"'


      schema.drop_column "some table", "count"

      assert.same {
        {
          id: 12
          name: "yes"
        }
      }, db.query 'select * from "some table"'


      assert.same {
        [[CREATE TABLE "some table" (
  "id" INTEGER NOT NULL
)]]
        [[ALTER TABLE "some table" ADD COLUMN "name" TEXT NOT NULL DEFAULT 'woop']]
        [[ALTER TABLE "some table" ADD COLUMN "count" NUMERIC NOT NULL]]
        [[ALTER TABLE "umm" ADD COLUMN "count" NUMERIC NOT NULL]]
        [[INSERT INTO "some table" ("id", "name", "count") VALUES (12, 'yes', 55)]]
        [[select * from "some table"]]
        [[ALTER TABLE "some table" DROP COLUMN "count"]]
        [[select * from "some table"]]
      }, query_log

    it "renames column and table", ->
      schema.create_table "some table", {
        {"id", schema.types.integer}
      }

      query_log = {}

      schema.rename_column "some table", "id", "the_id"
      schema.rename_table "some table", "the table"

      assert.same {
        [[ALTER TABLE "some table" RENAME COLUMN "id" TO "the_id"]]
        [[ALTER TABLE "some table" RENAME TO "the table"]]
      }, query_log

      definition = unpack db.query [[select * from sqlite_master WHERE type='table']]

      assert.same [[CREATE TABLE "the table" (
  "the_id" INTEGER NOT NULL
)]], definition.sql



