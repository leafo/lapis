import NginxRunner from require "lapis.cmd.nginx"
runner = NginxRunner base_path: "spec_openresty/s1/"

import SpecServer from require "lapis.spec.server"
server = SpecServer runner

describe "server", ->
  before_each ->

  setup ->
    server\load_test_server!

  teardown ->
    server\close_test_server!

  it "should launch a server..", ->
    status, res = server\request "/"
    assert.same 200, status

