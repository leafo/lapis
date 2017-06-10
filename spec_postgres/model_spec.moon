
import setup_db, teardown_db from require "spec_postgres.helpers"

import drop_tables, truncate_tables from require "lapis.spec.db"

db = require "lapis.db.postgres"
import Model, enum from require "lapis.db.postgres.model"
import types, create_table from require "lapis.db.postgres.schema"

class Users extends Model
  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.serial}
      {"name", types.text}
      "PRIMARY KEY (id)"
    }

  @truncate: =>
    truncate_tables @

class Posts extends Model
  @timestamp: true

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.serial}
      {"user_id", types.foreign_key null: true}
      {"title", types.text null: false}
      {"body", types.text null: false}
      {"created_at", types.time}
      {"updated_at", types.time}
      "PRIMARY KEY (id)"
    }

  @truncate: =>
    truncate_tables @

class Likes extends Model
  @primary_key: {"user_id", "post_id"}
  @timestamp: true

  @relations: {
    {"user", belongs_to: "Users"}
    {"post", belongs_to: "Posts"}
  }

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"user_id", types.foreign_key}
      {"post_id", types.foreign_key}
      {"count", types.integer default: 1}
      {"created_at", types.time}
      {"updated_at", types.time}
      "PRIMARY KEY (user_id, post_id)"
    }

  @truncate: =>
    truncate_tables @


class HasArrays extends Model
  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.serial}
      {"tags", types.text array: true}
      "PRIMARY KEY (id)"
    }

describe "model", ->
  setup ->
    setup_db!

  teardown ->
    teardown_db!

  describe "core model", ->
    build = require "spec.core_model_specs"
    build { :Users, :Posts, :Likes }

  it "should get columns of model", ->
    Users\create_table!
    assert.same {
      {
        data_type: "integer"
        column_name: "id"
      }
      {
        data_type: "text"
        column_name: "name"
      }
    }, Users\columns!

  it "should fail to create without required types", ->
    Posts\create_table!
    assert.has_error ->
      Posts\create {}

  describe "create", ->
    it "creates a new post", ->
      post = Posts\create {
        title: "yo"
        body: "okay!"
        user_id: db.NULL
      }

      assert.same "yo", post.title
      assert.same nil, post.user_id
      assert.same "okay!", post.body

      assert.truthy post.created_at
      assert.truthy post.updated_at
      assert.same post.updated_at, post.created_at

    it "creates a new post with custom dates", ->
      post = Posts\create {
        title: "yo"
        body: "okay!"
        user_id: db.NULL
        updated_at: "2016-6-8 20:00"
        created_at: "2016-6-8 20:00"
      }

      post\refresh!

      assert.same "2016-06-08 20:00:00", post.created_at
      assert.same "2016-06-08 20:00:00", post.updated_at

  describe "update", ->
    local post
    before_each ->
      Posts\create_table!
      post = Posts\create {
        title: "yo"
        body: "okay!"
      }

    it "does a basic update", ->
      post\update {
        title: "sure"
        user_id: 234
      }

      assert.same "sure", post.title
      assert.same 234, post.user_id
      assert.same "okay!", post.body

    it "updates timestamp", ->
      post\update {
        updated_at: "2016-6-8 20:00"
        created_at: "2016-6-8 20:00"
      }

      post\refresh!

      assert.same "2016-06-08 20:00:00", post.created_at
      assert.same "2016-06-08 20:00:00", post.updated_at

      post\update title: "yo"
      post\refresh!

      assert.not.same "2016-06-08 20:00:00", post.updated_at

    it "updates a field to null", ->
      post\update { user_id: 234 }

      assert.same 234, post.user_id

      post\update {
        user_id: db.NULL
      }

      assert.same nil, post.user_id

  describe "returning", ->
    it "should create with returning", ->
      Likes\create_table!
      like = Likes\create {
        user_id: db.raw "1 + 1"
        post_id: db.raw "2 * 2"
        count: 1
      }

      assert.same 1, like.count
      assert.same 2, like.user_id
      assert.same 4, like.post_id

    it "should create with returning all", ->
      Likes\create_table!
      like = Likes\create {
        user_id: 9
        post_id: db.raw "2 * 2"
      }, returning: "*"

      assert.same 1, like.count
      assert.same 9, like.user_id
      assert.same 4, like.post_id

    it "should create with returning specified column", ->
      Likes\create_table!
      like = Likes\create {
        user_id: 2
        post_id: db.raw "9 * 2"
      }, returning: {"count"}

      assert.same 1, like.count
      assert.same 2, like.user_id
      assert.same 18, like.post_id

    it "should create with returning null", ->
      Posts\create_table!
      post = Posts\create {
        title: db.raw "'hi'"
        body: "okay!"
        user_id: db.raw "(case when false then 1234 else null end)"
      }

      assert.same "hi", post.title
      assert.same "okay!", post.body
      assert.falsy post.user_id

    it "should update with returning", ->
      Likes\create_table!
      like = Likes\create {
        user_id: 1
        post_id: 2
        count: 1
      }

      like\update {
        count: db.raw "1 + 1"
        post_id: 123
        user_id: db.raw "(select user_id from likes where count = 1 limit 1)"
      }

      assert.same 2, like.count
      assert.same 123, like.post_id
      assert.same 1, like.user_id

    it "should update with returning null", ->
      Posts\create_table!
      post = Posts\create {
        title: "hi"
        body: "quality writing"
        user_id: 1343
      }

      post\update user_id: db.raw "(case when false then 1234 else null end)"
      assert.same nil, post.user_id

  describe "arrays", ->
    before_each ->
      HasArrays\create_table!

    it "inserts a new row", ->
      res = HasArrays\create {
        tags: db.array {"hello", "world"}
      }

      assert.same {
        id: 1
        tags: {"hello", "world"}
      }, res

    it "fetches rows with arrays", ->
      db.query "insert into #{db.escape_identifier HasArrays\table_name!}
        (tags) values ('{one,two,three}')"

      db.query "insert into #{db.escape_identifier HasArrays\table_name!}
        (tags) values ('{food,hat}')"

      assert.same {
        {id: 1, tags: {"one", "two", "three"}}
        {id: 2, tags: {"food", "hat"}}
      }, HasArrays\select "order by id asc"

    it "updates model with array", ->
      res = HasArrays\create {
        tags: db.array {"hello", "world"}
      }

      res\update tags: db.array {"yeah"}
      assert.same {"yeah"}, unpack(HasArrays\select!).tags

      table.insert res.tags, "okay"
      res\update "tags"
      assert.same {"yeah", "okay"}, unpack(HasArrays\select!).tags

