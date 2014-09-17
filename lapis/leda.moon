import escape_pattern, parse_content_disposition, build_url, parse_query_string from require "lapis.util"

local parse_url
local parse_query
local http

pcall ->
  import parseUrl, parseQuery from require 'leda.util'
  parse_url = parseUrl
  parse_query = parseQuery

  http = require 'leda.server.http'

flatten_params = (t) ->
  {k, type(v) == "table" and v[#v] or v for k,v in pairs t}

request = {
  headers: -> __leda.request\headers!
  cmd_mth: -> __leda.request\method!
  cmd_url: ->  __leda.request\url!
  relpath: (t) -> t.parsed_url.path
  scheme: (t)-> t.parsed_url.scheme
  port: (t) -> t.parsed_url.port
  srv: (t) -> t.parsed_url.host
  remote_addr: -> __leda.request\address!
  referer: ->  ""
  body: -> __leda.request\body!

  parsed_url: (t) ->
    host = t.headers.host
    parsed = parse_url(t.cmd_url)
    if host
      parsed_host = parse_url(host)
      parsed.host = parsed_host.host
      parsed.port = parsed_host.port

    parsed

  built_url: (t) ->
    build_url t.parsed_url

  params_post: (t) ->
    -- parse multipart if required
    if (t.headers["content-type"] or "")\match escape_pattern "x-www-form-urlencoded"
      flatten_params parse_query(t.body or "") or {}
    else
      flatten_params {}

  params_get: (t) ->
    flatten_params t.parsed_url.params
}

lazy_tbl = (tbl, index) ->
  setmetatable tbl, {
    __index: (key) =>
      fn = index[key]
      if fn
        with res = fn @
          @[key] = res
  }


build_request = (unlazy=false) ->
  with t = lazy_tbl {}, request
    if unlazy
      for k in pairs request
        t[k]

build_response = ->
  {
    req: build_request!
    add_header: (k, v) =>
      old = @headers[k]
      switch type old
        when "nil"
          @headers[k] = v
        when "table"
          old[#old + 1] = v
          @headers[k] = old
        else
          @headers[k] = {old, v}

     headers: {}
  }

request_callback = (app, request, response)  ->
  __leda.request = request
  __leda.response = response

  res = build_response!

  app\dispatch res.req, res

  if res.status
    response.status = res.status

  if next(res.headers)
     response.headers = res.headers

  response.body = res.content or ""
  response\send!

dispatch = (app) ->
  config = require("lapis.config")
  server = http(config.get!.port, config.get!.host or 'localhost')
  server.request = (server, response, request) ->
    request_callback(app, response, request)

{ :build_request, :build_response, :dispatch }