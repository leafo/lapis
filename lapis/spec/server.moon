
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
  current_server = attach_server TEST_ENV

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
  server_port = require("lapis.config").get(TEST_ENV).port

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
    url: "http://127.0.0.1:#{server_port}/#{url or ""}"
    redirect: false
    sink: ltn12.sink.table buffer
    :headers, :method, :source
  }

  table.concat(buffer), status, normalize_headers(headers)

run_on_server = (fn) ->
  error "not anymore"
  import execute_on_server from require "lapis.cmd.nginx"
  encoded = "%q"\format string.dump(fn)
  res, code, headers = execute_on_server "
    local logger = require 'lapis.logging'
    local json = require 'cjson'

    local queries = {}

    local old_log = logger.query
    logger.query = function(q)
      local old_print = print
      print = function(...)
        local buff = {...}
        io.stdout:write(table.concat(buff, '\\t') .. '\\n')
      end
      old_log(q)
      print = old_print
      table.insert(queries, q)
    end

    local fn = loadstring(#{encoded})
    local res = {fn()}
    ngx.header.x_queries = json.encode(queries)
    ngx.print(json.encode(res))
  ", TEST_ENV

  if code != 200
    error res

  unpack json.decode res

{
  :load_test_server
  :close_test_server
  :request
  :run_on_server
}

