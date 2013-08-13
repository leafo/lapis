
db = require "lapis.nginx.postgres"
import Model from require "lapis.db.model"

local old_query_fn
describe "lapis.db.model.", ->
  local queries
  local query_mock

  setup ->
    old_query_fn = db.set_backend "raw", (q) ->
      table.insert queries, (q\gsub("%s+", " ")\gsub("[\n\t]", " "))

      -- try to find a mock
      for k,v in pairs query_mock
        if q\match k
          return v

      {}

  teardown ->
    db.set_backend "raw", old_query_fn

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

