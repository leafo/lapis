-- These functions work on a 'route group' object, that is an object that is
-- able to contain routes. In practice, a lapis.Application class.__base and
-- instance are both route groups, meaning you can declare routes on both. When
-- the router is built, the instance, class, and any classes in the class
-- hierarchy are scanned in order to build the final router

-- Routes can be stored on the object in two forms:
-- {
--   "/path": => -- handler
--   [route_name: "/other-path"]: => -- other handler
-- }

-- There are additional fields that can be in a route group object:

-- `ordered_routes`: If exists, it will be used to dictate the order of the
-- routes on the object. Any routes not specified in ordered_routes will come
-- after in no particular order.

-- `before_filters`: An optional array of functions that should be processed
-- before the handler when resolving a request

add_route = (obj, route_name, path, handler) ->
  if handler == nil
    handler = path
    path = route_name
    route_name = nil

  -- store the route insertion order to ensure they are added to the router
  -- in the same order as they are defined (NOTE: routes are still sorted by
  -- precedence)
  ordered_routes = rawget obj, "ordered_routes"
  unless ordered_routes
    ordered_routes = {}
    obj.ordered_routes = ordered_routes

  key = if route_name
    {[route_name]: path}
  else
    path

  table.insert ordered_routes, key

  obj[key] = handler
  return -- return nothing

-- add a route that's tied to a particular HTTP verb via respond_to
-- method should be UPPERCASE
add_route_verb = (obj, respond_to, method, route_name, path, handler) ->
  if handler == nil
    handler = path
    path = route_name
    route_name = nil

  responders = rawget obj, "responders"
  unless responders
    responders = {}
    obj.responders = responders

  existing = responders[path]

  -- this must live somewhere else
  -- if type(handler) != "function"
  --   -- NOTE: this works slightly differently, as it loads the action
  --   -- immediately instead of lazily, how it happens in wrap_handler. This
  --   -- is okay for now as we'll likely be overhauling this interface
  --   handler = load_action @actions_prefix, handler, route_name

  if existing
    -- add the handler to the responder table for the method

    -- TODO: write specs for this
    -- assert that what we are adding to matches what it was initially declared as
    assert existing.path == path,
      "You are trying to add a new verb action to a route that was declared with an existing route name but a different path. Please ensure you use the same route name and path combination when adding additional verbs to a route."

    assert existing.route_name == route_name,
      "You are trying to add a new verb action to a route that was declared with and existing path but different route name. Please ensure you use the same route name and path combination when adding additional verbs to a route."

    existing.respond_to[method] = handler
  else
    -- create the initial responder and add route to match

    tbl = { [method]: handler }

    -- NOTE: we store the pre-wrapped table in responders so we can mutate it
    responders[path] = {
      :path
      :route_name
      respond_to: tbl
    }

    responder = respond_to tbl

    if route_name
      add_route obj, route_name, path, responder
    else
      add_route obj, path, responder

  return -- return nothing

add_before_filter = (obj, fn) ->
  before_filters = rawget obj, "before_filters"
  unless before_filters
    before_filters = {}
    obj.before_filters = before_filters

  table.insert before_filters, fn
  return

-- Finds all routes on the object, in order, and calls callback with each one.
-- callback recives arguments path_key, handler_function
each_route = (obj, scan_metatable=false, callback) ->
  added = {}

  if ordered = rawget obj, "ordered_routes"
    for path in *ordered
      added[path] = true
      handler = assert obj[path], "Failed to find route handler when adding ordered route"
      callback path, handler

  for path, handler in pairs obj
    continue if added[path] -- do not re-add things that ordered_routes already took care of

    -- confirm it's a route: either path is a string that starts with "/" or
    -- it's a table of { name: path }
    switch type path
      when "string"
        continue unless path\match "^/"
      when "table"
        k = next(path)
        continue unless type(k) == "string" or type(path[k]) == "string"
      else
        continue

    callback path, handler

  if scan_metatable
    obj_mt = getmetatable obj
    if obj_mt and type(obj_mt.__index) == "table"
      each_route obj_mt.__index, scan_metatable, callback

each_route_iter = (obj, scan_metatable) ->
  coroutine.wrap ->
    each_route obj, scan_metatable, coroutine.yield

{ :each_route, :each_route_iter, :add_route, :add_route_verb, :add_before_filter }
