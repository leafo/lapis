
logger = require "lapis.logging"
url = require "socket.url"
json = require "cjson"
session = require "lapis.session"

import Router from require "lapis.router"
import html_writer from require "lapis.html"

import parse_cookie_string from require "lapis.util"

set_and_truthy = (val, default=true) ->
  return default if val == nil
  val

auto_table = (fn) ->
  setmetatable {}, __index: (name) =>
    result = fn!
    setmetatable @, __index: result
    result[name]

class Request
  new: (@app, @req, @res) =>
    @buffer = {} -- output buffer
    @params = {}
    @options = {}

    @cookies = auto_table -> parse_cookie_string @req.headers.cookie
    @session = auto_table -> session.get_session self

  add_params: (params, name) =>
    self[name] = params
    for k,v in pairs params
      @params[k] = v

  -- render the request into the response
  -- do this last
  render: (opts=false) =>
    @options = opts if opts

    if @options.json
      @res.headers["Content-type"] = "application/json"
      @res.content = json.encode @options.json
      return

    if not @res.headers["Content-type"]
      @res.headers["Content-type"] = "text/html"

    if @options.redirect_to
      @res\add_header "Location", @build_url @options.redirect_to
      @res.status = 302

    if @options.status
      @res.status = @options.status

    session.write_session @
    @write_cookies!

    if rpath = @options.render
      rpath = @route_name if rpath == true
      widget = require "#{@app.views_prefix}.#{rpath}"

      view = widget @options.locals
      view\include_helper @

      @write view

    if @app.layout and set_and_truthy(@options.layout, true)
      inner = @buffer
      @buffer = {}
      layout = @app.layout inner: -> raw inner
      layout\include_helper @
      layout\render @buffer

    if next @buffer
      content = table.concat @buffer
      @res.content = if @res.content
        @res.content .. content
      else
        content

  html: (fn) => html_writer fn

  url_for: (...) => @app.router\url_for ...

  build_url: (path, options) =>
    parsed = { k,v for k,v in pairs @req.parsed_url }
    parsed.authority = nil

    if path and not path\match "^/"
      path = "/#{path}"

    parsed.path = path

    if parsed.port == "80"
      parsed.port = nil

    if options
      for k,v in pairs options
        parsed[k] = v

    url.build parsed

  write: (...) =>
    for thing in *{...}
      t = type(thing)
      -- is it callable?
      if t == "table"
        mt = getmetatable(thing)
        if mt and mt.__call
          t = "function"

      switch t
        when "string"
          table.insert @buffer, thing
        when "table"
          -- see if there are options
          for k,v in pairs thing
            if type(k) == "string"
              @options[k] = v
            else
              @write v
        when "function"
          @write thing @buffer
        when "nil"
          nil -- ignore
        else
          error "Don't know how to write:", tostring(thing)

  -- TODO: cookie paramaters
  write_cookies: =>
    parts = for k,v in pairs @cookies
      "#{url.escape k}=#{url.escape v}"

    @res\add_header "Set-cookie", table.concat parts, "; "

  _debug: =>
    @buffer = {
      "<html>", "req:", "<pre>"
      moon.dump @req
      "</pre>", "res:", "<pre>"
      moon.dump @res
      "</pre>", "</html>"
    }


class Application
  layout: require"lapis.views.layout"
  error_page: require"lapis.views.error"

  views_prefix: "views"

  before_filters: {}

  new: =>
    @router = Router!
    @router.default_route = => false

    with require "lapis.server"
      -- add static route
      @@__base["/static/*"] = .make_static_handler "static"
      @@__base["/favicon.ico"] = .serve_from_static!

    for path, handler in pairs @@__base
      t = type path
      if t == "table" or t == "string" and path\match "^/"
        @router\add_route path, @wrap_handler handler

  wrap_handler: (handler) =>
    (params, path, name, r) ->
      with r
        .route_name = name

        \add_params r.req.params_get, "GET"
        \add_params r.req.params_post, "POST"
        \add_params params, "url_params"

        for filter in *@before_filters
          filter r

        \write handler r

  dispatch: (req, res) =>
    local err, trace
    success = xpcall (->
        r = Request self, req, res

        unless @router\resolve req.parsed_url.path, r
          -- run default route if nothing matched
          handler = @wrap_handler self.default_route
          r\write handler {}, nil, "default_route", r

        r\render!
        logger.request r),
      (_err) ->
        err = _err
        trace = debug.traceback "", 2

    unless success
      r = Request self, req, res
      r\write {
        status: 500
        layout: false
        self.error_page { staus: 500, :err, :trace }
      }
      r\render!
      logger.request r

    res

  serve: => -- TODO: alias to lapis.serve

  default_route: =>
    -- strip trailing /
    if @req.cmd_url\match "./$"
      stripped = @req.cmd_url\match "^(.+)/+$"
      redirect_to: stripped, status: 301
    else
      error "Failed to find route: #{@req.cmd_url}"

  @before_filter: (fn) =>
    table.insert @before_filters, fn

respond_to = (tbl) ->
  =>
    fn = tbl[@req.cmd_mth]
    if fn
      if before = tbl.before
        before @
      fn @
    else
      error "don't know how to respond to #{@req.cmd_mth}"

capture_errors = (fn) ->
  (...) =>
    co = coroutine.create fn
    out = { coroutine.resume co }

    unless out[1]
      error debug.traceback co, out[2]

    if coroutine.status(co) == "suspended"
      @errors = { unpack out, 2 }
      render: true
    else
      unpack out, 2

assert_error = (thing, msg) ->
  unless thing
    coroutine.yield msg
  thing

yield_error = (msg) ->
  coroutine.yield msg

{
  :Request, :Application, :respond_to, :capture_errors, :assert_error
  :yield_error
}

