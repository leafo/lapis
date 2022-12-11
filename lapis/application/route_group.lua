local add_route
add_route = function(obj, route_name, path, handler)
  if handler == nil then
    handler = path
    path = route_name
    route_name = nil
  end
  local ordered_routes = rawget(obj, "ordered_routes")
  if not (ordered_routes) then
    ordered_routes = { }
    obj.ordered_routes = ordered_routes
  end
  local key
  if route_name then
    key = {
      [route_name] = path
    }
  else
    key = path
  end
  table.insert(ordered_routes, key)
  obj[key] = handler
end
local add_route_verb
add_route_verb = function(obj, respond_to, method, route_name, path, handler)
  if handler == nil then
    handler = path
    path = route_name
    route_name = nil
  end
  local responders = rawget(obj, "responders")
  if not (responders) then
    responders = { }
    obj.responders = responders
  end
  local existing = responders[path]
  if existing then
    assert(existing.path == path, "You are trying to add a new verb action to a route that was declared with an existing route name but a different path. Please ensure you use the same route name and path combination when adding additional verbs to a route.")
    assert(existing.route_name == route_name, "You are trying to add a new verb action to a route that was declared with and existing path but different route name. Please ensure you use the same route name and path combination when adding additional verbs to a route.")
    existing.respond_to[method] = handler
  else
    local tbl = {
      [method] = handler
    }
    responders[path] = {
      path = path,
      route_name = route_name,
      respond_to = tbl
    }
    local responder = respond_to(tbl)
    if route_name then
      add_route(obj, route_name, path, responder)
    else
      add_route(obj, path, responder)
    end
  end
end
local add_before_filter
add_before_filter = function(obj, fn)
  local before_filters = rawget(obj, "before_filters")
  if not (before_filters) then
    before_filters = { }
    obj.before_filters = before_filters
  end
  table.insert(before_filters, fn)
end
local scan_routes_on_object
scan_routes_on_object = function(obj, each_route_fn)
  local added = { }
  do
    local ordered = rawget(obj, "ordered_routes")
    if ordered then
      for _index_0 = 1, #ordered do
        local path = ordered[_index_0]
        added[path] = true
        each_route_fn(path, assert(obj[path], "Failed to find route handler when adding ordered route"))
      end
    end
  end
  for path, handler in pairs(obj) do
    local _continue_0 = false
    repeat
      if added[path] then
        _continue_0 = true
        break
      end
      each_route_fn(path, handler)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
return {
  scan_routes_on_object = scan_routes_on_object,
  add_route = add_route,
  add_route_verb = add_route_verb,
  add_before_filter = add_before_filter
}