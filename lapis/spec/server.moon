
TEST_ENV = "test"

import normalize_headers from require "lapis.spec.request"
ltn12 = require "ltn12"
json = require "cjson"

server_loaded = 0
current_server = nil

load_test_server = ->
  server_loaded += 1
  return unless server_loaded == 1

  import attach_server from require "lapis.cmd.nginx"
  import get_free_port from require "lapis.cmd.util"

  port = get_free_port!
  current_server = attach_server TEST_ENV, { :port }
  current_server.app_port = port
  current_server

-- TODO: if _TEST (inside of busted) keep the server running?
close_test_server = ->
  server_loaded -= 1
  return unless server_loaded == 0
  current_server\detach!
  current_server = nil

-- hits the server in test environment
request = (url, opts={}) ->
  error "The test server is not loaded!" unless server_loaded > 0
  http = require "socket.http"

  headers = {}
  method = opts.method

  source = if data = opts.post or opts.data
    method or= "POST" if opts.post

    if type(data) == "table"
      import encode_query_string from require "lapis.util"
      headers["Content-type"] = "application/x-www-form-urlencoded"
      data = encode_query_string data

    headers["Content-length"] = #data
    ltn12.source.string(data)

  buffer = {}
  res, status, headers = http.request {
    url: "http://127.0.0.1:#{current_server.app_port}/#{url or ""}"
    redirect: false
    sink: ltn12.sink.table buffer
    :headers, :method, :source
  }

  assert res, status
  status, table.concat(buffer), normalize_headers(headers)

{
  :load_test_server
  :close_test_server
  :request
  :run_on_server
}

