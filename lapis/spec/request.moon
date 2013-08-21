

normalize_headers = do
  normalize = (header) ->
    header\lower!\gsub "-", "_"

  (t) ->
    setmetatable {normalize(k), v for k,v in pairs t}, __index: (name) =>
      rawget @, normalize name

mock_request = (app, url, opts={}) ->
  stack = require "lapis.spec.stack"

  import parse_query_string, encode_query_string from require "lapis.util"
  import insert, concat from table

  logger = require "lapis.logging"
  old_logger = logger.request
  logger.request = ->

  -- look for existing params in url
  url_base, url_query = url\match "^(.-)%?(.*)$"
  url_base = url unless url_base

  get_params = if url_query
    parse_query_string url_query
  else {}

  -- copy in new params
  if opts.get
    for k,v in pairs opts.get
      if type(k) == "number"
        insert get_params, v
      else
        get_params[k] = v

  -- filter out extra has params
  for k,v in pairs get_params
    if type(v) == "table"
      get_params[v[1]] = nil

  url_query = encode_query_string(get_params)
  request_uri = url_base

  if url_query == ""
    url_query = nil
  else
    request_uri ..= "?" .. url_query

  host = opts.host or "localhost"
  request_method = opts.method or "GET"
  scheme = opts.scheme or "http"
  server_port = opts.port or 80


  headers = {
    Host: host
  }

  if opts.headers
    for k,v in pairs opts.headers
      headers[k] = v

  headers = normalize_headers headers
  out_headers = {}

  old_ngx = ngx
  nginx = require "lapis.nginx"
  buffer = {}

  flatten = (tbl, accum={})->
    for thing in *tbl
      if type(thing) == "table"
        flatten thing, accum
      else
        insert accum, thing

    accum

  stack.push {
    print: (...) ->
      args = flatten { ... }
      str = [tostring a for a in *args]
      insert buffer, a for a in *args
      true

    say: (...) ->
      ngx.print ...
      ngx.print "\n"

    header: out_headers

    var: setmetatable {
      :host
      :request_method
      :request_uri
      :scheme
      :server_port

      args: url_query
      query_string: url_query

      uri: url_base
    }, __index: (name) =>
      if header_name = name\match "^http_(.+)"
        return headers[header_name]

    req: {
      read_body: ->
      get_headers: -> headers
      get_uri_args: ->
        out = {}

        add_arg = (k,v) ->
          if current = out[k]
            if type(current) == "table"
              insert current, v
            else
              out[k] = {current, v}
          else
            out[k] = v

        for k,v in pairs get_params
          if type(v) == "table"
            add_arg unpack v
          else
            add_arg k, v

        out

      get_post_args: ->
        opts.post or {}
    }
  }


  response = nginx.dispatch app
  stack.pop!

  logger.request = old_logger
  response.status or 200, concat(buffer), out_headers

{ :mock_request, :normalize_headers }
