

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
  
  it "creates table", ->
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

    assert.same {
      [[CREATE TABLE "my table" (
  "id" INTEGER NOT NULL,
  "name" TEXT NOT NULL DEFAULT 'Hello World',
  PRIMARY KEY (id)
) STRICT, WITHOUT ROWID]]
      [[INSERT INTO "my table" ("id") VALUES (55)]]
      [[select * from "my table"]]
    }, query_log


