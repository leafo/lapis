
logger = require "lapis.logging"

import Router from require "lapis.router"
import html_writer from require "lapis.html"

set_and_truthy = (val, default=true) ->
  return default if val == nil
  val

class Request
  new: (@app, @req, @res) =>
    @buffer = {} -- output buffer
    @params = {}
    @options = {}

  add_params: (params, name) =>
    self[name] = params
    for k,v in pairs params
      @params[k] = v

  -- render the request into the response
  -- do this last
  render: =>
    if not @res.headers["Content-type"]
      @res.headers["Content-type"] = "text/html"

    if @app.layout and set_and_truthy(@options.layout, true)
      inner = @buffer
      @buffer = {}
      layout = @app.layout inner: -> raw inner
      layout\render @buffer

    if next @buffer
      content = table.concat @buffer
      @res.content = if @res.content
        @res.content .. content
      else
        content

  html: (fn) => html_writer fn

  url_for: (...) => @app.router\url_for ...

  write: (thing) =>
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

  _debug: =>
    @buffer = {
      "<html>", "req:", "<pre>"
      moon.dump @req
      "</pre>", "res:", "<pre>"
      moon.dump @res
      "</pre>", "</html>"
    }


class Application
  layout: require"lapis.layout".Default

  new: =>
    @router = Router!

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

        \write handler r

  dispatch: (req, res) =>
    r = Request self, req, res
    @router\resolve req.parsed_url.path, r
    r\render!
    logger.request r
    res

  serve: => -- TODO: alias to lapis.serve


{ :Request, :Application }

