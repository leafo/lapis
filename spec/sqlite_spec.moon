unpack = unpack or table.unpack

import sorted_pairs from require "spec.helpers"

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


-- Note: core model specs depend on same reference to lapis.db so we have to
-- run it in separate block
describe "sqlite core model specs", ->
  setup ->
    env = require "lapis.environment"
    env.push "test", {
      sqlite: {
        database: ":memory:"
      }
    }

  teardown ->
    env = require "lapis.environment"
    env.pop!

  import Users, Posts, Likes from require "spec.sqlite_models"
  build = require "spec.core_model_specs"
  build { :Users, :Posts, :Likes }

describe "lapis.db.sqlite", ->
  sorted_pairs!

  local snapshot

  local db, schema, logger
  local query_log

  setup ->
    env = require "lapis.environment"
    env.push "test", {
      -- NOTE: the logging order changes when performance measurement is
      -- enabled. Queries that fail will *not* be logged with measurement
      -- enabled
      -- measure_performance: true

      sqlite: {
        database: ":memory:"
      }
    }

  before_each ->
    query_log = {}
    snapshot = assert\snapshot!

    db = require "lapis.db.sqlite"
    db\connect! -- this forces an empty db for every test

    schema = require "lapis.db.sqlite.schema"
    logger = require "lapis.logging"

    original_logger = logger.query
    stub(logger, "query").invokes (query, ...) ->
      -- original_logger query, ...
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

  it "db.select", ->
    res = schema.create_table "my table", {
      {"id", schema.types.integer}
      {"name", schema.types.text default: "Hello World"}
      "PRIMARY KEY (id)"
    }, strict: true, without_rowid: true

    query_log = {}

    db.select '* from "my table" where id = ?', 100

    db.select 'id from "my table" where ?', db.clause {
      {"id > ?", 23}
      name: "cool"
    }

    assert.same {
      [[SELECT * from "my table" where id = 100]]
      [[SELECT id from "my table" where (id > 23) AND "name" = 'cool']]
    }, query_log

  it "db.insert", ->
    res = schema.create_table "my table", {
      {"id", schema.types.integer}
      {"name", schema.types.text default: "Hello World"}
      "PRIMARY KEY (id)"
    }, strict: true, without_rowid: true

    query_log = {}

    -- plain insert
    assert.same {
      affected_rows: 1
    }, db.insert "my table", {
      id: 1
      name: "poppy"
    }

    -- returning by name
    assert.same {
      affected_rows: 1
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
    assert.same {
      affected_rows: 0
    }, db.insert "my table", { id: 5 }, on_conflict: "do_nothing"

    -- returning and ignoring conflict
    assert.same {
      affected_rows: 1
      {
        id: 6
        name: "Hello World"
      }
    }, db.insert "my table", { id: 6 }, on_conflict: "do_nothing", returning: "*"

    assert.same {affected_rows: 0}, db.insert "my table", { id: 6 }, on_conflict: "do_nothing", returning: "*"

    assert.same {
      [[INSERT INTO "my table" ("id", "name") VALUES (1, 'poppy')]]
      [[INSERT INTO "my table" ("id") VALUES (5) RETURNING "id", "name"]]
      [[INSERT INTO "my table" ("id") VALUES (5)]]
      [[INSERT INTO "my table" ("id") VALUES (5) ON CONFLICT DO NOTHING]]
      [[INSERT INTO "my table" ("id") VALUES (6) ON CONFLICT DO NOTHING RETURNING *]]
      [[INSERT INTO "my table" ("id") VALUES (6) ON CONFLICT DO NOTHING RETURNING *]]
    }, query_log

  it "db.update", ->
    res = schema.create_table "my table", {
      {"id", schema.types.integer}
      {"name", schema.types.text default: "Hello World"}
      "PRIMARY KEY (id)"
    }, strict: true, without_rowid: true

    assert.same {
      affected_rows: 1
    }, db.insert "my table", {
      id: 1
      name: "poppy"
    }

    assert.same {
      affected_rows: 1
    }, db.insert "my table", {
      id: 2
      name: "pappy"
    }

    query_log = {}

    -- update every row with no clause
    assert.same {
      affected_rows: 2
    }, db.update "my table", {
      name: "cool"
    }

    -- update by query fragment
    assert.same {
      affected_rows: 1
    }, db.update "my table", {
      name: "cool"
    }, "id in (?)", 1, "id" -- this last value is ignored since we can't do returning with this syntax format

    -- update by clause object
    assert.same {
      affected_rows: 1
    }, db.update "my table", {
      name: "wassup"
    }, id: 2

    -- update with returning
    assert.same {
      affected_rows: 1
      {
        id: 1
        name: "cool"
      }
    }, db.update "my table", {
      name: "cool"
    }, { id: 1 }, "id", "name"

    -- update with returning but no matches
    assert.same {
      affected_rows: 0
    }, db.update "my table", {
      name: "cool"
    }, { id: 88 }, "id", "name"

    -- update multiple with returning
    assert.same {
      affected_rows: 2
      {
        id: 1
        name: "id:1"
      }
      {
        id: 2
        name: "id:2"
      }
    }, db.update "my table", {
      name: db.raw db.interpolate_query "? || id", "id:"
    }, db.clause({
      {"id in ?", db.list {1,2}}
    }), db.raw "*"

    assert.same {
      [[UPDATE "my table" SET "name" = 'cool']]
      [[UPDATE "my table" SET "name" = 'cool' WHERE id in (1)]]
      [[UPDATE "my table" SET "name" = 'wassup' WHERE "id" = 2]]
      [[UPDATE "my table" SET "name" = 'cool' WHERE "id" = 1 RETURNING "id", "name"]]
      [[UPDATE "my table" SET "name" = 'cool' WHERE "id" = 88 RETURNING "id", "name"]]
      [[UPDATE "my table" SET "name" = 'id:' || id WHERE (id in (1, 2)) RETURNING *]]
    }, query_log

  it "db.delete", ->
    res = schema.create_table "my table", {
      {"id", schema.types.integer}
      {"name", schema.types.text default: "Hello World"}
      "PRIMARY KEY (id)"
    }, strict: true, without_rowid: true

    assert.same {
      affected_rows: 1
    }, db.insert "my table", {
      id: 1
      name: "poppy"
    }

    assert.same {
      affected_rows: 1
    }, db.insert "my table", {
      id: 2
      name: "pappy"
    }

    query_log = {}

    assert.same {
      affected_rows: 1
    }, db.delete "my table", {
      id: 1
    }

    assert.same {
      affected_rows: 0
    }, db.delete "my table", {
      id: 1
    }, "id"


    assert.same {
      affected_rows: 0
    }, db.delete "my table", db.clause {
      {"id > ?", 500}
    }

    assert.has_error(
      -> db.delete "my table"
      "Blocking call to db.delete with no conditions. Use db.truncate"
    )

    assert.same {
      [[DELETE FROM "my table" WHERE "id" = 1]]
      [[DELETE FROM "my table" WHERE "id" = 1 RETURNING "id"]]
      [[DELETE FROM "my table" WHERE (id > 500)]]
    }, query_log

  it "db.truncate", ->
    schema.create_table "first", {
      {"id", schema.types.integer}
      "PRIMARY KEY (id)"
    }

    schema.create_table "second", {
      {"id", schema.types.integer}
      "PRIMARY KEY (id)"
    }

    query_log = {}

    db.insert "first", {}
    db.insert "first", {}
    db.insert "first", {}
    db.insert "second", {}

    assert.same {
      affected_rows: 4
    }, db.truncate "first", "second"

    assert.same {
      [[INSERT INTO "first" DEFAULT VALUES]]
      [[INSERT INTO "first" DEFAULT VALUES]]
      [[INSERT INTO "first" DEFAULT VALUES]]
      [[INSERT INTO "second" DEFAULT VALUES]]
      [[DELETE FROM "first"]]
      [[DELETE FROM "second"]]
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

      assert.same {
        affected_rows: 1
      }, res

      res = db.query [[select * from "my table"]]

      assert.same {
        {
          id: 55,
          name: "Hello World"
        }
      }, res

      res = db.query [[select name from sqlite_master WHERE type='table']]

      assert.same {
        {
          name: "my table"
        }
      }, res

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
        [[select name from sqlite_master WHERE type='table']]
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
        [[INSERT INTO "some table" ("count", "id", "name") VALUES (55, 12, 'yes')]]
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

  describe "lapis.db.sqlite.model", ->
    local MyNames, DualKeys, Model
    DEFAULT_DATE = "2023-02-10 21:27:00"

    before_each ->
      schema.create_table "my_names", {
        {"id", schema.types.integer}

        {"created_at", schema.types.text}
        {"updated_at", schema.types.text}

        {"name", schema.types.text default: "Hello World"}
        "PRIMARY KEY (id)"
      }, strict: true

      schema.create_table "dual_keys", {
        {"a", schema.types.text}
        {"b", schema.types.text}

        {"name", schema.types.text}
        "PRIMARY KEY (a,b)"
      }, strict: true

      query_log = {} -- reset log

      import Model from require "lapis.db.sqlite.model"

      stub(db, "format_date").invokes => DEFAULT_DATE

      class MyNames extends Model
        @timestamp: true

      class DualKeys extends Model
        @primary_key: {"a", "b"}

    it "Model:columns", ->
      assert.same {
        {
          cid: 0
          name: "id"
          notnull: 1
          pk: 1
          type: "INTEGER"
        }
        {
          cid: 1,
          name: "created_at",
          notnull: 1,
          pk: 0
          type: "TEXT"
        }
        {
          cid: 2,
          name: "updated_at",
          notnull: 1,
          pk: 0,
          type: "TEXT"
        },
        {
          cid: 3,
          dflt_value: "'Hello World'",
          name: "name",
          notnull: 1,
          pk: 0,
          type: "TEXT"
        }
      }, MyNames\columns!

    it "Model:create", ->
      m1 = MyNames\create {
        name: "Crumbles"
      }

      assert.same {
        created_at: DEFAULT_DATE
        updated_at: DEFAULT_DATE

        id: 1
        name: "Crumbles"
      }, m1

      m2 = MyNames\create {
        name: db.raw "'Nanette' || 2"
      }, returning: "*"

      assert.same {
        created_at: DEFAULT_DATE
        updated_at: DEFAULT_DATE

        id: 2
        name: "Nanette2"
      }, m2

      assert.same {
        [[INSERT INTO "my_names" ("created_at", "name", "updated_at") VALUES ('2023-02-10 21:27:00', 'Crumbles', '2023-02-10 21:27:00') RETURNING "id"]]
        [[INSERT INTO "my_names" ("created_at", "name", "updated_at") VALUES ('2023-02-10 21:27:00', 'Nanette' || 2, '2023-02-10 21:27:00') RETURNING *]]
      }, query_log

    it "Model:update", ->
      -- handles when model no longer has record
      missing = MyNames\load { id: 99, name: "CowCat" }

      assert.same {
        false
        { affected_rows: 0 }
      }, {
        missing\update {
          name: "CowThree"
        }
      }

      dk = DualKeys\create {
        a: "first"
        b: "second"
        name: "Deep"
      }

      assert.same {
        true
        {
          affected_rows: 1
        }
      }, { dk\update "name" }

      assert.same {
        true
        {
          {
            name: "100"
          }
          affected_rows: 1
        }
      }, { dk\update {
        name: db.raw "99 + 1"
      }}

      assert.same {
        a: "first"
        b: "second"
        name: "100"
      }, dk

      assert.same {
        true
        {
          affected_rows: 1
        }
      }, {
        dk\update {
          name: "Lastly..."
        }, where: db.clause { name: "100" }
      }

      assert.same {
        [[UPDATE "my_names" SET "name" = 'CowThree', "updated_at" = '2023-02-10 21:27:00' WHERE "id" = 99]]
        [[INSERT INTO "dual_keys" ("a", "b", "name") VALUES ('first', 'second', 'Deep') RETURNING "a", "b"]]
        [[UPDATE "dual_keys" SET "name" = 'Deep' WHERE "a" = 'first' AND "b" = 'second']]
        [[UPDATE "dual_keys" SET "name" = 99 + 1 WHERE "a" = 'first' AND "b" = 'second' RETURNING "name"]]
        [[UPDATE "dual_keys" SET "name" = 'Lastly...' WHERE "a" = 'first' AND "b" = 'second' AND "name" = '100']]
      }, query_log

    it "Model:delete", ->
      dk = DualKeys\create {
        a: "first"
        b: "second"
        name: "Deep"
      }

      roo = MyNames\create {
        name: "Roo"
      }

      assert.same {
        false
        {
          affected_rows: 0
        }
      }, { dk\delete db.clause {
        name: "Reep"
      }}

      assert.same {
        true
        {
          affected_rows: 1
        }
      }, { dk\delete! }


      assert.same {
        false
        {
          affected_rows: 0
        }
      }, { dk\delete! }

      assert.same {
        true
        {
          affected_rows: 1
          { name: "Roo" }
        }
      }, { roo\delete "name" }

      assert.same {
        [[INSERT INTO "dual_keys" ("a", "b", "name") VALUES ('first', 'second', 'Deep') RETURNING "a", "b"]]
        [[INSERT INTO "my_names" ("created_at", "name", "updated_at") VALUES ('2023-02-10 21:27:00', 'Roo', '2023-02-10 21:27:00') RETURNING "id"]]
        [[DELETE FROM "dual_keys" WHERE "a" = 'first' AND "b" = 'second' AND "name" = 'Reep']]
        [[DELETE FROM "dual_keys" WHERE "a" = 'first' AND "b" = 'second']]
        [[DELETE FROM "dual_keys" WHERE "a" = 'first' AND "b" = 'second']]
        [[DELETE FROM "my_names" WHERE "id" = 1 RETURNING "name"]]
      }, query_log

    it "Model:refresh", ->
      db.insert "my_names", {
        id: 99
        name: "Very Fresh"
        created_at: DEFAULT_DATE
        updated_at: DEFAULT_DATE
      }

      unfresh = MyNames\load { id: 99 }
      assert unfresh\refresh!
      assert.same {
        id: 99
        name: "Very Fresh"
        created_at: DEFAULT_DATE
        updated_at: DEFAULT_DATE
      }, unfresh

      invalid = MyNames\load { id: 100 }
      assert.has_error(
        -> invalid\refresh!
        "my_names failed to find row to refresh from, did the primary key change?"
      )

      assert.same {
        [[INSERT INTO "my_names" ("created_at", "id", "name", "updated_at") VALUES ('2023-02-10 21:27:00', 99, 'Very Fresh', '2023-02-10 21:27:00')]]
        [[SELECT * from "my_names" where "id" = 99]]
        [[SELECT * from "my_names" where "id" = 100]]
      }, query_log


    it "Model:paginated", ->
      pager = MyNames\paginated!
      pager\get_page 1

      pager2 = MyNames\paginated db.clause {
        {"id > 5"}
      }
      pager2\get_page 1

      assert.same 0, pager2\num_pages!

      assert.false pager2\has_items!
      assert.false pager\has_items!

      assert.same {
        [[SELECT * FROM "my_names"  LIMIT 10 OFFSET 0]]
        [[SELECT * FROM "my_names" WHERE (id > 5) LIMIT 10 OFFSET 0]]
        [[SELECT COUNT(*) AS c FROM "my_names" WHERE (id > 5)]]
        [[SELECT 1 FROM "my_names" WHERE (id > 5) LIMIT 1]]
        [[SELECT 1 FROM "my_names"  LIMIT 1]]
      }, query_log


  describe "lapis.db.migrations", ->
    local migrations

    before_each ->
      migrations = require("lapis.db.migrations")

      -- silence logging
      stub(logger, "migration").invokes ->
      stub(logger, "migration_summary").invokes ->
      stub(logger, "notice").invokes ->

    it "creates migrations table", ->
      migrations.create_migrations_table!
      assert.true schema.entity_exists "lapis_migrations"

    it "runs migrations on empty database", ->
      m = {
        ->
          schema.create_table "first", {
            {"id", schema.types.integer}
            "PRIMARY KEY (id)"
          }

      }

      migrations.run_migrations m
      -- this does nothing
      migrations.run_migrations m

      assert.same {
        { name: "1" }
      }, migrations.LapisMigrations\select!


    it "runs migrations on empty database with transaction", ->
      m = {
        ->
          schema.create_table "first", {
            {"id", schema.types.integer}
            "PRIMARY KEY (id)"
          }

      }

      migrations.run_migrations m, nil, transaction: "global"

