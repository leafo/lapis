lapis = require "lapis"
db = require "lapis.db"

import Users, Posts, Likes from require "spec_mysql.models"

assert = require "luassert"

assert_same_rows = (a, b) ->
  a = {k,v for k,v in pairs a}
  b = {k,v for k,v in pairs b}

  a.created_at = nil
  a.updated_at = nil

  b.created_at = nil
  b.updated_at = nil

  assert.same a, b

class extends lapis.Application
  @before_filter ->
    Users\truncate!
    Posts\truncate!
    Likes\truncate!

  "/": =>
    json: db.query "show tables like ?", "users"

  "/migrations": =>
    import create_table, types from require "lapis.db.mysql.schema"

    require("lapis.db.migrations").run_migrations {
      =>
        create_table "migrated_table", {
          {"id", types.id}
          {"name", types.varchar}
        }
    }

    json: { success: true }

  "/basic-model/create": =>
    first = Users\create { name: "first" }
    second = Users\create { name: "second" }

    assert.truthy first.id
    assert.same "first", first.name

    assert.same first.id + 1, second.id
    assert.same "second", second.name

    -- TODO: looks like resty-mysql returns strings for count rows
    assert.same "2", Users\count!

    json: { success: true }

  "/basic-model/find": =>
    first = Users\create { name: "first" }
    second = Users\create { name: "second" }

    assert.same "2", Users\count!

    assert.same first, Users\find first.id
    assert.same second, Users\find second.id
    assert.same second, Users\find name: "second"

    assert.falsy Users\find name: "second", id: first.id
    assert.same first, Users\find id: "#{first.id}"

    json: { success: true }

  "/basic-model/select": =>
    first = Users\create { name: "first" }
    second = Users\create { name: "second" }

    things = Users\select!
    assert.same 2, #things

    things = Users\select "order by name desc"
    assert "second", things[1].name
    assert "first", things[2].name

    things = Users\select "order by id asc", fields: "id"
    assert.same {{id: first.id}, {id: second.id}}, things

    things = Users\find_all {first.id, second.id + 22}
    assert.same {first}, things

    things = Users\find_all {first.id,second.id}, where: {
      name: "second"
    }

    assert.same {second}, things

    json: { success: true }

  "/primary-key/create": =>
    like = Likes\create {
      user_id: 40
      post_id: 22
      count: 1
    }

    assert.same 40, like.user_id
    assert.same 22, like.post_id

    assert.truthy like.created_at
    assert.truthy like.updated_at

    assert.same like, Likes\find 40, 22

    json: { success: true }

  "/primary-key/delete": =>
    like = Likes\create {
      user_id: 1
      post_id: 2
      count: 1
    }

    other_like = Likes\create {
      user_id: 4
      post_id: 6
      count: 2
    }

    like\delete!

    assert.has_error ->
      like\refresh!

    remaining = Likes\select!
    assert.same 1, #remaining
    assert_same_rows other_like, remaining[1]

    json: { success: true }

  "/primary-key/update": =>
    like = Likes\create {
      user_id: 1
      post_id: 2
      count: 1
    }

    other_like = Likes\create {
      user_id: 4
      post_id: 6
      count: 2
    }

    like\update {
      count: 5
    }

    assert.same 5, like.count

    assert_same_rows like, Likes\find(like.user_id, like.post_id)
    assert_same_rows other_like, Likes\find(other_like.user_id, other_like.post_id)

    json: { success: true }
