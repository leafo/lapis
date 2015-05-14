db = require "lapis.db.mysql"

import setup_db, teardown_db from require "spec_mysql.helpers"
import drop_tables from require "lapis.spec.db"

import Model, enum from require "lapis.db.mysql.model"
import types, create_table from require "lapis.db.mysql.schema"

class Users extends Model
  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.id}
      {"name", types.text}
    }

class Posts extends Model
  @timestamp: true

  @create_table: =>
    drop_tables @
    create_table @table_name!, {
      {"id", types.id}
      {"user_id", types.integer null: true}
      {"title", types.text null: false}
      {"body", types.text null: false}
      {"created_at", types.datetime}
      {"updated_at", types.datetime}
    }

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
      {"user_id", types.integer}
      {"post_id", types.integer}
      {"count", types.integer}
      {"created_at", types.datetime}
      {"updated_at", types.datetime}

      "PRIMARY KEY (user_id, post_id)"
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

