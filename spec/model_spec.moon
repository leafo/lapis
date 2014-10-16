
db = require "lapis.nginx.postgres"
import Model from require "lapis.db.model"
import with_query_fn, assert_queries from require "spec.helpers"

time = 1376377000

describe "lapis.db.model", ->
  local queries
  local query_mock

  local restore_query
  local old_date

  setup ->
    export ngx = { null: nil }

    restore_query = with_query_fn (q) ->
      table.insert queries, (q\gsub("%s+", " ")\gsub("[\n\t]", " "))

      -- try to find a mock
      for k,v in pairs query_mock
        if q\match k
          return v

      {}

    old_date = os.date
    os.date = (str) ->
      old_date str, time

  teardown ->
    export ngx = nil
    restore_query!
    os.date = old_date

  before_each ->
    queries = {}
    query_mock = {}

  it "should select", ->
    class Things extends Model

    Things\select!
    Things\select "where id = ?", 1234
    Things\select fields: "hello" -- broke
    Things\select "where id = ?", 1234, fields: "hello, world"

    assert_queries {
      'SELECT * from "things" '
      'SELECT * from "things" where id = 1234'
      'SELECT hello from "things" '
      'SELECT hello, world from "things" where id = 1234'
    }, queries


  it "should find", ->
    class Things extends Model

    Things\find "hello"
    Things\find cat: true, weight: 120

    Things\find_all { 1,2,3,4,5 }
    Things\find_all { "yeah" }
    Things\find_all { }

    Things\find_all { 1,2,4 }, "dad"
    Things\find_all { 1,2,4 }, fields: "hello"
    Things\find_all { 1,2,4 }, fields: "hello, world", key: "dad"

    Things\find_all { 1,2,4 }, {
      fields: "hello, world"
      key: "dad"
      where: {
        color: "blue"
        height: "10px"
      }
    }

    class Things2 extends Model
      @primary_key: {"hello", "world"}

    Things2\find 1,2

    assert_queries {
      [[SELECT * from "things" where "id" = 'hello' limit 1]]
      {
        [[SELECT * from "things" where "cat" = TRUE AND "weight" = 120 limit 1]]
        [[SELECT * from "things" where "weight" = 120 AND "cat" = TRUE limit 1]]
      }
      [[SELECT * from "things" where "id" in (1, 2, 3, 4, 5)]]
      [[SELECT * from "things" where "id" in ('yeah')]]
      [[SELECT * from "things" where "dad" in (1, 2, 4)]]
      [[SELECT hello from "things" where "id" in (1, 2, 4)]]
      [[SELECT hello, world from "things" where "dad" in (1, 2, 4)]]
      {
        [[SELECT hello, world from "things" where "dad" in (1, 2, 4) and "height" = '10px' AND "color" = 'blue']]
        [[SELECT hello, world from "things" where "dad" in (1, 2, 4) and "color" = 'blue' AND "height" = '10px']]
      }
      {
        [[SELECT * from "things" where "world" = 2 AND "hello" = 1 limit 1]]
        [[SELECT * from "things" where "hello" = 1 AND "world" = 2 limit 1]]
      }
    }, queries

  it "should paginate", ->
    query_mock['COUNT%(%*%)'] = {{ c: 127 }}
    query_mock['BLAH'] = {{ hello: "world"}}

    class Things extends Model

    p = Things\paginated [[where group_id = ? order by name asc]], 123

    p\get_all!
    assert.same 127, p\total_items!
    assert.same 13, p\num_pages!

    p\get_page 1
    p\get_page 4

    p2 = Things\paginated [[order by name asc]], 123, per_page: 25

    p2\get_page 3

    p3 = Things\paginated "", fields: "hello, world", per_page: 12
    p3\get_page 2

    p4 = Things\paginated fields: "hello, world", per_page: 12
    p4\get_page 2

    p5 = Things\paginated [[order by BLAH]]
    iter = p5\each_page!
    iter!
    iter!

    p6 = Things\paginated [[join whales on color = blue order by BLAH]]
    p6\total_items!
    p6\get_page 2

    assert_queries {
      'SELECT * from "things" where group_id = 123 order by name asc'
      'SELECT COUNT(*) as c from "things" where group_id = 123 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 0 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 30 '
      'SELECT * from "things" order by name asc limit 25 offset 50 '
      'SELECT hello, world from "things" limit 12 offset 12 '
      'SELECT hello, world from "things" limit 12 offset 12 '
      'SELECT * from "things" order by BLAH limit 10 offset 0 '
      'SELECT * from "things" order by BLAH limit 10 offset 10 '
      'SELECT COUNT(*) as c from "things" join whales on color = blue '
      'SELECT * from "things" join whales on color = blue order by BLAH limit 10 offset 10 '
    }, queries


  it "should ordered paginate", ->
    import OrderedPaginator from require "lapis.db.pagination"
    class Things extends Model

    pager = OrderedPaginator Things, "id", "where color = blue"
    res, np = pager\get_page!

    res, np = pager\get_page 123

    assert_queries {
      'SELECT * from "things" where color = blue order by "id" ASC limit 10'
      'SELECT * from "things" where "id" > 123 and (color = blue) order by "id" ASC limit 10'
    }, queries

  it "should create model", ->
    class Things extends Model
    query_mock['INSERT'] = { { id: 101 } }

    thing = Things\create color: "blue"

    assert.same { id: 101, color: "blue" }, thing

    class TimedThings extends Model
      @timestamp: true

    thing2 = TimedThings\create hello: "world"

    class OtherThings extends Model
      @primary_key: {"id_a", "id_b"}

    query_mock['INSERT'] = { { id_a: "hello", id_b: "world" } }

    thing3 = OtherThings\create id_a: 120, height: "400px"

    assert.same { id_a: "hello", id_b: "world", height: "400px"}, thing3

    assert_queries {
      [[INSERT INTO "things" ("color") VALUES ('blue') RETURNING "id"]]
      {
        [[INSERT INTO "timed_things" ("hello", "created_at", "updated_at") VALUES ('world', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id"]]
        [[INSERT INTO "timed_things" ("created_at", "hello", "updated_at") VALUES ('2013-08-13 06:56:40', 'world', '2013-08-13 06:56:40') RETURNING "id"]]
        [[INSERT INTO "timed_things" ("created_at", "updated_at", "hello" ) VALUES ('2013-08-13 06:56:40', '2013-08-13 06:56:40', 'world') RETURNING "id"]]

        [[INSERT INTO "timed_things" ("hello", "updated_at", "created_at") VALUES ('world', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id"]]
        [[INSERT INTO "timed_things" ("updated_at", "hello", "created_at") VALUES ('2013-08-13 06:56:40', 'world', '2013-08-13 06:56:40') RETURNING "id"]]
        [[INSERT INTO "timed_things" ("updated_at", "created_at", "hello" ) VALUES ('2013-08-13 06:56:40', '2013-08-13 06:56:40', 'world') RETURNING "id"]]
      }
      {
        [[INSERT INTO "other_things" ("height", "id_a") VALUES ('400px', 120) RETURNING "id_a", "id_b"]]
        [[INSERT INTO "other_things" ("id_a", "height") VALUES (120, '400px') RETURNING "id_a", "id_b"]]
      }
    }, queries


  it "should refresh model", ->
    class Things extends Model
    query_mock['SELECT'] = { { id: 123 } }

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
    }, queries


  it "should refresh model with composite primary key", ->
    class Things extends Model
      @primary_key: {"a", "b"}

    query_mock['SELECT'] = { { a: "hello", b: false } }
    instance = Things\load { a: "hello", b: false }
    instance\refresh!

    assert.same { a: "hello", b: false }, instance

    instance\refresh "hello"
    assert.same { a: "hello", b: false }, instance

    assert_queries {
      [[SELECT * from "things" where "a" = 'hello' AND "b" = FALSE]]
      [[SELECT "hello" from "things" where "a" = 'hello' AND "b" = FALSE]]
    }, queries


  it "should update model", ->
    class Things extends Model

    thing = Things\load { id: 12 }
    thing\update color: "green", height: 100

    assert.same { height: 100, color: "green", id: 12 }, thing

    thing2 = Things\load { age: 2000, sprit: true }
    thing2\update "age"


    class TimedThings extends Model
      @primary_key: {"a", "b"}
      @timestamp: true

    thing3 = TimedThings\load { a: 2, b: 3 }
    thing3\update! -- does nothing
    -- thing3\update "what" -- should error set to null
    thing3\update great: true -- need a way to stub date before testing

    thing3.hello = "world"
    thing3\update "hello", timestamp: false
    thing3\update { cat: "dog" }, timestamp: false

    assert_queries {
      {
        [[UPDATE "things" SET "height" = 100, "color" = 'green' WHERE "id" = 12]]
        [[UPDATE "things" SET "color" = 'green', "height" = 100 WHERE "id" = 12]]
      }
      [[UPDATE "things" SET "age" = 2000 WHERE "id" IS NULL]]
      {
        [[UPDATE "timed_things" SET "updated_at" = '2013-08-13 06:56:40', "great" = TRUE WHERE "a" = 2 AND "b" = 3]]
        [[UPDATE "timed_things" SET "great" = TRUE, "updated_at" = '2013-08-13 06:56:40' WHERE "a" = 2 AND "b" = 3]]

        [[UPDATE "timed_things" SET "updated_at" = '2013-08-13 06:56:40', "great" = TRUE WHERE "b" = 3 AND "a" = 2]]
        [[UPDATE "timed_things" SET "great" = TRUE, "updated_at" = '2013-08-13 06:56:40' WHERE "b" = 3 AND "a" = 2]]
      }
      [[UPDATE "timed_things" SET "hello" = 'world' WHERE "a" = 2 AND "b" = 3]]
      [[UPDATE "timed_things" SET "cat" = 'dog' WHERE "a" = 2 AND "b" = 3]]
    }, queries

  it "should delete model", ->
    class Things extends Model

    thing = Things\load { id: 2 }
    thing\delete!

    thing = Things\load { }
    thing\delete!


    class Things2 extends Model
      @primary_key: {"key1", "key2"}

    thing = Things2\load { key1: "blah blag", key2: 4821 }
    thing\delete!

    assert_queries {
      [[DELETE FROM "things" WHERE "id" = 2]]
      [[DELETE FROM "things" WHERE "id" IS NULL]]
      {
        [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" = 4821]]
        [[DELETE FROM "things" WHERE "key2" = 4821 AND "key1" = 'blah blag']]
      }
    }, queries


  it "should check unique constraint", ->
    class Things extends Model

    query_mock['SELECT 1'] = {{ yes: 1 }}

    assert.same true, Things\check_unique_constraint "name", "world"

    query_mock['SELECT 1'] = {}

    assert.same false, Things\check_unique_constraint color: "red", height: 10

    assert_queries {
      [[SELECT 1 from "things" where "name" = 'world' limit 1]]
      {
        [[SELECT 1 from "things" where "height" = 10 AND "color" = 'red' limit 1]]
        [[SELECT 1 from "things" where "color" = 'red' AND "height" = 10 limit 1]]
      }
    }, queries



  it "should include other association", ->
    class Things extends Model

    class ThingItems extends Model

    things = [Things\load { id: i, thing_id: 100 + i } for i=1,10]

    ThingItems\include_in things, "thing_id"
    ThingItems\include_in things, "thing_id", flip: true
    ThingItems\include_in things, "thing_id", where: { dad: true }
    ThingItems\include_in things, "thing_id", fields: "one, two, three"

    assert_queries {
      [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110)]]
      [[SELECT * from "thing_items" where "thing_id" in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]]
      [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110) and "dad" = TRUE]]
      [[SELECT one, two, three from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110)]]
    }, queries

  it "should create model with extend syntax", ->
    m = Model\extend "the_things", {
      timestamp: true
      primary_key: {"hello", "world"}
      constraints: {
        hello: =>
      }
    }

    assert.same "the_things", m\table_name!
    assert.same {"hello", "world"}, { m\primary_keys! }
    assert.truthy m.constraints.hello

  describe "constraints", ->
    it "should prevent update/insert for failed constraint", ->
      query_mock['INSERT'] = { { id: 101 } }

      class Things extends Model
        @constraints: {
          name: (val) => val == "hello" and "name can't be hello"
        }

      assert.same { nil, "name can't be hello"}, { Things\create name: "hello" }

      thing = Things\load { id: 0, name: "hello" }
      assert.same { nil, "name can't be hello"}, { thing\update "name" }

      assert_queries { }, queries

    it "should prevent create for missing field", ->
      class Things extends Model
        @constraints: {
          name: (val) =>
            "missing `name`" unless val
        }

      assert.same { nil, "missing `name`"}, { Things\create! }


