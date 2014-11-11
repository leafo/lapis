
TEST_ENV = "test"

import normalize_headers from require "lapis.spec.request"
ltn12 = require "ltn12"
json = require "cjson"

import parse_query_string, encode_query_string from require "lapis.util"

current_server = nil

load_test_server = ->
  import attach_server from require "lapis.cmd.nginx"
  import get_free_port from require "lapis.cmd.util"

  app_port = get_free_port!

  current_server = attach_server TEST_ENV, { port: app_port }
  current_server.app_port = app_port
  current_server

close_test_server = ->
  import detach_server from require "lapis.cmd.nginx"
  detach_server!

  current_server = nil

get_current_server = ->
  current_server

-- hits the server in test environment
request = (path="", opts={}) ->
  unless current_server
    error "The test server is not loaded! (did you forget to load_test_server?)"

  http = require "socket.http"

  headers = {}
  method = opts.method
  port = opts.port or current_server.app_port

  source = if data = opts.post or opts.data
    method or= "POST" if opts.post

    if type(data) == "table"
      headers["Content-type"] = "application/x-www-form-urlencoded"
      data = encode_query_string data

    headers["Content-length"] = #data
    ltn12.source.string(data)

  -- if the path is a url then extract host and path
  url_host, url_path = path\match "^https?://([^/]+)(.*)$"
  if url_host
    headers.Host = url_host
    path = url_path
    if override_port = url_host\match ":(%d+)$"
      port = override_port

  path = path\gsub "^/", ""

  -- merge get parameters
  if opts.get
    url_base, url_query = path\match "^(.-)%?(.*)$"
    get_params = if url_query
      parse_query_string url_query
    else
      {}

    for k,v in pairs opts.get
      get_params[k] = v

    path = path\gsub("^.-(%?.*)$", "") .. "?" .. encode_query_string get_params

  if opts.headers
    for k,v in pairs opts.headers
      headers[k] = v

  buffer = {}
  res, status, headers = http.request {
    url: "http://127.0.0.1:#{port}/#{path}"
    redirect: false
    sink: ltn12.sink.table buffer
    :headers, :method, :source
  }

  assert res, status
  body = table.concat buffer

  headers = normalize_headers headers
  if headers.x_lapis_error
    json = require "cjson"
    {:status, :err, :trace} = json.decode body
    error "\n#{status}\n#{err}\n#{trace}"

  if opts.expect == "json"
    json = require "cjson"
    unless pcall -> body = json.decode body
      error "expected to get json from #{path}"

  status, body, headers

{
  :load_test_server
  :close_test_server
  :get_current_server
  :request
  :run_on_server
}

