db = require "lapis.db.mysql"

import setup_db, teardown_db from require "spec_mysql.helpers"
import Users, Posts, Likes from require "spec_mysql.models"

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

