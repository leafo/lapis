db = require "lapis.db.mysql"

import setup_db, teardown_db from require "spec_mysql.helpers"
import Users, Posts, Likes from require "spec_mysql.models"

import configure_mysql, bind_query_log from require "spec_mysql.helpers"

describe "lapis.db.mysql.model", ->
  configure_mysql!

  local query_log
  bind_query_log -> query_log

  before_each ->
    query_log = {}

  describe "core model", ->
    build = require "spec.core_model_specs"
    build { :Users, :Posts, :Likes }

  it "Model:columns", ->
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

