
TEST_ENV = "test"

import normalize_headers from require "lapis.spec.request"
ltn12 = require "ltn12"
json = require "cjson"

server_loaded = 0
server_port = nil

load_test_server = ->
  server_loaded += 1
  return unless server_loaded == 1

  import push_server from require "lapis.cmd.nginx"
  server = assert push_server(TEST_ENV), "Failed to start test server"
  server_port = server.port

-- TODO: if _TEST (inside of busted) keep the server running?
close_test_server = ->
  server_loaded -= 1
  return unless server_loaded == 0
  import pop_server from require "lapis.cmd.nginx"
  pop_server!

-- hits the server in test environment
request = (url) ->
  error "The test server is not loaded!" unless server_loaded > 0
  http = require "socket.http"

  buffer = {}
  res, status, headers = http.request {
    url: "http://127.0.0.1:#{server_port}/#{url or ""}"
    redirect: false
    sink: ltn12.sink.table buffer
  }

  table.concat(buffer), status, normalize_headers(headers)

run_on_server = (fn) ->
  import execute_on_server from require "lapis.cmd.nginx"
  encoded = "%q"\format string.dump(fn)
  execute_on_server "
    local json = require 'cjson'
    local fn = loadstring(#{encoded})
    ngx.print(json.encode({fn()}))
  ", TEST_ENV

{
  :load_test_server
  :close_test_server
  :request
  :run_on_server
}

