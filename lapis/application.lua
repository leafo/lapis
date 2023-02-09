local logger = require("lapis.logging")
local lapis_config = require("lapis.config")
local Router
Router = require("lapis.router").Router
local insert
insert = table.insert
local json = require("cjson")
local unpack = unpack or table.unpack
local capture_errors, capture_errors_json, respond_to
local Application
local MISSING_ROUTE_NAME_ERORR = "Attempted to load action `true` for route with no name, a name must be provided to require the action"
local INVALID_ACTION_TYPE = "Loaded an action that is the wrong type. Actions must be a function or callable table"
local run_before_filter
run_before_filter = function(filter, r)
  local _write = r.write
  local written = false
  r.write = function(...)
    written = true
    return _write(...)
  end
  filter(r)
  r.write = nil
  return written
end
local load_action
load_action = function(prefix, action, route_name)
  if action == true then
    assert(route_name, MISSING_ROUTE_NAME_ERORR)
    return require(tostring(prefix) .. "." .. tostring(route_name))
  elseif type(action) == "string" then
    return require(tostring(prefix) .. "." .. tostring(action))
  else
    return action
  end
end
local test_callable
test_callable = function(value)
  local _exp_0 = type(value)
  if "function" == _exp_0 then
    return true
  elseif "table" == _exp_0 then
    local mt = getmetatable(value)
    return mt and mt.__call and true
  end
end
local wrap_action_loader
wrap_action_loader = function(action)
  if type(action) == "function" then
    return action
  end
  local loaded = false
  return function(self)
    if not (loaded) then
      action = load_action(self.app.actions_prefix, action, self.route_name)
      assert(test_callable(action), INVALID_ACTION_TYPE)
      loaded = true
    end
    return action(self)
  end
end
local get_target_route_group
get_target_route_group = function(obj)
  assert(obj ~= Application, "lapis.Application is not able to be modified with routes. You must either subclass or instantiate it")
  if obj == obj.__class then
    return obj.__base
  else
    return obj
  end
end
do
  local _class_0
  local _base_0 = {
    Request = require("lapis.request"),
    layout = require("lapis.views.layout"),
    error_page = require("lapis.views.error"),
    views_prefix = "views",
    actions_prefix = "actions",
    flows_prefix = "flows",
    find_action = function(self, name, resolve)
      if resolve == nil then
        resolve = true
      end
      local route_group = get_target_route_group(self)
      local cache = rawget(route_group, "_named_route_cache")
      if not (cache) then
        cache = { }
        route_group._named_route_cache = cache
      end
      local route = cache[name]
      if not (route) then
        local each_route
        each_route = require("lapis.application.route_group").each_route
        each_route(route_group, true, function(path)
          if type(path) == "table" then
            local route_name = next(path)
            if not (cache[route_name]) then
              cache[route_name] = path
              if route_name == name then
                route = path
              end
            end
          end
        end)
      end
      local action = route and self[route]
      if resolve then
        action = load_action(self.actions_prefix, action, name)
      end
      return action, route
    end,
    enable = function(self, feature)
      assert(self ~= Application, "You tried to enable a feature on the read-only class lapis.Application. You must sub-class it before enabling features")
      local fn = require("lapis.features." .. tostring(feature))
      if test_callable(fn) then
        return fn(self)
      end
    end,
    match = function(self, route_name, path, handler)
      local route_group = get_target_route_group(self)
      local add_route
      add_route = require("lapis.application.route_group").add_route
      add_route(route_group, route_name, path, handler)
      if route_group == self then
        self.router = nil
      end
    end,
    before_filter = function(self, fn)
      local route_group = get_target_route_group(self)
      local add_before_filter
      add_before_filter = require("lapis.application.route_group").add_before_filter
      return add_before_filter(route_group, fn)
    end,
    build_router = function(self)
      self.router = Router()
      self.router.default_route = function(self)
        return false
      end
      local each_route
      each_route = require("lapis.application.route_group").each_route
      local filled_routes = { }
      each_route(self, true, function(path, handler)
        local route_name, path_string
        if type(path) == "table" then
          route_name, path_string = next(path), path[next(path)]
        else
          route_name, path_string = nil, path
        end
        if route_name then
          if filled_routes[route_name] then
            return 
          end
          filled_routes[route_name] = true
        end
        if filled_routes[path_string] then
          return 
        end
        filled_routes[path_string] = true
        return self.router:add_route(path, self:wrap_handler(handler))
      end)
      return self.router
    end,
    wrap_handler = function(self, handler)
      return function(params, path, name, r)
        local support = r.__class.support
        do
          local _with_0 = r
          _with_0.route_name = name
          support.add_params(r, r.req.params_get, "GET")
          support.add_params(r, r.req.params_post, "POST")
          support.add_params(r, params, "url_params")
          if self.before_filters then
            local _list_0 = self.before_filters
            for _index_0 = 1, #_list_0 do
              local filter = _list_0[_index_0]
              if run_before_filter(filter, r) then
                return r
              end
            end
          end
          if type(handler) ~= "function" then
            handler = load_action(self.actions_prefix, handler, name)
            assert(test_callable(handler), INVALID_ACTION_TYPE)
          end
          _with_0:write(handler(r))
          return _with_0
        end
      end
    end,
    render_request = function(self, r)
      r.__class.support.render(r)
      return logger.request(r)
    end,
    render_error_request = function(self, r, err, trace)
      local config = lapis_config.get()
      r:write(self.handle_error(r, err, trace))
      if config._name == "test" then
        r.options.headers = r.options.headers or { }
        local param_dump = logger.flatten_params(r.original_request.url_params)
        local error_payload = {
          summary = "[" .. tostring(r.original_request.req.method) .. "] " .. tostring(r.original_request.req.request_uri) .. " " .. tostring(param_dump),
          err = err,
          trace = trace
        }
        local to_json
        to_json = require("lapis.util").to_json
        r.options.headers["X-Lapis-Error"] = to_json(error_payload)
      end
      r.__class.support.render(r)
      return logger.request(r)
    end,
    dispatch = function(self, req, res)
      local err, trace, r
      local success = xpcall(function()
        r = self.Request(self, req, res)
        if not (self.router:resolve(req.parsed_url.path, r)) then
          local handler = self:wrap_handler(self.default_route)
          handler({ }, nil, "default_route", r)
        end
        return self:render_request(r)
      end, function(_err)
        err = _err
        trace = debug.traceback("", 2)
      end)
      if not (success) then
        local error_request = self.Request(self, req, res)
        error_request.original_request = r
        self:render_error_request(error_request, err, trace)
      end
      return success, r
    end,
    include = function(self, other_app, opts)
      local into = get_target_route_group(self)
      if into == self then
        self.router = nil
      end
      if type(other_app) == "string" then
        other_app = require(other_app)
      end
      local path_prefix = opts and opts.path or other_app.path
      local name_prefix = opts and opts.name or other_app.name
      local source = get_target_route_group(other_app)
      local each_route
      each_route = require("lapis.application.route_group").each_route
      each_route(source, true, function(path, action)
        local t = type(path)
        if t == "table" then
          if path_prefix then
            local name = next(path)
            path[name] = path_prefix .. path[name]
          end
          if name_prefix then
            local name = next(path)
            path[name_prefix .. name] = path[name]
            path[name] = nil
          end
        elseif t == "string" and path:match("^/") then
          if path_prefix then
            path = path_prefix .. path
          end
        else
          return 
        end
        if name_prefix then
          if type(action) == "string" then
            action = name_prefix .. action
          elseif action == true then
            assert(type(path) == "table", "include: " .. tostring(MISSING_ROUTE_NAME_ERORR))
            action = next(path)
          end
        end
        do
          local before_filters = source.before_filters
          if before_filters then
            local original_action = wrap_action_loader(action)
            action = function(r)
              for _index_0 = 1, #before_filters do
                local filter = before_filters[_index_0]
                if run_before_filter(filter, r) then
                  return 
                end
              end
              return original_action(r)
            end
          end
        end
        into[path] = action
      end)
    end,
    default_route = function(self)
      if self.req.parsed_url.path:match("./$") then
        local stripped = self.req.parsed_url.path:match("^(.+)/+$")
        return {
          redirect_to = self:build_url(stripped, {
            query = self.req.parsed_url.query
          }),
          status = 301
        }
      else
        return self.app.handle_404(self)
      end
    end,
    handle_404 = function(self)
      return error("Failed to find route: " .. tostring(self.req.request_uri))
    end,
    handle_error = function(self, err, trace)
      self.status = 500
      self.err = err
      self.trace = trace
      return {
        status = self.status,
        layout = false,
        render = self.app.error_page
      }
    end,
    cookie_attributes = function(self, name, value)
      return "Path=/; HttpOnly"
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      return self:build_router()
    end,
    __base = _base_0,
    __name = "Application"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.extend = function(self, name, tbl)
    local lua = require("lapis.lua")
    if type(name) == "table" then
      tbl = name
      name = nil
    end
    local class_fields = { }
    local cls = lua.class(name or "ExtendedApplication", tbl, self)
    return cls, cls.__base
  end
  local _list_0 = {
    "get",
    "post",
    "delete",
    "put"
  }
  for _index_0 = 1, #_list_0 do
    local meth = _list_0[_index_0]
    local upper_meth = meth:upper()
    self.__base[meth] = function(self, route_name, path, handler)
      self.router = nil
      if handler == nil then
        handler = path
        path = route_name
        route_name = nil
      end
      if type(handler) ~= "function" then
        handler = wrap_action_loader(handler)
      end
      local route_group = get_target_route_group(self)
      local add_route_verb
      add_route_verb = require("lapis.application.route_group").add_route_verb
      add_route_verb(route_group, respond_to, upper_meth, route_name, path, handler)
      if route_group == self then
        self.router = nil
      end
    end
  end
  Application = _class_0
end
do
  local default_head
  default_head = function()
    return {
      layout = false
    }
  end
  local on_invalid_method
  on_invalid_method = function(self)
    return error("don't know how to respond to " .. tostring(self.req.method))
  end
  respond_to = function(tbl)
    if tbl.HEAD == nil then
      tbl.HEAD = default_head
    end
    local out
    out = function(self)
      local fn = tbl[self.req.method]
      if fn then
        do
          local before = tbl.before
          if before then
            if run_before_filter(before, self) then
              return 
            end
          end
        end
        return fn(self)
      else
        return (tbl.on_invalid_method or on_invalid_method)(self)
      end
    end
    do
      local error_response = tbl.on_error
      if error_response then
        out = capture_errors(out, error_response)
      end
    end
    return out
  end
end
local default_error_response
default_error_response = function()
  return {
    render = true
  }
end
capture_errors = function(fn, error_response)
  if error_response == nil then
    error_response = default_error_response
  end
  if type(fn) == "table" then
    error_response = fn.on_error or error_response
    fn = fn[1]
  end
  return function(self, ...)
    local co = coroutine.create(fn)
    local out = {
      coroutine.resume(co, self)
    }
    while true do
      if not (out[1]) then
        error(debug.traceback(co, out[2]))
      end
      if coroutine.status(co) == "suspended" then
        if out[2] == "error" then
          self.errors = out[3]
          return error_response(self)
        else
          out = {
            coroutine.resume(co, coroutine.yield(unpack(out, 2)))
          }
        end
      else
        return unpack(out, 2)
      end
    end
  end
end
capture_errors_json = function(fn)
  return capture_errors(fn, function(self)
    return {
      json = {
        errors = self.errors
      }
    }
  end)
end
local yield_error
yield_error = function(msg)
  if msg == nil then
    msg = "unknown error"
  end
  return coroutine.yield("error", {
    msg
  })
end
local assert_error
assert_error = function(thing, msg, ...)
  if not (thing) then
    yield_error(msg)
  end
  return assert(thing, msg, ...)
end
local json_params
json_params = function(fn)
  return function(self, ...)
    do
      local content_type = self.req.headers["content-type"]
      if content_type then
        if string.find(content_type:lower(), "application/json", nil, true) then
          local body = self.req:read_body_as_string()
          local success, obj_or_err = pcall(function()
            return json.decode(body)
          end)
          if success then
            self.__class.support.add_params(self, obj_or_err, "json")
          end
        end
      end
    end
    return fn(self, ...)
  end
end
return {
  Request = Application.Request,
  Application = Application,
  respond_to = respond_to,
  capture_errors = capture_errors,
  capture_errors_json = capture_errors_json,
  json_params = json_params,
  assert_error = assert_error,
  yield_error = yield_error
}
