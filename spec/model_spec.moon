config = require "lapis.config"
config.default_config.postgres = {backend: "pgmoon"}
config.reset true

db = require "lapis.db.postgres"
import Model from require "lapis.db.postgres.model"
import stub_queries, assert_queries from require "spec.helpers"

import sorted_pairs from require "spec.helpers"

time = 1376377000

describe "lapis.db.model", ->
  sorted_pairs!
  get_queries, mock_query = stub_queries!

  local old_date

  with old = assert_queries
    assert_queries = (expected) ->
      old expected, get_queries!

  setup ->
    old_date = os.date
    os.date = (str) ->
      old_date str, time

  teardown ->
    os.date = old_date

  it "should get singular name", ->
    assert.same "thing", (class Things extends Model)\singular_name!
    assert.same "category", (class Categories extends Model)\singular_name!

  it "should get table name", ->
    assert.same "banned_users", (class BannedUsers extends Model)\table_name!
    assert.same "categories", (class Categories extends Model)\table_name!

  it "should select", ->
    class Things extends Model

    Things\select!
    Things\select "where id = ?", 1234
    Things\select fields: "hello" -- broke
    Things\select "where id = ?", 1234, fields: "hello, world"

    -- doesn't try to interpolate with no params
    Things\select "where color = '?'"


    assert_queries {
      'SELECT * FROM "things" '
      'SELECT * FROM "things" where id = 1234'
      'SELECT hello FROM "things" '
      'SELECT hello, world FROM "things" where id = 1234'
      [[SELECT * FROM "things" where color = '?']]
    }

  it "selects with db.clause", ->
    class Things extends Model

    Things\select db.clause {
      id: 999
    }

    Things\select db.clause({
      id: 999
    }), fields: "one, two"

    Things\select db.clause {
      id: 1289
    }

    Things\select(
      "inner join dogs on ? where ?"
      db.clause { id: db.raw "thing_id "}, table_name: "things"
      db.clause { height: 10 }, table_name: "dogs"
    )

    Things\select db.clause {
      one: true
      two: true
    }, operator: "OR"

    assert_queries {
      [[SELECT * FROM "things" WHERE "id" = 999]]
      [[SELECT one, two FROM "things" WHERE "id" = 999]]
      [[SELECT * FROM "things" WHERE "id" = 1289]]
      [[SELECT * FROM "things" inner join dogs on "things"."id" = thing_id where "dogs"."height" = 10]]
      [[SELECT * FROM "things" WHERE "one" OR "two"]]
    }

  it "should count", ->
    mock_query "COUNT%(%*%)", {{ c: 127 }}

    class Things extends Model

    -- meh, this can't do things like inner join, it should have been designed to work like select where you must write "where" yourself
    Things\count!
    Things\count "not deleted"
    Things\count "views > ?", 100

    Things\count db.clause {
      status: "promoted"
    }

    Things\count db.clause {
      alpha: true
      beta: true
    }, operator: "OR"

    assert_queries {
      [[SELECT COUNT(*) AS c FROM "things"]]
      [[SELECT COUNT(*) AS c FROM "things" WHERE not deleted]]
      [[SELECT COUNT(*) AS c FROM "things" WHERE views > 100]]
      [[SELECT COUNT(*) AS c FROM "things" WHERE "status" = 'promoted']]
      [[SELECT COUNT(*) AS c FROM "things" WHERE "alpha" OR "beta"]]
    }


  describe "find", ->
    it "handles empty clause", ->
      class Things extends Model

      assert.has_error(
        -> Things\find {}
        "db.encode_clause: passed an empty table"
      )

      assert.has_error(
        -> Things\find nil
        "Model.find: things: trying to find with no conditions"
      )

      assert.has_error(
        -> Things\find!
        "Model.find: things: trying to find with no conditions"
      )


    it "basic", ->
      class Things extends Model

      Things\find "hello"
      Things\find cat: true, weight: 120
      Things\find db.clause {
        age: 11
      }

      Things\find db.clause {
        deleted: true
        status: "deleted"
      }, operator: "OR"

      assert_queries {
        [[SELECT * FROM "things" WHERE "id" = 'hello' LIMIT 1]]
        [[SELECT * FROM "things" WHERE "cat" = TRUE AND "weight" = 120 LIMIT 1]]
        [[SELECT * FROM "things" WHERE "age" = 11 LIMIT 1]]
        [[SELECT * FROM "things" WHERE "deleted" OR "status" = 'deleted' LIMIT 1]]
      }

    it "composite primary key", ->
      class Things2 extends Model
        @primary_key: {"hello", "world"}

      Things2\find 1,2
      assert_queries {
        [[SELECT * FROM "things" WHERE "hello" = 1 AND "world" = 2 LIMIT 1]]
      }

  describe "find_all", ->
    local Things
    before_each ->
      class Things extends Model

    it "many ids", ->
      Things\find_all { 1,2,3,4,5 }
      assert_queries {
        [[SELECT * FROM "things" WHERE "id" IN (1, 2, 3, 4, 5)]]
      }

    it "single id", ->
      Things\find_all { "yeah" }
      assert_queries {
        [[SELECT * FROM "things" WHERE "id" IN ('yeah')]]
      }

    it "raw key", ->
      Things\find_all { "a", "b" }, db.raw "derived(id)"

      Things\find_all { "one", "two" }, {
        key: db.raw "lookup(name)"
      }

      assert_queries {
        [[SELECT * FROM "things" WHERE derived(id) IN ('a', 'b')]]
        [[SELECT * FROM "things" WHERE lookup(name) IN ('one', 'two')]]
      }

    it "fails with invalid key", ->
      assert.has_error(
        -> Things\find_all { "a", "b" }, { key: {"one", "two"} }
        "Model.find_all: (things) Must have a singular key to search"
      )

      assert.has_error(
        -> Things\find_all { "a", "b" }, db.list {"umm"}
        "Model.find_all: (things) Must have a singular key to search"
      )

      assert.has_error(
        -> Things\find_all { "a", "b" }, key: db.list {"yeah"}
        "Model.find_all: (things) Must have a singular key to search"
      )

    it "empty ids", ->
      assert.same {}, Things\find_all {}
      assert_queries {}

    it "custom field", ->
      Things\find_all { 1,2,4 }, "dad"
      assert_queries {
        [[SELECT * FROM "things" WHERE "dad" IN (1, 2, 4)]]
      }

    it "with fields option", ->
      Things\find_all { 1,2,4 }, fields: "hello"
      assert_queries {
        [[SELECT hello FROM "things" WHERE "id" IN (1, 2, 4)]]
      }

    it "with multiple field and key option", ->
      Things\find_all { 1,2,4 }, fields: "hello, world", key: "dad"
      assert_queries {
        [[SELECT hello, world FROM "things" WHERE "dad" IN (1, 2, 4)]]
      }

    it "with empty where option", ->
      Things\find_all { 1,2,4 }, where: {}
      assert_queries {
        [[SELECT * FROM "things" WHERE "id" IN (1, 2, 4)]]
      }

    it "with db.clause", ->
      Things\find_all { 1,2,4 }, where: db.clause {
        name: "thing"
      }

      Things\find_all { 1,2,4 }, where: db.clause {
        deleted: true
        status: "deleted"
      }, operator: "OR"

      assert_queries {
        [[SELECT * FROM "things" WHERE "name" = 'thing' AND "id" IN (1, 2, 4)]]
        [[SELECT * FROM "things" WHERE ("deleted" OR "status" = 'deleted') AND "id" IN (1, 2, 4)]]
      }

    it "with complex options", ->
      Things\find_all { 1,2,4 }, {
        fields: "hello, world"
        key: "dad"
        where: {
          color: "blue"
          height: "10px"
        }
      }

      -- :/
      assert_queries {
        [[SELECT hello, world FROM "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) AND "height" = '10px']]
      }

    it "with complex options & interpolated clause", ->
      Things\find_all { 1,2,4 }, {
        fields: "hello, world"
        key: "dad"
        where: {
          color: "blue"
        }
        clause: {
          "order by id limit ?", 1234
        }
      }

      assert_queries {
        [[SELECT hello, world FROM "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) order by id limit 1234]]
      }

    it "with complex options & plain clause", ->
      Things\find_all { 1,2,4 }, {
        fields: "hello, world"
        key: "dad"
        where: {
          color: "blue"
        }
        clause: "group by color"
      }

      assert_queries {
        [[SELECT hello, world FROM "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) group by color]]
      }


  it "creates paginator", ->
    mock_query "COUNT%(%*%)", {{ c: 127 }}
    mock_query "BLAH", {{ hello: "world"}}

    class Things extends Model

    pager = Things\paginated "where color = ?", "blue", per_page: 99
    pager\total_items!
    pager\get_page 3

    -- without opts
    pager2 = Things\paginated "where number = ?", 100
    pager2\get_page 2

    assert_queries {
      [[SELECT COUNT(*) AS c FROM "things" where color = 'blue']]
      [[SELECT * FROM "things" where color = 'blue' LIMIT 99 OFFSET 198]]
      [[SELECT * FROM "things" where number = 100 LIMIT 10 OFFSET 10]]
    }


  it "creates ordered paginator", ->
    class Things extends Model

    pager = Things\paginated "where color = ?", "blue", {
      per_page: 99
      ordered: "id"
    }

    import OrderedPaginator from require "lapis.db.pagination"

    assert.same OrderedPaginator, pager.__class

    -- without opts
    pager2 = Things\paginated "where not deleted", {
      ordered: {"created_at", "id"}
      per_page: 55
    }

    assert.same OrderedPaginator, pager2.__class

    pager\get_page 100
    pager2\get_page "2020-6-8", 202

    assert_queries {
      [[SELECT * FROM "things" where "things"."id" > 100 and (color = 'blue') order by "things"."id" ASC limit 99]]
      [[SELECT * FROM "things" where ("things"."created_at", "things"."id") > ('2020-6-8', 202) and (not deleted) order by "things"."created_at" ASC, "things"."id" ASC limit 55]]
    }


  it "should create model", ->
    mock_query "INSERT", { { id: 101 } }

    class Things extends Model

    thing = Things\create color: "blue"

    assert.same { id: 101, color: "blue" }, thing

    class TimedThings extends Model
      @timestamp: true

    thing2 = TimedThings\create hello: "world"

    class OtherThings extends Model
      @primary_key: {"id_a", "id_b"}

    mock_query "INSERT", { { id_a: "hello", id_b: "world" } }

    thing3 = OtherThings\create id_a: 120, height: "400px"

    assert.same { id_a: "hello", id_b: "world", height: "400px"}, thing3

    assert_queries {
      [[INSERT INTO "things" ("color") VALUES ('blue') RETURNING "id"]]
      [[INSERT INTO "timed_things" ("created_at", "hello", "updated_at") VALUES ('2013-08-13 06:56:40', 'world', '2013-08-13 06:56:40') RETURNING "id"]]
      [[INSERT INTO "other_things" ("height", "id_a") VALUES ('400px', 120) RETURNING "id_a", "id_b"]]

    }

  it "should create model with options", ->
    mock_query "INSERT", { { id: 101 } }

    class TimedThings extends Model
      @timestamp: true

    TimedThings\create { color: "blue" }, returning: { "height" }

    assert_queries {
      [[INSERT INTO "timed_things" ("color", "created_at", "updated_at") VALUES ('blue', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id", "height"]]
    }

  it "should create model with returning *", ->
    mock_query "INSERT", { { id: 101, color: "gotya" } }

    class Hi extends Model
    row = Hi\create { color: "blue" }, returning: "*"

    assert_queries {
      [[INSERT INTO "hi" ("color") VALUES ('blue') RETURNING *]]
    }

    assert.same {
      id: 101
      color: "gotya"
    }, row

  it "strips db.NULL when creating with return *", ->
    mock_query "INSERT", { { id: 101 } }
    class Hi extends Model
    row1 = Hi\create { color: db.NULL }, returning: "*"
    row2 = Hi\create { color: db.raw "x+y" }, returning: "*"

    assert_queries {
      [[INSERT INTO "hi" ("color") VALUES (NULL) RETURNING *]]
      [[INSERT INTO "hi" ("color") VALUES (x+y) RETURNING *]]
    }

    assert.same {
      id: 101
    }, row1

  it "should refresh model", ->
    class Things extends Model
    mock_query "SELECT", { { id: 123 } }

    instance = Things\load { id: 123 }
    instance\refresh!
    assert.same { id: 123 }, instance

    instance\refresh "hello"
    assert.same { id: 123 }, instance

    instance\refresh "foo", "bar"
    assert.same { id: 123 }, instance

    assert_queries {
      'SELECT * from "things" where "id" = 123'
      'SELECT "hello" from "things" where "id" = 123'
      'SELECT "foo", "bar" from "things" where "id" = 123'
    }

  it "should refresh model with composite primary key", ->
    class Things extends Model
      @primary_key: {"a", "b"}

    mock_query "SELECT", { { a: "hello", b: false } }
    instance = Things\load { a: "hello", b: false }
    instance\refresh!

    assert.same { a: "hello", b: false }, instance

    instance\refresh "hello"
    assert.same { a: "hello", b: false }, instance

    assert_queries {
      [[SELECT * from "things" where "a" = 'hello' AND "b" = FALSE]]
      [[SELECT "hello" from "things" where "a" = 'hello' AND "b" = FALSE]]
    }

  it "updates model", ->
    class Things extends Model

    thing = Things\load { id: 12 }

    -- no query is mocked
    assert.same {
      false, {}
    }, {
      thing\update color: "green", height: 100
    }

    assert.same { height: 100, color: "green", id: 12 }, thing

    mock_query ".", { affected_rows: 1 }

    thing2 = Things\load { age: 2000, sprit: true }
    assert.same {
      true, {affected_rows: 1}
    }, {
      thing2\update "age"
    }

    class TimedThings extends Model
      @primary_key: {"a", "b"}
      @timestamp: true

    thing3 = TimedThings\load { a: 2, b: 3 }
    thing3\update! -- does nothing
    -- thing3\update "what" -- should error set to null
    thing3\update great: true -- need a way to stub date before testing

    thing3.hello = "world"
    thing3\update "hello", timestamp: false

    mock_query ".", { affected_rows: 0 }

    assert.same {
      false, { affected_rows: 0 }
    }, {
      thing3\update { cat: "dog" }, timestamp: false
    }

    assert_queries {
      [[UPDATE "things" SET "color" = 'green', "height" = 100 WHERE "id" = 12]]

      [[UPDATE "things" SET "age" = 2000 WHERE "id" IS NULL]]
      [[UPDATE "timed_things" SET "great" = TRUE, "updated_at" = '2013-08-13 06:56:40' WHERE "a" = 2 AND "b" = 3]]
      [[UPDATE "timed_things" SET "hello" = 'world' WHERE "a" = 2 AND "b" = 3]]
      [[UPDATE "timed_things" SET "cat" = 'dog' WHERE "a" = 2 AND "b" = 3]]
    }

  it "updates model with conditional", ->
    mock_query ".", { affected_rows: 1 }

    class Things extends Model

    class TimedThings extends Model
      @primary_key: {"a", "b"}
      @timestamp: true

    thing = Things\load { id: 12 }

    assert.same {
      true, { affected_rows: 1 }
    }, {
      thing\update { color: "green", height: 100}, where: { color: "blue"}
    }

    assert.same {id: 12 }, thing\_primary_cond!
    assert.same {
      color: "green"
      height: 100
      id: 12
    }, thing

    thing2 = TimedThings\load { a: 2, b: 3 }
    thing2\update {
      b: 4
      actor: "good"
    }, where: db.clause {
      "update_count < 100"
      update_id: db.NULL
    }

    assert.same {
      a: 2
      b: 4
      actor: "good"
    }, thing2

    thing2\update {
      yes: "no"
    }, where: db.clause {
      deleted: true
      status: "deleted"
    }, operator: "OR"

    mock_query "count %+ 1", {
      affected_rows: 1
      {
        count: 200
        height: 44
        duplex: "cat"
      }
    }

    thing\update {
      count: db.raw "count + 1"
    }, where: {
      count: 0
    }

    assert.same 200, thing.count
    assert.same 100, thing.height -- doesn't pull random field
    assert.same nil, thing.duplex -- doesn't pull random field

    thing2.b = nil
    thing2\update {
      color: "green"
    }, {
      timestamp: false
      where: { age: "10" }
    }

    assert.has_error(
      ->
        thing2\update {
          color: "green"
        }, {
          where: "oopsie"
        }
      "Model.update: where condition must be a table or db.clause"
    )

    assert_queries {
      [[UPDATE "things" SET "color" = 'green', "height" = 100 WHERE "id" = 12 AND ("color" = 'blue')]]
      [[UPDATE "timed_things" SET "actor" = 'good', "b" = 4, "updated_at" = '2013-08-13 06:56:40' WHERE "a" = 2 AND "b" = 3 AND (update_count < 100) AND "update_id" IS NULL]]
      [[UPDATE "timed_things" SET "updated_at" = '2013-08-13 06:56:40', "yes" = 'no' WHERE "a" = 2 AND "b" = 4 AND ("deleted" OR "status" = 'deleted')]]
      [[UPDATE "things" SET "count" = count + 1 WHERE "id" = 12 AND ("count" = 0) RETURNING "count"]]
      [[UPDATE "timed_things" SET "color" = 'green' WHERE "a" = 2 AND "b" IS NULL AND ("age" = '10')]]
    }

  it "deletes model", ->
    mock_query [["id" = 2]], { affected_rows: 1 }

    class Things extends Model

    thing = Things\load { id: 2 }
    assert.same true, (thing\delete!)

    thing = Things\load { }
    assert.same false, (thing\delete!)

    class Things2 extends Model
      @primary_key: {"key1", "key2"}

    thing = Things2\load { key1: "blah blag", key2: 4821 }
    thing\delete!

    thing\delete "one", "two"
    thing\delete db.clause(status: "spam")

    thing.key2 = nil
    thing\delete db.clause(status: "spam"), "cool"
    thing\delete db.clause({status: "spam", spam: true}, operator: "OR"), "cool"

    assert_queries {
      [[DELETE FROM "things" WHERE "id" = 2]]
      [[DELETE FROM "things" WHERE "id" IS NULL]]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" = 4821]]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" = 4821 RETURNING "one", "two"]]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" = 4821 AND "status" = 'spam']]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" IS NULL AND "status" = 'spam' RETURNING "cool"]]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" IS NULL AND ("spam" OR "status" = 'spam') RETURNING "cool"]]
    }

  it "should check unique constraint", ->
    class Things extends Model

    mock_query "SELECT 1", {{ yes: 1 }}

    assert.same true, Things\check_unique_constraint "name", "world"

    mock_query "SELECT 1", {}

    assert.same false, Things\check_unique_constraint color: "red", height: 10

    assert_queries {
      [[SELECT 1 from "things" where "name" = 'world' limit 1]]
      [[SELECT 1 from "things" where "color" = 'red' AND "height" = 10 limit 1]]
    }


  it "should create model with extend syntax", ->
    m, m_mt = Model\extend "the_things", {
      timestamp: true
      primary_key: {"hello", "world"}
      constraints: {
        hello: =>
      }
    }

    assert.same "the_things", m\table_name!
    assert.same {"hello", "world"}, { m\primary_keys! }
    assert.truthy m.constraints.hello

    m_mt.test_method = => "id:#{@id}"

    inst = m\load { id: 55 }

    assert.same "id:55", inst\test_method!


  describe "include_in", ->
    local Things, ThingItems, things

    before_each ->
      class Things extends Model
      class ThingItems extends Model
      things = [Things\load { id: i, other_id: (i + 7) * 2, thing_id: 100 + i } for i=1,5]

    it "with no options", ->
      thing_items = {
        { id: 101, name: "leaf" }
        { id: 103, name: "loaf" }
        { id: 104, name: "laugh" }
      }

      mock_query "SELECT", thing_items

      ThingItems\include_in things, "thing_id"

      -- TODO: this naming isn't right, shouldn't it be called `thing_item`
      assert.same thing_items[1], things[1].thing
      assert.same nil, things[2].thing
      assert.same thing_items[2], things[3].thing
      assert.same thing_items[3], things[4].thing
      assert.same nil, things[5].thing

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105)]]
      }

    it "with skip_included", ->
      things[1].thing = { id: 101, name: "leaf" }
      things[4].thing = { id: 104, name: "leaf" }

      ThingItems\include_in things, "thing_id", skip_included: true

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (102, 103, 105)]]
      }


    it "with flip", ->
      ThingItems\include_in things, "thing_id", flip: true

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "thing_id" IN (1, 2, 3, 4, 5)]]
      }

    it "with where", ->
      ThingItems\include_in things, "thing_id", where: { dad: true }

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105) AND "dad"]]
      }

    it "with empty where", ->
      ThingItems\include_in things, "thing_id", where: { }

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105)]]
      }

    it "with db.clause", ->
      ThingItems\include_in things, "thing_id", where: db.clause {
        {"counter > ?", 10}
        db.clause {
          "alpha"
          beta: "dog"
        }, operator: "OR"
      }

      ThingItems\include_in things, "thing_id", where: db.clause {
        alpha: db.NULL
        beta: db.list {"dog", "cat", "snot"}
        db.clause {
          thing: true
          thong: false
        }, operator: "and" -- NOTE: intentionally testing lowercase operator here
      }, operator: "OR"

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105) AND (counter > 10) AND ((alpha) OR "beta" = 'dog')]]
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105) AND (("thing" and NOT "thong") OR "alpha" IS NULL OR "beta" IN ('dog', 'cat', 'snot'))]]
      }

    it "with fields", ->
      ThingItems\include_in things, "thing_id", fields: "one, two, three"

      assert_queries {
        [[SELECT one, two, three FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105)]]
      }

    it "with order", ->
      ThingItems\include_in things, "thing_id", order: "title desc", many: true

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105) ORDER BY title desc]]
      }

    it "with group", ->
      ThingItems\include_in things, "thing_id", group: "yeah"

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (101, 102, 103, 104, 105) GROUP BY yeah]]
      }

    it "with local key", ->
      ThingItems\include_in things, "thing_id", local_key: "other_id", flip: true

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "thing_id" IN (16, 18, 20, 22, 24)]]
      }

    it "with for relation", ->
      ThingItems\include_in things, "thing_id", for_relation: "yeahs"
      import LOADED_KEY from require "lapis.db.model.relations"
      for thing in *things
        assert.same thing[LOADED_KEY], { yeahs: true }

    it "skip_included with relation", ->
      import mark_loaded_relations from require "lapis.db.model.relations"

      mark_loaded_relations {things[1], things[2]}, "yeahs"

      ThingItems\include_in things, "thing_id", {
        for_relation: "yeahs"
        skip_included: true
      }

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE "id" IN (103, 104, 105)]]
      }

    it "combines many options", ->
      ThingItems\include_in things, "thing_id", {
        fields: "yeah, count(*)"
        where: { deleted: false }
        group: "yeah"
        flip: true
        order: "color desc"
        many: true
        local_key: "other_id"
      }

      assert_queries {
        [[SELECT yeah, count(*) FROM "thing_items" WHERE "thing_id" IN (16, 18, 20, 22, 24) AND NOT "deleted" GROUP BY yeah ORDER BY color desc]]
      }

    it "applies value function", ->
      mock_query "SELECT", {
        {thing_id: 1, count: 222}
        {thing_id: 2, count: 9}
      }

      ThingItems\include_in {things[1]}, "thing_id", {
        flip: true
        value: (res) -> res.count
      }

      assert.same {
        thing_item: 222
        thing_id: 101
        other_id: 16
        id: 1
      }, things[1]

    it "fetches many", ->
      mock_query "SELECT", {
        {thing_id: 1, name: "one"}
        {thing_id: 1, count: "two"}
      }

      things = {things[1], things[2]}
      ThingItems\include_in things, "thing_id", flip: true, many: true

      assert.same {
        {thing_id: 1, name: "one"}
        {thing_id: 1, count: "two"}
      }, things[1].thing_items

      assert.same {}, things[2].thing_items

  describe "include_in with composite keys", ->
    local Things, ThingItems, things

    before_each ->
      class Things extends Model
      class ThingItems extends Model
      things = for i=1,5
        Things\load {
          id: i
          alpha_id: 100 + math.floor i / 2
          beta_id: 200 + i
        }

    it "with simple keys", ->
      mock_query "SELECT", {
        { id: 1, alpha_id: 101, beta_id: 202 }
        { id: 2, alpha_id: 101, beta_id: 203 }
        { id: 3, alpha_id: 102, beta_id: 204 }
        { id: 4, alpha_id: 100, beta_id: 201 }
      }

      ThingItems\include_in things, {
        "alpha_id", "beta_id"
      }

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE ("alpha_id", "beta_id") IN ((100, 201), (101, 202), (101, 203), (102, 204), (102, 205))]]
      }

      assert.same {
        id: 1
        alpha_id: 100
        beta_id: 201
        thing_item: {
          id: 4, alpha_id: 100, beta_id: 201
        }
      }, things[1]

      assert.same {
        id: 2
        alpha_id: 101
        beta_id: 202
        thing_item: {
          id: 1, alpha_id: 101, beta_id: 202
        }
      }, things[2]

      assert.same {
        id: 3
        alpha_id: 101
        beta_id: 203
        thing_item: {
          id: 2, alpha_id: 101, beta_id: 203
        }
      }, things[3]

      assert.same {
        id: 4
        alpha_id: 102
        beta_id: 204
        thing_item: {
          id: 3, alpha_id: 102, beta_id: 204
        }
      }, things[4]

      assert.same {
        id: 5
        alpha_id: 102
        beta_id: 205
      }, things[5]

    it "with mapped keys", ->
      thing_items = {
        { id: 1, aid: 101, bid: 202 }
        { id: 2, aid: 101, bid: 203 }
        { id: 3, aid: 102, bid: 204 }
        { id: 4, aid: 100, bid: 201 }
      }

      mock_query "SELECT", thing_items

      ThingItems\include_in things, {
        aid: "alpha_id"
        bid: "beta_id"
      }

      assert_queries {
        {
          [[SELECT * FROM "thing_items" WHERE ("aid", "bid") IN ((100, 201), (101, 202), (101, 203), (102, 204), (102, 205))]]
          [[SELECT * FROM "thing_items" WHERE ("bid", "aid") IN ((201, 100), (202, 101), (203, 101), (204, 102), (205, 102))]]
        }
      }

      assert.same thing_items[4], things[1].thing_item
      assert.same thing_items[1], things[2].thing_item
      assert.same thing_items[2], things[3].thing_item
      assert.same thing_items[3], things[4].thing_item
      assert.same nil, things[5].thing_item

    it "with mapped keys combined with where", ->
      thing_items = {
        { id: 1, aid: 101, bid: 202 }
        { id: 2, aid: 101, bid: 203 }
        { id: 3, aid: 102, bid: 204 }
        { id: 4, aid: 100, bid: 201 }
      }

      mock_query "SELECT", thing_items

      ThingItems\include_in things, {
        aid: "alpha_id"
        bid: "beta_id"
      }, {
        where: {
          deleted: false
        }
      }

      ThingItems\include_in things, {
        aid: "alpha_id"
        bid: "beta_id"
      }, {
        where: db.clause {
          blessed: true
          ordained: true
        }, operator: "OR"
      }

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE ("aid", "bid") IN ((100, 201), (101, 202), (101, 203), (102, 204), (102, 205)) AND NOT "deleted"]]
        [[SELECT * FROM "thing_items" WHERE ("aid", "bid") IN ((100, 201), (101, 202), (101, 203), (102, 204), (102, 205)) AND ("blessed" OR "ordained")]]
      }

    it "with many", ->
      thing_items = {
        { id: 1, aid: 101, bid: 202 }
        { id: 2, aid: 101, bid: 202 }
        { id: 3, aid: 102, bid: 204 }
      }

      mock_query "SELECT", thing_items

      ThingItems\include_in things, {
        aid: "alpha_id"
        bid: "beta_id"
      }, many: true

      assert_queries {
        [[SELECT * FROM "thing_items" WHERE ("aid", "bid") IN ((100, 201), (101, 202), (101, 203), (102, 204), (102, 205))]]
      }

      assert.same {}, things[1].thing_items
      assert.same {
        { id: 1, aid: 101, bid: 202 }
        { id: 2, aid: 101, bid: 202 }
      }, things[2].thing_items

      assert.same {}, things[3].thing_items
      assert.same {
        { id: 3, aid: 102, bid: 204 }
      }, things[4].thing_items
      assert.same {}, things[5].thing_items


  describe "constraints", ->
    it "should prevent update/insert for failed constraint", ->
      mock_query "INSERT", { { id: 101 } }

      class Things extends Model
        @constraints: {
          name: (val) => val == "hello" and "name can't be hello"
        }

      assert.same { nil, "name can't be hello"}, { Things\create name: "hello" }

      thing = Things\load { id: 0, name: "hello" }
      assert.same { nil, "name can't be hello"}, { thing\update "name" }

      assert_queries {}

    it "should prevent create for missing field", ->
      class Things extends Model
        @constraints: {
          name: (val) =>
            "missing `name`" unless val
        }

      assert.same { nil, "missing `name`"}, { Things\create! }

    it "should allow to update values on create and on update", ->
      mock_query "INSERT", { { id: 101 } }

      class Things extends Model
        @constraints: {
          name: (val, column, values) => values.name = 'changed from ' .. val
        }

      thing = Things\create name: 'create'
      thing\update name: 'update'

      assert_queries {
        [[INSERT INTO "things" ("name") VALUES ('changed from create') RETURNING "id"]]
        [[UPDATE "things" SET "name" = 'changed from update' WHERE "id" = 101]]
      }

  describe "inheritance", ->
    it "returns correct cached table name", ->
      class FirstModel extends Model
      class SecondModel extends FirstModel
      assert.same "first_model", FirstModel\table_name!
      assert.same "second_model", SecondModel\table_name!

    it "returns correct cached table name when flipped", ->
      class FirstModel extends Model
      class SecondModel extends FirstModel
      assert.same "second_model", SecondModel\table_name!
      assert.same "first_model", FirstModel\table_name!

    it "fetches relation", ->
      class Firsts extends Model

      class Seconds extends Firsts
        @primary_key: "hello_id"

      class OtherModel extends Model
        @get_relation_model: (name) =>
          ({ :Seconds })[name]

        @relations: {
          {"second", has_one: "Seconds"}
        }

      m = OtherModel\load {
        id: 5
      }

      m\get_second!


  describe "enum", ->
    import enum from require "lapis.db.model"

    it "should create an enum", ->
      e = enum {
        hello: 1
        world: 2
        foo: 3
        bar: 3
      }

    describe "with enum", ->
      local e
      before_each ->
        e = enum {
          hello: 1
          world: 2
          foo: 3
          bar: 4
        }

      it "should get enum values", ->
        assert.same "hello", e[1]
        assert.same "world", e[2]
        assert.same "foo", e[3]
        assert.same "bar", e[4]

        assert.same 1, e.hello
        assert.same 2, e.world
        assert.same 3, e.foo
        assert.same 4, e.bar

      it "should get enum for_db", ->
        assert.same 1, e\for_db "hello"
        assert.same 1, e\for_db 1

        assert.same 2, e\for_db "world"
        assert.same 2, e\for_db 2

        assert.same 3, e\for_db "foo"
        assert.same 3, e\for_db 3

        assert.same 4, e\for_db "bar"
        assert.same 4, e\for_db 4

        assert.has_error ->
          e\for_db "far"

        assert.has_error ->
          e\for_db 5

      it "should get enum to_name", ->
        assert.same "hello", e\to_name "hello"
        assert.same "hello", e\to_name 1

        assert.same "world", e\to_name "world"
        assert.same "world", e\to_name 2

        assert.same "foo", e\to_name "foo"
        assert.same "foo", e\to_name 3

        assert.same "bar", e\to_name "bar"
        assert.same "bar", e\to_name 4

  describe "scoped model", ->
    it "creates a scoped model with prefix only", ->
      CoolThingsModel = Model\scoped_model "cool_things_"

      package.loaded.models = {
        Worlds: "itworks"
      }

      class Hellos extends CoolThingsModel

      assert.same "cool_things_hellos", Hellos\table_name!
      assert.same "hello", Hellos\singular_name!

      assert.same "itworks", Hellos\get_relation_model "Worlds"

    it "creates a scoped model with prefix, module, and external", ->
      GreatModel = Model\scoped_model "great_", "great.models", {
        Users: true
      }

      package.loaded.models = {
        Twos: "itdoesntowkr"
        Users: "definitelyworks"
      }

      package.loaded["great.models"] = {
        Twos: "itworks"
      }

      class Ones extends GreatModel

      assert.same "great_ones", Ones\table_name!
      assert.same "one", Ones\singular_name!

      assert.same "itworks", Ones\get_relation_model "Twos"
      assert.same "definitelyworks", Ones\get_relation_model "Users"


