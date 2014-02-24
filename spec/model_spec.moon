
db = require "lapis.nginx.postgres"
import Model from require "lapis.db.model"

time = 1376377000

local old_query_fn, old_date
describe "lapis.db.model.", ->
  local queries
  local query_mock

  setup ->
    export ngx = { null: nil }

    old_query_fn = db.set_backend "raw", (q) ->
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
    db.set_backend "raw", old_query_fn
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

    assert.same {
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

    class Things2 extends Model
      @primary_key: {"hello", "world"}

    Things2\find 1,2


    assert.same {
      [[SELECT * from "things" where "id" = 'hello' limit 1]]
      [[SELECT * from "things" where "cat" = TRUE AND "weight" = 120 limit 1]]
      [[SELECT * from "things" where "id" in (1, 2, 3, 4, 5)]]
      [[SELECT * from "things" where "id" in ('yeah')]]
      [[SELECT * from "things" where "dad" in (1, 2, 4)]]
      [[SELECT hello from "things" where "id" in (1, 2, 4)]]
      [[SELECT hello, world from "things" where "dad" in (1, 2, 4)]]
      [[SELECT * from "things" where "world" = 2 AND "hello" = 1 limit 1]]
    }, queries

  it "should paginate", ->
    query_mock['COUNT%(%*%)'] = {{ c: 127 }}

    class Things extends Model

    p = Things\paginated [[where group_id = ? order by name asc]], 123

    p\get_all!
    assert.same 127, p\total_items!
    assert.same 13, p\num_pages!

    p\get_page 1
    p\get_page 4

    p2 = Things\paginated [[order by name asc]], 123, per_page: 25

    p2\get_page 3

    -- TODO: make clause optional
    p3 = Things\paginated "", fields: "hello, world", per_page: 12
    p3\get_page 2

    assert.same {
      'SELECT * from "things" where group_id = 123 order by name asc'
      'SELECT COUNT(*) as c from "things" where group_id = 123 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 0 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 30 '
      'SELECT * from "things" order by name asc limit 25 offset 50 '
      'SELECT hello, world from "things" limit 12 offset 12 '
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


    assert.same {
      [[INSERT INTO "things" ("color") VALUES ('blue') RETURNING "id"]]
      [[INSERT INTO "timed_things" ("hello", "created_at", "updated_at") VALUES ('world', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id"]]
      [[INSERT INTO "other_things" ("height", "id_a") VALUES ('400px', 120) RETURNING "id_a", "id_b"]]
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

    assert.same {
      [[UPDATE "things" SET "height" = 100, "color" = 'green' WHERE "id" = 12]]
      [[UPDATE "things" SET "age" = 2000 WHERE "id" IS NULL]]
      [[UPDATE "timed_things" SET "updated_at" = '2013-08-13 06:56:40', "great" = TRUE WHERE "a" = 2 AND "b" = 3]]
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

    assert.same {
      [[DELETE FROM "things" WHERE "id" = 2]]
      [[DELETE FROM "things" WHERE "id" IS NULL]]
      [[DELETE FROM "things" WHERE "key1" = 'blah blag' AND "key2" = 4821]]
    }, queries


  it "should check unique constraint", ->
    class Things extends Model

    query_mock['SELECT 1'] = {{ yes: 1 }}

    assert.same true, Things\check_unique_constraint "name", "world"

    query_mock['SELECT 1'] = {}

    assert.same false, Things\check_unique_constraint color: "red", height: 10

    assert.same {
      [[SELECT 1 from "things" where "name" = 'world' limit 1]]
      [[SELECT 1 from "things" where "height" = 10 AND "color" = 'red' limit 1]]
    }, queries


  it "should prevent update/insert", ->
    query_mock['INSERT'] = { { id: 101 } }

    class Things extends Model
      @constraints: {
        name: (val) => val == "hello" and "name can't be hello"
      }

    assert.same { nil, "name can't be hello"}, { Things\create name: "hello" }

    thing = Things\load { id: 0, name: "hello" }
    assert.same { nil, "name can't be hello"}, { thing\update "name" }

    assert.same { }, queries

  it "should include other association", ->
    class Things extends Model

    class ThingItems extends Model

    things = [Things\load { id: i, thing_id: 100 + i } for i=1,10]

    ThingItems\include_in things, "thing_id"
    ThingItems\include_in things, "thing_id", flip: true
    ThingItems\include_in things, "thing_id", where: { dad: true }
    ThingItems\include_in things, "thing_id", fields: "one, two, three"

    assert.same {
      [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110)]]
      [[SELECT * from "thing_items" where "thing_id" in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10)]]
      [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110) and "dad" = TRUE]]
      [[SELECT one, two, three from "thing_items" where "id" in (101, 102, 103, 104, 105, 106, 107, 108, 109, 110)]]
    }, queries

  it "should create model with extend syntax", ->
    m = Model\extend "the_things", {
      timestamp: true
      primary_key: {"hello", "world"}
    }

    assert.same "the_things", m\table_name!
    assert.same {"hello", "world"}, { m\primary_keys! }


