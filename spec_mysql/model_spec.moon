db = require "lapis.db.mysql"

import setup_db, teardown_db from require "spec_mysql.helpers"
import Users, Posts, Images, Likes from require "spec_mysql.models"

describe "model", ->
  setup ->
    setup_db!

  teardown ->
    teardown_db!

  describe "core model", ->
    build = require "spec.core_model_specs"
    build { :Users, :Posts, :Images, :Likes }

  it "should get columns of model", ->
    Users\create_table!
    assert.same {
      {
        "Extra": "auto_increment"
        "Field": "id"
        "Key": "PRI"
        "Null": "NO"
        "Type": "int(11)"
      }
      {
        "Extra": ""
        "Field": "name"
        "Key": ""
        "Null": "NO"
        "Type": "text"
      }
    }, Users\columns!


  it "should create empty row", ->
    Posts\create_table!
    -- this fails in postgres, but mysql gives default values
    Posts\create {}

  describe "with compound auto_increment", ->
    Users\create_table!
    Posts\create_table!
    Images\create_table!

    user1 = Users\create { name: "bob" }
    post1 = Posts\create { user_id: user1.user_id }
    post2 = Posts\create { user_id: user1.user_id }

    first = Images\create {
      user_id: user1.id
      post_id: post1.id
      url: "first"
    }
    second = Images\create {
      user_id: user1.id
      post_id: post1.id
      url: "second"
    }
    third = Images\create {
      user_id: user1.id
      post_id: post2.id
      url: "third"
    }

    it "should increment keys", ->
      assert.truthy first.id < second.id
      assert.truthy second.id < third.id

    it "should find entites", ->
      assert.same first, Images\find post1.id, first.id
      assert.same {first, second}, Images\find_all {post1.id}, "post_id"
      assert.same {third}, Images\find_all {post2.id}, "post_id"

    it "should allow relations", ->
      package.loaded.models = {
        :Users, :Posts, :Images, :Likes
      }

      assert.same user1, first\get_user!
      assert.same post1, first\get_post!
      assert.same post2, third\get_post!

      assert.same {first.id, second.id}, [v.id for v in *post1\get_images!]
      assert.same {third.id}, [v.id for v in *post2\get_images!]
