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
local each_route
each_route = function(obj, scan_metatable, callback)
  if scan_metatable == nil then
    scan_metatable = false
  end
  local added = { }
  do
    local ordered = rawget(obj, "ordered_routes")
    if ordered then
      for _index_0 = 1, #ordered do
        local path = ordered[_index_0]
        added[path] = true
        local handler = assert(obj[path], "Failed to find route handler when adding ordered route")
        callback(path, handler)
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
      local _exp_0 = type(path)
      if "string" == _exp_0 then
        if not (path:match("^/")) then
          _continue_0 = true
          break
        end
      elseif "table" == _exp_0 then
        local k = next(path)
        if not (type(k) == "string" or type(path[k]) == "string") then
          _continue_0 = true
          break
        end
      else
        _continue_0 = true
        break
      end
      callback(path, handler)
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  if scan_metatable then
    local obj_mt = getmetatable(obj)
    if obj_mt and type(obj_mt.__index) == "table" then
      return each_route(obj_mt.__index, scan_metatable, callback)
    end
  end
end
local each_route_iter
each_route_iter = function(obj, scan_metatable)
  return coroutine.wrap(function()
    return each_route(obj, scan_metatable, coroutine.yield)
  end)
end
return {
  each_route = each_route,
  each_route_iter = each_route_iter,
  add_route = add_route,
  add_route_verb = add_route_verb,
  add_before_filter = add_before_filter
}
