
import NginxRunner from require "lapis.cmd.nginx"
runner = NginxRunner base_path: "spec_openresty/s2/"

import SpecServer from require "lapis.spec.server"
server = SpecServer runner

import Users, Posts, Likes from require "spec_mysql.models"

import setup_db, teardown_db from require "spec_mysql.helpers"

describe "resty", ->
  setup ->
    setup_db!

    Users\create_table!
    Posts\create_table!
    Likes\create_table!

    server\load_test_server!

  teardown ->
    server\close_test_server!
    teardown_db!

  it "should run a query", ->
    status, res = server\request "/", expect: "json"

    assert.same {
      {
        "Tables_in_lapis_test (users)": "users"
      }
    }, res

  describe "model specs", ->
    request = (path) ->
      it "should request `#{path}`", ->
        status, res = server\request path, expect: "json"
        assert.same 200, status
        assert.truthy res.success

    request "/basic-model/create"
    request "/basic-model/find"
    request "/basic-model/select"
    request "/primary-key/create"
    request "/primary-key/delete"
    request "/primary-key/update"

  it "runs migrations", ->
    status, res = server\request "/migrations", expect: "json"
    assert.same 200, status

