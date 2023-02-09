unpack = unpack or table.unpack

normalize_headers = do
  normalize = (header) ->
    header\lower!\gsub "-", "_"

  (t) ->
    setmetatable {normalize(k), v for k,v in pairs t}, __index: (name) =>
      rawget @, normalize name

-- append a cookie to the input headers
add_cookie = (headers, name, val) ->
  import escape from require "lapis.util"
  assign = "#{escape name}=#{escape val}"

  if old = headers.Cookie
    headers.Cookie = "#{old}; #{assign}"
  else
    headers.Cookie = assign

-- extract the cookies from set_cookie response headers
extract_cookies = (response_headers) ->
  set_cookies = response_headers.set_cookie
  return unless set_cookies

  if type(set_cookies) == "string"
    set_cookies = { set_cookies }

  parsed_cookies = {}

  for cookie_header in *set_cookies
    import parse_cookie_string from require "lapis.util"
    tmp = parse_cookie_string cookie_header
    set_name = cookie_header\match "[^=]+"
    parsed_cookies[set_name] = tmp[set_name]


  parsed_cookies


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
  -- TODO: rename this to query (for query params), also support old syntax
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

  if opts.cookies
    for k, v in pairs opts.cookies
      add_cookie headers, k, v

  if opts.post
    headers["Content-type"] = "application/x-www-form-urlencoded"

  if opts.session
    config = require("lapis.config").get!
    import encode_session from require "lapis.session"
    add_cookie headers, config.session_name, encode_session opts.session

  if opts.headers
    for k,v in pairs opts.headers
      headers[k] = v

  headers = normalize_headers headers
  out_headers = {}

  nginx = require "lapis.nginx"
  buffer = {}

  flatten = (tbl, accum={})->
    for thing in *tbl
      if type(thing) == "table"
        flatten thing, accum
      else
        insert accum, thing

    accum

  hex = (str)->
    (str\gsub ".", (c) -> string.format "%02x", string.byte c)

  stack.push {
    print: (...) ->
      args = flatten { ... }
      str = [tostring a for a in *args]
      insert buffer, a for a in *args
      true

    say: (...) ->
      ngx.print ...
      ngx.print "\n"

    md5: (str) ->
      digest = require "openssl.digest"
      hex((digest.new "md5")\final str)

    header: out_headers

    now: -> os.time! -- note that the resolution here does not match what nginx generates

    update_time: -> os.time!
    time: -> os.time!

    -- This is a bit hacky: We use the init phase to force pgmoon to default to
    -- using luasocket for the nginx socket, as we don't support the full
    -- cosocket protocol here. This should otherwise have no effect on your app
    get_phase: -> "init"

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
      get_body_data: -> opts.body or opts.post and encode_query_string(opts.post) or nil
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
        if opts.post
          return opts.post

        if opts.body and headers["Content-type"] == "application/x-www-form-urlencoded"
          if args = parse_query_string(opts.body)
            return {k,v for k,v in pairs args when type(k) == "string"}

        {}

    }

    -- we can't suppor this api so we just return blank responses
    location: {
      capture: -> { status: 200, header: {}, body: "" }
      capture_multi: (args) ->
        [{ status: 200, header: {}, body: "" } for i=1,#args]
    }
  }

  -- if app is already an instance just use it
  app = app_cls.__base and app_cls! or app_cls
  unless app.router
    app\build_router!

  response = nginx.dispatch app

  stack.pop!

  logger.request = old_logger
  out_headers = normalize_headers out_headers

  body = concat(buffer)

  unless opts.allow_error
    if error_blob = out_headers.x_lapis_error
      json = require "cjson"
      {:summary, :err, :trace} = json.decode error_blob
      error "\n#{summary}\n#{err}\n#{trace}"

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

-- creates a reuest object and returns it
stub_request = (app_cls, url="/", opts={}) ->
  local stub

  app = app_cls!
  app.dispatch = (req, res) =>
    stub = @.Request @, req, res

  mock_request app, url, opts
  stub

{ :mock_request, :assert_request, :normalize_headers, :mock_action, :stub_request, :extract_cookies }
