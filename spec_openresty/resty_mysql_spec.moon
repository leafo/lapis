
import NginxRunner from require "lapis.cmd.nginx"
runner = NginxRunner base_path: "spec_openresty/s2/"

import SpecServer from require "lapis.spec.server"
server = SpecServer runner

describe "resty", ->
  setup ->
    server\load_test_server!

  teardown ->
    server\close_test_server!

  it "should request basic page", ->
    status, res = server\request "/", {
      -- expect: "json"
    }
    error res

