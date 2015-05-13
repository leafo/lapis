import NginxRunner from require "lapis.cmd.nginx"
runner = NginxRunner base_path: "spec_openresty/s1/"

import SpecServer from require "lapis.spec.server"
server = SpecServer runner

describe "server", ->
  setup ->
    server\load_test_server!

  teardown ->
    server\close_test_server!

  it "should request basic page", ->
    status, res = server\request "/"
    assert.same 200, status

  it "should request json page", ->
    status, res = server\request "/world", {
      expect: "json"
    }

    assert.same 200, status
    assert.same { success: true }, res

