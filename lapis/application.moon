
logger = require "lapis.logging"
lapis_config = require "lapis.config"

import Router from require "lapis.router"

import insert from table

json = require "cjson"

unpack = unpack or table.unpack

local capture_errors, capture_errors_json, respond_to

local Application

MISSING_ROUTE_NAME_ERORR = "Attempted to load action `true` for route with no name, a name must be provided to require the action"
INVALID_ACTION_TYPE = "Loaded an action that is the wrong type. Actions must be a function or callable table"

run_before_filter = (filter, r) ->
  _write = r.write
  written = false
  r.write = (...) ->
    written = true
    _write ...

  filter r
  r.write = nil
  written

load_action = (prefix, action, route_name) ->
  if action == true
    assert route_name, MISSING_ROUTE_NAME_ERORR
    require "#{prefix}.#{route_name}"
  elseif type(action) == "string"
    require "#{prefix}.#{action}"
  else
    action

-- test the type of an action
test_callable = (value) ->
  switch type value
    when "function"
      true
    when "table"
      mt = getmetatable(value)
      mt and mt.__call and true

-- if action is a non-function then we turn it into a function that can
-- dynamically load the appropraite action via `load_action`
wrap_action_loader = (action) ->
  if type(action) == "function"
    return action

  -- NOTE: the closure on the argument is used as the cache
  loaded = false
  =>
    unless loaded
      action = load_action @app.actions_prefix, action, @route_name
      assert test_callable(action), INVALID_ACTION_TYPE

      loaded = true

    action @

-- if obj is a class, then the __base, otherwise obj is an instance and is the
-- route group
get_target_route_group = (obj) ->
  assert obj != Application, "lapis.Application is not able to be modified with routes. You must either subclass or instantiate it"
  if obj == obj.__class
    obj.__base
  else
    obj

class Application
  Request: require "lapis.request"
  layout: require "lapis.views.layout"
  error_page: require "lapis.views.error"

  views_prefix: "views"
  actions_prefix: "actions"
  flows_prefix: "flows"

  new: => @build_router!

  @extend: (name, tbl) =>
    lua = require "lapis.lua"

    if type(name) == "table"
      tbl = name
      name = nil

    class_fields = { }

    cls = lua.class name or "ExtendedApplication", tbl, @
    cls, cls.__base


  -- search the route group hierarchy for the action handler that matches the route name
  -- NOTE: this is a special method that can be called on either the class or the instance
  find_action: (name, resolve=true) =>
    route_group = get_target_route_group @

    cache = rawget route_group, "_named_route_cache"
    unless cache
      cache = {}
      route_group._named_route_cache = cache

    route = cache[name]

    -- refresh the entire route cache
    unless route
      import each_route from require "lapis.application.route_group"
      each_route route_group, true, (path) ->
        if type(path) == "table"
          route_name = next path
          unless cache[route_name]
            cache[route_name] = path
            route = path if route_name == name

    action = route and @[route]

    if resolve
      action = load_action @actions_prefix, action, name

    action, route

  -- NOTE: this is a special method that can be called on either the class or the instance
  enable: (feature) =>
    assert @ != Application, "You tried to enable a feature on the read-only class lapis.Application. You must sub-class it before enabling features"

    fn = require "lapis.features.#{feature}"
    if test_callable fn
      fn @

  -- add new route to the set of routes
  -- NOTE: this is a special method that can be called on either the class or the instance
  match: (route_name, path, handler) =>
    route_group = get_target_route_group(@)
    import add_route from require "lapis.application.route_group"
    add_route route_group, route_name, path, handler
    if route_group == @
      @router = nil

  -- dynamically create methods for common HTTP verbs
  for meth in *{"get", "post", "delete", "put"}
    upper_meth = meth\upper!

    @__base[meth] = (route_name, path, handler) =>
      @router = nil
      if handler == nil
        handler = path
        path = route_name
        route_name = nil

      if type(handler) != "function"
        handler = wrap_action_loader handler

      route_group = get_target_route_group(@)
      import add_route_verb from require "lapis.application.route_group"
      add_route_verb route_group, respond_to, upper_meth, route_name, path, handler
      if route_group == @
        @router = nil

  -- Add before filter `fn` to __base
  before_filter: (fn) =>
    route_group = get_target_route_group(@)
    import add_before_filter from require "lapis.application.route_group"
    add_before_filter route_group, fn

  build_router: =>
    @router = Router!
    @router.default_route = => false

    import each_route from require "lapis.application.route_group"

    -- this will hold both paths and route names to prevent them from being
    -- redeclared by paths lower in precedence
    filled_routes = {}

    each_route @, true, (path, handler) ->
      route_name, path_string = if type(path) == "table"
        next(path), path[next path]
      else
        nil, path

      if route_name
        return if filled_routes[route_name]
        filled_routes[route_name] = true

      return if filled_routes[path_string]
      filled_routes[path_string] = true

      @router\add_route path, @wrap_handler handler

    @router

  -- this creates the callback for the router by wrapping the action defined by
  -- the application. It sets up parameters generated by the router and copies
  -- them into the request. Additionally, any lazy-loaded actions are converted
  -- if necessary.
  wrap_handler: (handler) =>
    (params, path, name, r) ->
      support = r.__class.support

      with r
        .route_name = name

        support.add_params r, r.req.params_get, "GET"
        support.add_params r, r.req.params_post, "POST"
        support.add_params r, params, "url_params"

        if @before_filters
          for filter in *@before_filters
            return r if run_before_filter filter, r

        if type(handler) != "function"
          handler = load_action @actions_prefix, handler, name
          assert test_callable(handler), INVALID_ACTION_TYPE

        \write handler r

  render_request: (r) =>
    r.__class.support.render r
    logger.request r

  render_error_request: (r, err, trace) =>
    config = lapis_config.get!
    r\write @.handle_error r, err, trace

    if config._name == "test"
      r.options.headers or= {}

      param_dump = logger.flatten_params r.original_request.url_params

      error_payload = {
        summary: "[#{r.original_request.req.method}] #{r.original_request.req.request_uri} #{param_dump}"
        :err, :trace
      }

      import to_json from require "lapis.util"
      r.options.headers["X-Lapis-Error"] = to_json error_payload

    r.__class.support.render r
    logger.request r


  dispatch: (req, res) =>
    local err, trace, r

    success = xpcall(
      ->
        r = @.Request @, req, res

        unless @router\resolve req.parsed_url.path, r
          -- run default route if nothing matched
          handler = @wrap_handler @default_route
          handler {}, nil, "default_route", r

        @render_request r

      (_err) ->
        err = _err
        trace = debug.traceback "", 2
    )

    unless success
      -- create a new request to handle the rendering the error
      error_request = @.Request @, req, res
      error_request.original_request = r
      @render_error_request error_request, err, trace

    success, r

  -- copies all actions into this application, preserves before filters
  -- other app can just be a plain table, doesn't have to be another application
  -- @include other_app, path: "/hello", name: "hello_"
  include: (other_app, opts) =>
    into = get_target_route_group @

    if into == @ -- purge the route cache if it exists
      @router = nil

    if type(other_app) == "string"
      other_app = require other_app

    path_prefix = opts and opts.path or other_app.path
    name_prefix = opts and opts.name or other_app.name

    source = get_target_route_group other_app

    import each_route from require "lapis.application.route_group"

    each_route source, true, (path, action) ->
      t = type path
      -- named action
      if t == "table"
        if path_prefix
          name = next path
          path[name] = path_prefix .. path[name]

        if name_prefix
          name = next path
          path[name_prefix .. name] = path[name]
          path[name] = nil
      -- route only action
      elseif t == "string" and path\match "^/"
        if path_prefix
          path = path_prefix .. path
      -- other field in class, ignore
      else
        return

      if name_prefix
        -- normalize and adjust lazy loaded actions
        if type(action) == "string"
          action = name_prefix .. action
        elseif action == true
          assert type(path) == "table", "include: #{MISSING_ROUTE_NAME_ERORR}"
          action = next(path) -- the route name is the only key in the table

      -- embed the before filters into the action
      if before_filters = source.before_filters
        original_action = wrap_action_loader action
        action = (r) ->
          for filter in *before_filters
            return if run_before_filter filter, r

          original_action r

      into[path] = action

    return

  -- Callbacks
  -- run with Request as self, instead of application

  default_route: =>
    -- strip trailing /
    if @req.parsed_url.path\match "./$"
      stripped = @req.parsed_url.path\match "^(.+)/+$"
      -- TODO: if the path starts with // here then build URL will treat it as
      -- an absolute URL and redirect off domain
      redirect_to: @build_url(stripped, query: @req.parsed_url.query), status: 301
    else
      @app.handle_404 @

  handle_404: =>
    error "Failed to find route: #{@req.request_uri}"

  handle_error: (err, trace) =>
    @status = 500
    @err = err
    @trace = trace

    {
      status: @status
      layout: false
      render: @app.error_page
    }

  cookie_attributes: (name, value) =>
    "Path=/; HttpOnly"

respond_to = do
  default_head = -> layout: false -- render nothing
  on_invalid_method = => error "don't know how to respond to #{@req.method}"

  (tbl) ->
    tbl.HEAD = default_head if tbl.HEAD == nil

    out = =>
      fn = tbl[@req.method]
      if fn
        if before = tbl.before
          return if run_before_filter before, @
        fn @
      else
        (tbl.on_invalid_method or on_invalid_method) @

    if error_response = tbl.on_error
      out = capture_errors out, error_response

    out

default_error_response = -> { render: true }
capture_errors = (fn, error_response=default_error_response) ->
  if type(fn) == "table"
    error_response = fn.on_error or error_response
    fn = fn[1]

  (...) =>
    co = coroutine.create fn
    out = { coroutine.resume co, @ }
    while true
      unless out[1] -- error
        error debug.traceback co, out[2]

      -- { status, "error", error_msgs }
      if coroutine.status(co) == "suspended"
        if out[2] == "error"
          @errors = out[3]
          return error_response @
        else -- proxy to someone else
          out = { coroutine.resume co, coroutine.yield unpack out, 2 }
      else
        return unpack out, 2

capture_errors_json = (fn) ->
  capture_errors fn, => {
    json: { errors: @errors }
  }

yield_error = (msg="unknown error") ->
  coroutine.yield "error", {msg}

assert_error = (thing, msg, ...) ->
  yield_error msg unless thing
  -- assert in case the enclosing function can't capture yeilded error, so we trigger hard failure
  assert thing, msg, ...

json_params = (fn) ->
  (...) =>
    if content_type = @req.headers["content-type"]
      -- Header often ends with ;UTF-8
      if string.find content_type\lower!, "application/json", nil, true
        body = @req\read_body_as_string!
        success, obj_or_err = pcall -> json.decode body
        if success
          @@support.add_params @, obj_or_err, "json"

    fn @, ...

{
  Request: Application.Request

  :Application, :respond_to
  :capture_errors, :capture_errors_json
  :json_params, :assert_error, :yield_error
}

