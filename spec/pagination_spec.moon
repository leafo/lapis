config = require "lapis.config"
config.default_config.postgres = {backend: "pgmoon"}
config.reset true

db = require "lapis.db.postgres"
import Model from require "lapis.db.postgres.model"
import stub_queries, assert_queries from require "spec.helpers"

describe "lapis.db.pagination", ->
  get_queries, mock_query = stub_queries!

  with old = assert_queries
    assert_queries = (expected) ->
      old expected, get_queries!

  describe "offset paginator", ->
    it "gets pages", ->
      class Thing extends Model
      import OffsetPaginator from require "lapis.db.pagination"

      pager = OffsetPaginator(Thing)
      assert.same {}, pager\get_page 1
      assert.same {}, pager\get_page 2
      assert.same {}, pager\get_page 3

      assert_queries {
        [[SELECT * from "thing" LIMIT 10 OFFSET 0]]
        [[SELECT * from "thing" LIMIT 10 OFFSET 10]]
        [[SELECT * from "thing" LIMIT 10 OFFSET 20]]
      }

    it "gets pages with per_page", ->
      class Thing extends Model
      import OffsetPaginator from require "lapis.db.pagination"

      pager = OffsetPaginator Thing, {
        per_page: 25
      }

      assert.same {}, pager\get_page 1
      assert.same {}, pager\get_page 2
      assert.same {}, pager\get_page 3

      assert_queries {
        [[SELECT * from "thing" LIMIT 25 OFFSET 0]]
        [[SELECT * from "thing" LIMIT 25 OFFSET 25]]
        [[SELECT * from "thing" LIMIT 25 OFFSET 50]]
      }

    it "paginates with clause", ->
      mock_query "COUNT%(%*%)", {{ c: 127 }}

      import OffsetPaginator from require "lapis.db.pagination"
      class Things extends Model

      p = OffsetPaginator Things, [[where group_id = ? order by name asc]], 123

      p\get_all!
      assert.same 127, p\total_items!
      assert.same 13, p\num_pages!
      assert.falsy p\has_items!

      p\get_page 1
      p\get_page 4

      assert_queries {
        'SELECT * from "things" where group_id = 123 order by name asc'
        'SELECT COUNT(*) AS c FROM "things" where group_id = 123 '
        'SELECT 1 FROM "things" where group_id = 123 limit 1'
        'SELECT * from "things" where group_id = 123 order by name asc LIMIT 10 OFFSET 0'
        'SELECT * from "things" where group_id = 123 order by name asc LIMIT 10 OFFSET 30'
      }

    it "iterates through pages", ->
      mock_query "OFFSET 0", { { id: 101 }, { id: 202 } }
      mock_query "OFFSET 10", { { id: 102 } }
      mock_query "OFFSET 20", { }

      class Thing extends Model
      import OffsetPaginator from require "lapis.db.pagination"

      pager = OffsetPaginator Thing

      assert.same {
        { { id: 101 }, { id: 202 } }
        { { id: 102 } }
      }, [page for page in pager\each_page!]

      assert_queries {
        [[SELECT * from "thing" LIMIT 10 OFFSET 0]]
        [[SELECT * from "thing" LIMIT 10 OFFSET 10]]
        [[SELECT * from "thing" LIMIT 10 OFFSET 20]]
      }


  describe "ordered paginator", ->
    it "gets page with single key", ->
      import OrderedPaginator from require "lapis.db.pagination"
      class Things extends Model

      pager = OrderedPaginator Things, "id", "where color = blue"
      res, np = pager\get_page!

      res, np = pager\get_page 123

      assert_queries {
        'SELECT * from "things" where color = blue order by "things"."id" ASC limit 10'
        'SELECT * from "things" where "things"."id" > 123 and (color = blue) order by "things"."id" ASC limit 10'
      }

    it "gets pages for multiple keys", ->
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


