url = require "socket.url"

lapis_config = require "lapis.config"
session = require "lapis.session"

import html_writer from require "lapis.html"
import increment_perf from require "lapis.nginx.context"
import parse_cookie_string, to_json, build_url, auto_table from require "lapis.util"

import insert from table

get_time = (config) ->
  if ngx
    ngx.update_time!
    ngx.now!
  elseif config.server == "cqueues"
    require("cqueues").monotime!

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
    default_url_params: =>
      parsed = { k,v for k,v in pairs @req.parsed_url }
      parsed.query = nil
      parsed

    append_content_for: (name, value) =>
      import CONTENT_FOR_PREFIX from require "lapis.html"

      full_name = CONTENT_FOR_PREFIX .. name

      existing = @[full_name]
      switch type existing
        when "nil"
          @[full_name] = value
        when "table"
          table.insert @[full_name], value
        else
          @[full_name] = {existing, value}

      return


    load_cookies: =>
      @cookies = auto_table ->
        cookie = @req.headers.cookie

        if type(cookie) == "table"
          out = {}
          for str in *cookie
            for k,v in pairs parse_cookie_string str
              out[k] = v
          out
        else
          parse_cookie_string cookie

    load_session: =>
      @session = session.lazy_session @

    -- write what is in @options and @buffer into the output
    -- this is called once, and done last
    render: =>
      if @options.skip_render
        return

      @@support.write_session @
      @@support.write_cookies @

      if @options.status
        @res.status = @options.status

      if @options.headers
        for k,v in pairs @options.headers
          @res\add_header k, v

      if @options.json != nil
        @res.headers["Content-Type"] = @options.content_type or "application/json"
        @res.content = to_json @options.json
        @options.layout = false
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
        @options.layout = false
        return

      -- set default layout if none is specified
      if @options.layout == nil
        @options.layout = @app.layout

      if @options.layout
        -- NOTE: @layout_opts is a legacy undocumented field, it should be eventually
        -- be removed now that @options can communicate the layout being used
        -- during view rendering
        @layout_opts = {}

      widget_cls = @options.render
      widget_cls = @route_name if widget_cls == true

      config = lapis_config.get!

      local view_widget
      if widget_cls
        if type(widget_cls) == "string"
          widget_cls = require "#{@app.views_prefix}.#{widget_cls}"

        start_time = if config.measure_performance
          get_time config

        view_widget = widget_cls!
        view_widget\include_helper @
        @write view_widget

        if @layout_opts
          @layout_opts.view_widget = view_widget

        if start_time
          t = get_time config
          increment_perf "view_time", t - start_time

      if layout = @options.layout
        @_content_for_inner = @buffer
        -- create a new buffer for the final result
        @buffer = {}

        layout_cls = if type(layout) == "string"
          require "#{@app.views_prefix}.#{layout}"
        else
          layout

        start_time = if config.measure_performance
          get_time config

        layout = layout_cls @layout_opts

        layout\include_helper @
        layout\render @buffer

        if start_time
          t = get_time config
          increment_perf "layout_time", t - start_time

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
      if name
        @[name] = params

      for k,v in pairs params
        -- expand nested[param][keys]
        front = k\match "^([^%[]+)%[" if type(k) == "string"

        if front
          curr = @params
          has_nesting = false
          for match in k\gmatch "%[([^%]]+)%]"
            has_nesting = true
            new = curr[front]
            if type(new) != "table"
              new = {}
              curr[front] = new

            curr = new
            front = match

          if has_nesting
            curr[front] = v
          else
            -- couldn't parse valid nesting, just bail
            @params[k] = v
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

    parsed = @@support.default_url_params @

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

  -- This will enable you to get a reference to
  -- the request object when it's part of a
  -- helper chain
  get_request: => @

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

