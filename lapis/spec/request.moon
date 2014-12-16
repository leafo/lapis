
env = require "lapis.environment"

normalize_headers = do
  normalize = (header) ->
    header\lower!\gsub "-", "_"

  (t) ->
    setmetatable {normalize(k), v for k,v in pairs t}, __index: (name) =>
      rawget @, normalize name

-- returns the result of request using app
-- mock_request App, "/hello"
-- mock_request App, "/hello", { host: "leafo.net" }
mock_request = (app_cls, url, opts={}) ->
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
  request_method = opts.method or (opts.post and "POST") or "GET"
  scheme = opts.scheme or "http"
  server_port = opts.port or 80

  http_host = host
  unless server_port == 80
    http_host ..= ":#{server_port}"

  prev_request = normalize_headers(opts.prev or {})

  headers = {
    Host: host
    Cookie: prev_request.set_cookie
  }

  if opts.post
    headers["Content-type"] = "application/x-www-form-urlencoded"

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

    now: -> os.time!
    update_time: => os.time!

    ctx: { }

    var: setmetatable {
      :host
      :http_host
      :request_method
      :request_uri
      :scheme
      :server_port

      args: url_query
      query_string: url_query
      remote_addr: "127.0.0.1"

      uri: url_base
    }, __index: (name) =>
      if header_name = name\match "^http_(.+)"
        return headers[header_name]

    req: {
      read_body: ->
      get_body_data: -> opts.body or encode_query_string opts.post
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

  -- if app is already an instance just use it
  app = app_cls.__base and app_cls! or app_cls
  unless app.router
    app\build_router!

  env.push "test"

  response = nginx.dispatch app

  env.pop!
  stack.pop!

  logger.request = old_logger
  out_headers = normalize_headers out_headers

  body = concat(buffer)

  if out_headers.x_lapis_error
    json = require "cjson"
    {:status, :err, :trace} = json.decode body
    error "\n#{status}\n#{err}\n#{trace}"

  if opts.expect == "json"
    json = require "cjson"
    unless pcall -> body = json.decode body
      error "expected to get json from #{url}"

  response.status or 200, body, out_headers

assert_request = (...) ->
  res = {mock_request ...}

  if res[1] == 500
    assert false, "Request failed: " .. res[2]

  unpack res

-- returns the result of running fn in the context of a mocked request
-- mock_action App, -> "hello"
-- mock_action App, "/path", -> "hello"
-- mock_action App, "/path", { host: "leafo.net"}, -> "hello"
mock_action = (app_cls, url, opts, fn) ->
  if type(url) == "function" and opts == nil
    fn = url
    url = "/"
    opts = {}

  if type(opts) == "function" and fn == nil
    fn = opts
    opts = {}

  local ret
  handler = (...) ->
    ret = { fn ... }
    layout: false

  class A extends app_cls
    "/*": handler
    "/": handler

  assert_request A, url, opts
  unpack ret

stub_request = (app_cls, url="/", opts={}) ->
  local stub

  class App extends app_cls
    dispatch: (req, res) =>
      stub = @.Request @, req, res

  mock_request App, url, opts
  stub

{ :mock_request, :assert_request, :normalize_headers, :mock_action, :stub_request }
