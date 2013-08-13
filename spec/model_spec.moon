
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

    assert.same {
      'SELECT * from "things" where group_id = 123 order by name asc'
      'SELECT COUNT(*) as c from "things" where group_id = 123 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 0 '
      'SELECT * from "things" where group_id = 123 order by name asc limit 10 offset 30 '
      'SELECT * from "things" order by name asc limit 25 offset 50 '
    }, queries

  it "should create model", ->
    class Things extends Model
    query_mock['INSERT'] = { { id: 101 } }

    thing = Things\create color: "blue"

    assert.same { id: 101, color: "blue" }, thing

    class OtherThings extends Model
      @primary_key: {"id_a", "id_b"}

    query_mock['INSERT'] = { { id_a: "hello", id_b: "world" } }

    thing2 = OtherThings\create id_a: 120, height: "400px"

    assert.same { id_a: "hello", id_b: "world", height: "400px"}, thing2

    assert.same {
      [[INSERT INTO "things" ("color") VALUES ('blue') RETURNING "id"]]
      [[INSERT INTO "other_things" ("height", "id_a") VALUES ('400px', 120) RETURNING "id_a", "id_b"]]
    }, queries


  it "should update model", ->
    class Things extends Model

    thing = Things\load {}
    thing\update color: "green", height: 100

    assert.same { height: 100, color: "green" }, thing

    thing2 = Things\load { age: 2000, sprit: true }
    thing2\update "age"


    class TimedThings extends Model
      @timestamp: true

    thing3 = TimedThings\load {}
    thing3\update! -- does nothing
    -- thing3\update "what" -- should error set to null
    thing3\update great: true -- need a way to stub date before testing

    assert.same {
      [[UPDATE "things" SET "height" = 100, "color" = 'green']]
      [[UPDATE "things" SET "age" = 2000]]
      [[UPDATE "timed_things" SET "updated_at" = '2013-08-13 06:56:40', "great" = TRUE]]
    }, queries

