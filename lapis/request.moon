
url = require "socket.url"

lapis_config = require "lapis.config"
session = require "lapis.session"

import html_writer from require "lapis.html"
import increment_perf from require "lapis.nginx.context"
import parse_cookie_string, to_json, build_url, auto_table from require "lapis.util"

import insert from table

class Request
  @__inherited: (child) =>
    -- add inheritance to support methods
    if support = rawget child, "support"
      return if getmetatable support
      setmetatable support, {
        __index: @support
      }

  -- these are like methods but we don't put them on the request object so they
  -- don't take up names that someone might use
  @support: {
    load_cookies: =>
      @cookies = auto_table -> parse_cookie_string @req.headers.cookie

    load_session: =>
      @session = session.lazy_session @

    -- write what is in @options and @buffer into the output
    -- this is called once, and done last
    render: =>
      @@support.write_session @
      @@support.write_cookies @

      if @options.status
        @res.status = @options.status

      if @options.headers
        for k,v in pairs @options.headers
          @res\add_header k, v

      if obj = @options.json
        @res.headers["Content-Type"] = "application/json"
        @res.content = to_json obj
        return

      if ct = @options.content_type
        @res.headers["Content-Type"] = ct

      if not @res.headers["Content-Type"]
        @res.headers["Content-Type"] = "text/html"

      if redirect_url = @options.redirect_to
        if redirect_url\match "^/"
          redirect_url  = @build_url redirect_url

        @res\add_header "Location", redirect_url
        @res.status or= 302
        return

      layout = if @options.layout != nil
        @options.layout
      else
        @app.layout

      @layout_opts = if layout
        { _content_for_inner: nil }

      widget = @options.render
      widget = @route_name if widget == true

      config = lapis_config.get!

      if widget
        if type(widget) == "string"
          widget = require "#{@app.views_prefix}.#{widget}"

        start_time = if config.measure_performance
          ngx.update_time!
          ngx.now!

        view = widget @options.locals
        @layout_opts.view_widget = view if @layout_opts
        view\include_helper @
        @write view

        if start_time
          ngx.update_time!
          increment_perf "view_time", ngx.now! - start_time

      if layout
        inner = @buffer
        @buffer = {}

        layout_cls = if type(layout) == "string"
          require "#{@app.views_prefix}.#{layout}"
        else
          layout

        start_time = if config.measure_performance
          ngx.update_time!
          ngx.now!

        @layout_opts._content_for_inner or= -> raw inner

        layout = layout_cls @layout_opts
        layout\include_helper @
        layout\render @buffer

        if start_time
          ngx.update_time!
          increment_perf "layout_time", ngx.now! - start_time

      if next @buffer
        content = table.concat @buffer
        @res.content = if @res.content
          @res.content .. content
        else
          content

    write_session: session.write_session

    write_cookies: =>
      return unless next @cookies

      for k,v in pairs @cookies
        cookie = "#{url.escape k}=#{url.escape v}"
        if extra = @app.cookie_attributes @, k, v
          cookie ..= "; " .. extra

        @res\add_header "Set-Cookie", cookie

    add_params: (params, name) =>
      @[name] = params
      for k,v in pairs params
        -- expand nested[param][keys]
        front = k\match "^([^%[]+)%[" if type(k) == "string"
        if front
          curr = @params
          for match in k\gmatch "%[(.-)%]"
            new = curr[front]
            if new == nil
              new = {}
              curr[front] = new
            curr = new
            front = match
          curr[front] = v
        else
          @params[k] = v
  }

  new: (@app, @req, @res) =>
    @buffer = {} -- output buffer
    @params = {}
    @options = {}

    @@support.load_cookies @
    @@support.load_session @

  flow: (flow) =>
    key = "_flow_#{flow}"

    unless @[key]
      @[key] = require("#{@app.flows_prefix}.#{flow}") @

    @[key]

  html: (fn) => html_writer fn

  url_for: (first, ...) =>
    if type(first) == "table"
      @app.router\url_for first\url_params @, ...
    else
      @app.router\url_for first, ...

  -- @build_url! --> http://example.com:8080
  -- @build_url "hello_world" --> http://example.com:8080/hello_world
  -- @build_url "hello_world?color=blue" --> http://example.com:8080/hello_world?color=blue
  -- @build_url "cats", host: "leafo.net", port: 2000 --> http://leafo.net:2000/cats
  -- Where example.com is the host of the request, and 8080 is current port
  build_url: (path, options) =>
    return path if path and (path\match("^%a+:") or path\match "^//")

    parsed = { k,v for k,v in pairs @req.parsed_url }
    parsed.query = nil

    if path
      _path, query = path\match("^(.-)%?(.*)$")
      path = _path or path
      parsed.query = query

    parsed.path = path

    scheme = parsed.scheme or "http"

    if scheme == "http" and (parsed.port == "80" or parsed.port == 80)
      parsed.port = nil

    if scheme == "https" and (parsed.port == "443" or parsed.port == 443)
      parsed.port = nil

    if options
      for k,v in pairs options
        parsed[k] = v

    build_url parsed

  write: (thing, ...) =>
    t = type(thing)
    -- is it callable?
    if t == "table"
      mt = getmetatable(thing)
      if mt and mt.__call
        t = "function"

    switch t
      when "string"
        insert @buffer, thing
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
        error "Don't know how to write: (#{t}) #{thing}"

    @write ... if ...

