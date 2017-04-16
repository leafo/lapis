config = require "lapis.config"
config.default_config.postgres = {backend: "pgmoon"}
config.reset true

db = require "lapis.db.postgres"
import Model from require "lapis.db.postgres.model"
import stub_queries, assert_queries from require "spec.helpers"

time = 1376377000

describe "lapis.db.model", ->
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
      'SELECT * from "things" '
      'SELECT * from "things" where id = 1234'
      'SELECT hello from "things" '
      'SELECT hello, world from "things" where id = 1234'
      [[SELECT * from "things" where color = '?']]
    }

  describe "find", ->
    it "basic", ->
      class Things extends Model

      Things\find "hello"
      Things\find cat: true, weight: 120

      assert_queries {
        [[SELECT * from "things" where "id" = 'hello' limit 1]]
        {
          [[SELECT * from "things" where "cat" = TRUE AND "weight" = 120 limit 1]]
          [[SELECT * from "things" where "weight" = 120 AND "cat" = TRUE limit 1]]
        }
      }

    it "composite primary key", ->
      class Things2 extends Model
        @primary_key: {"hello", "world"}

      Things2\find 1,2
      assert_queries {
        {
          [[SELECT * from "things" where "world" = 2 AND "hello" = 1 limit 1]]
          [[SELECT * from "things" where "hello" = 1 AND "world" = 2 limit 1]]
        }
      }

  describe "find_all", ->
    local Things
    before_each ->
      class Things extends Model

    it "many ids", ->
      Things\find_all { 1,2,3,4,5 }
      assert_queries {
        [[SELECT * from "things" WHERE "id" IN (1, 2, 3, 4, 5)]]
      }

    it "single id", ->
      Things\find_all { "yeah" }
      assert_queries {
        [[SELECT * from "things" WHERE "id" IN ('yeah')]]
      }

    it "empty ids", ->
      assert.same {}, Things\find_all {}
      assert_queries {}

    it "custom field", ->
      Things\find_all { 1,2,4 }, "dad"
      assert_queries {
        [[SELECT * from "things" WHERE "dad" IN (1, 2, 4)]]
      }
    
    it "with fields option", ->
      Things\find_all { 1,2,4 }, fields: "hello"
      assert_queries {
        [[SELECT hello from "things" WHERE "id" IN (1, 2, 4)]]
      }
    
    it "with multiple field and key option", ->
      Things\find_all { 1,2,4 }, fields: "hello, world", key: "dad"
      assert_queries {
        [[SELECT hello, world from "things" WHERE "dad" IN (1, 2, 4)]]
      }

    it "with empty where option", ->
      Things\find_all { 1,2,4 }, where: {}
      assert_queries {
        [[SELECT * from "things" WHERE "id" IN (1, 2, 4)]]
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
        {
          [[SELECT hello, world from "things" WHERE "dad" IN (1, 2, 4) AND "height" = '10px' AND "color" = 'blue']]
          [[SELECT hello, world from "things" WHERE "height" = '10px' AND "dad" IN (1, 2, 4) AND "color" = 'blue']]
          [[SELECT hello, world from "things" WHERE "height" = '10px' AND "color" = 'blue' AND "dad" IN (1, 2, 4)]]

          [[SELECT hello, world from "things" WHERE "dad" IN (1, 2, 4) AND "color" = 'blue' AND "height" = '10px']]
          [[SELECT hello, world from "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) AND "height" = '10px']]
          [[SELECT hello, world from "things" WHERE "color" = 'blue' AND "height" = '10px' AND "dad" IN (1, 2, 4)]]
        }
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
        {
          [[SELECT hello, world from "things" WHERE "dad" IN (1, 2, 4) AND "color" = 'blue' order by id limit 1234]]
          [[SELECT hello, world from "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) order by id limit 1234]]
        }
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
        {
          [[SELECT hello, world from "things" WHERE "dad" IN (1, 2, 4) AND "color" = 'blue' group by color]]
          [[SELECT hello, world from "things" WHERE "color" = 'blue' AND "dad" IN (1, 2, 4) group by color]]
        }
      }


  it "should paginate", ->
    mock_query "COUNT%(%*%)", {{ c: 127 }}
    mock_query "BLAH", {{ hello: "world"}}

    class Things extends Model

    p = Things\paginated [[where group_id = ? order by name asc]], 123

    p\get_all!
    assert.same 127, p\total_items!
    assert.same 13, p\num_pages!
    assert.falsy p\has_items!

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

    p7 = Things\paginated "where color = '?'"
    p7\total_items!
    p7\get_page 3

    assert_queries {
      'SELECT * from "things" where group_id = 123 order by name asc'
      'SELECT COUNT(*) AS c FROM "things" where group_id = 123 '
      'SELECT 1 FROM "things" where group_id = 123 limit 1'
      'SELECT * from "things" where group_id = 123 order by name asc LIMIT 10 OFFSET 0'
      'SELECT * from "things" where group_id = 123 order by name asc LIMIT 10 OFFSET 30'
      'SELECT * from "things" order by name asc LIMIT 25 OFFSET 50'
      'SELECT hello, world from "things" LIMIT 12 OFFSET 12'
      'SELECT hello, world from "things" LIMIT 12 OFFSET 12'
      'SELECT * from "things" order by BLAH LIMIT 10 OFFSET 0'
      'SELECT * from "things" order by BLAH LIMIT 10 OFFSET 10'
      'SELECT COUNT(*) AS c FROM "things" join whales on color = blue '
      'SELECT * from "things" join whales on color = blue order by BLAH LIMIT 10 OFFSET 10'
      [[SELECT COUNT(*) AS c FROM "things" where color = '?']]
      [[SELECT * from "things" where color = '?' LIMIT 10 OFFSET 20]]
    }

  it "should ordered paginate", ->
    import OrderedPaginator from require "lapis.db.pagination"
    class Things extends Model

    pager = OrderedPaginator Things, "id", "where color = blue"
    res, np = pager\get_page!

    res, np = pager\get_page 123

    assert_queries {
      'SELECT * from "things" where color = blue order by "things"."id" ASC limit 10'
      'SELECT * from "things" where "things"."id" > 123 and (color = blue) order by "things"."id" ASC limit 10'
    }

  it "should ordered paginate with multiple keys", ->
    import OrderedPaginator from require "lapis.db.pagination"
    class Things extends Model

    mock_query "SELECT", { { id: 101, updated_at: 300 }, { id: 102, updated_at: 301 } }

    pager = OrderedPaginator Things, {"id", "updated_at"}, "where color = blue"

    res, next_id, next_updated_at = pager\get_page!

    assert.same 102, next_id
    assert.same 301, next_updated_at

    pager\after!
    pager\before!

    pager\after 100
    pager\before 32

    pager\after 100, 200
    pager\before 32, 42

    assert_queries {
      'SELECT * from "things" where color = blue order by "things"."id" ASC, "things"."updated_at" ASC limit 10'

      'SELECT * from "things" where color = blue order by "things"."id" ASC, "things"."updated_at" ASC limit 10'
      'SELECT * from "things" where color = blue order by "things"."id" DESC, "things"."updated_at" DESC limit 10'

      'SELECT * from "things" where "things"."id" > 100 and (color = blue) order by "things"."id" ASC, "things"."updated_at" ASC limit 10'
      'SELECT * from "things" where "things"."id" < 32 and (color = blue) order by "things"."id" DESC, "things"."updated_at" DESC limit 10'

      'SELECT * from "things" where ("things"."id", "things"."updated_at") > (100, 200) and (color = blue) order by "things"."id" ASC, "things"."updated_at" ASC limit 10'
      'SELECT * from "things" where ("things"."id", "things"."updated_at") < (32, 42) and (color = blue) order by "things"."id" DESC, "things"."updated_at" DESC limit 10'
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
    }

  it "should create model with options", ->
    mock_query "INSERT", { { id: 101 } }

    class TimedThings extends Model
      @timestamp: true

    TimedThings\create { color: "blue" }, returning: { "height" }

    assert_queries {
      {
        [[INSERT INTO "timed_things" ("color", "created_at", "updated_at") VALUES ('blue', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id", "height"]]
        [[INSERT INTO "timed_things" ("created_at", "color", "updated_at") VALUES ('2013-08-13 06:56:40', 'blue', '2013-08-13 06:56:40') RETURNING "id", "height"]]
        [[INSERT INTO "timed_things" ("created_at", "updated_at", "color" ) VALUES ('2013-08-13 06:56:40', '2013-08-13 06:56:40', 'blue') RETURNING "id", "height"]]

        [[INSERT INTO "timed_things" ("color", "updated_at", "created_at") VALUES ('blue', '2013-08-13 06:56:40', '2013-08-13 06:56:40') RETURNING "id", "height"]]
        [[INSERT INTO "timed_things" ("updated_at", "color", "created_at") VALUES ('2013-08-13 06:56:40', 'blue', '2013-08-13 06:56:40') RETURNING "id", "height"]]
        [[INSERT INTO "timed_things" ("updated_at", "created_at", "color") VALUES ('2013-08-13 06:56:40', '2013-08-13 06:56:40', 'blue') RETURNING "id", "height"]]
      }
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
    row = Hi\create { color: db.NULL }, returning: "*"

    assert_queries {
      [[INSERT INTO "hi" ("color") VALUES (NULL) RETURNING *]]
    }

    assert.same {
      id: 101
    }, row

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
    }

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
    }

  it "should check unique constraint", ->
    class Things extends Model

    mock_query "SELECT 1", {{ yes: 1 }}

    assert.same true, Things\check_unique_constraint "name", "world"

    mock_query "SELECT 1", {}

    assert.same false, Things\check_unique_constraint color: "red", height: 10

    assert_queries {
      [[SELECT 1 from "things" where "name" = 'world' limit 1]]
      {
        [[SELECT 1 from "things" where "height" = 10 AND "color" = 'red' limit 1]]
        [[SELECT 1 from "things" where "color" = 'red' AND "height" = 10 limit 1]]
      }
    }


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

  describe "include_in", ->
    local Things, ThingItems, things

    before_each ->
      class Things extends Model
      class ThingItems extends Model
      things = [Things\load { id: i, other_id: (i + 7) * 2, thing_id: 100 + i } for i=1,5]

    it "with no options", ->
      ThingItems\include_in things, "thing_id"

      assert_queries {
        [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105)]]
      }

    it "with flip", ->
      ThingItems\include_in things, "thing_id", flip: true

      assert_queries {
        [[SELECT * from "thing_items" where "thing_id" in (1, 2, 3, 4, 5)]]
      }

    it "with where", ->
      ThingItems\include_in things, "thing_id", where: { dad: true }

      assert_queries {
        [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105) and "dad" = TRUE]]
      }

    it "with empty where", ->
      ThingItems\include_in things, "thing_id", where: { }

      assert_queries {
        [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105)]]
      }

    it "with fields", ->
      ThingItems\include_in things, "thing_id", fields: "one, two, three"

      assert_queries {
        [[SELECT one, two, three from "thing_items" where "id" in (101, 102, 103, 104, 105)]]
      }

    it "with order", ->
      ThingItems\include_in things, "thing_id", order: "title desc", many: true

      assert_queries {
        [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105) order by title desc]]
      }

    it "with group", ->
      ThingItems\include_in things, "thing_id", group: "yeah"

      assert_queries {
        [[SELECT * from "thing_items" where "id" in (101, 102, 103, 104, 105) group by yeah]]
      }

    it "with local key", ->
      ThingItems\include_in things, "thing_id", local_key: "other_id", flip: true

      assert_queries {
        [[SELECT * from "thing_items" where "thing_id" in (16, 18, 20, 22, 24)]]
      }

    it "with for relation", ->
      ThingItems\include_in things, "thing_id", for_relation: "yeahs"
      import LOADED_KEY from require "lapis.db.model.relations"
      for thing in *things
        assert.same thing[LOADED_KEY], { yeahs: true }

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
        [[SELECT yeah, count(*) from "thing_items" where "thing_id" in (16, 18, 20, 22, 24) and "deleted" = FALSE order by color desc group by yeah]]
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


