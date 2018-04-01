local logger = require("lapis.logging")
local lapis_config = require("lapis.config")
local Router
Router = require("lapis.router").Router
local insert
insert = table.insert
local json = require("cjson")
local capture_errors, capture_errors_json, respond_to
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
local Application
do
  local _class_0
  local _base_0 = {
    Request = require("lapis.request"),
    layout = require("lapis.views.layout"),
    error_page = require("lapis.views.error"),
    views_prefix = "views",
    flows_prefix = "flows",
    enable = function(self, feature)
      local fn = require("lapis.features." .. tostring(feature))
      if type(fn) == "function" then
        return fn(self)
      end
    end,
    match = function(self, route_name, path, handler)
      if handler == nil then
        handler = path
        path = route_name
        route_name = nil
      end
      self.ordered_routes = self.ordered_routes or { }
      local key
      if route_name then
        local tuple = self.ordered_routes[route_name]
        do
          local old_path = tuple and tuple[next(tuple)]
          if old_path then
            if old_path ~= path then
              error("named route mismatch (" .. tostring(old_path) .. " != " .. tostring(path) .. ")")
            end
          end
        end
        if tuple then
          key = tuple
        else
          tuple = {
            [route_name] = path
          }
          self.ordered_routes[route_name] = tuple
          key = tuple
        end
      else
        key = path
      end
      if not (self[key]) then
        insert(self.ordered_routes, key)
      end
      self[key] = handler
      self.router = nil
      return handler
    end,
    build_router = function(self)
      self.router = Router()
      self.router.default_route = function(self)
        return false
      end
      local add_route
      add_route = function(path, handler)
        local t = type(path)
        if t == "table" or t == "string" and path:match("^/") then
          return self.router:add_route(path, self:wrap_handler(handler))
        end
      end
      local add_routes
      add_routes = function(cls)
        for path, handler in pairs(cls.__base) do
          add_route(path, handler)
        end
        do
          local ordered = self.ordered_routes
          if ordered then
            for _index_0 = 1, #ordered do
              local path = ordered[_index_0]
              add_route(path, self[path])
            end
          else
            for path, handler in pairs(self) do
              add_route(path, handler)
            end
          end
        end
        do
          local parent = cls.__parent
          if parent then
            return add_routes(parent)
          end
        end
      end
      return add_routes(self.__class)
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
          summary = "[" .. tostring(r.original_request.req.cmd_mth) .. "] " .. tostring(r.original_request.req.cmd_url) .. " " .. tostring(param_dump),
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
      local capture_error
      capture_error = function(_err)
        err = _err
        trace = debug.traceback("", 2)
      end
      local raw_request
      raw_request = function()
        r = self.Request(self, req, res)
        if not (self.router:resolve(req.parsed_url.path, r)) then
          local handler = self:wrap_handler(self.default_route)
          handler({ }, nil, "default_route", r)
        end
        return self:render_request(r)
      end
      local success = xpcall(raw_request, capture_error)
      if not (success) then
        local error_request = self.Request(self, req, res)
        error_request.original_request = r
        self:render_error_request(error_request, err, trace)
      end
      return success, r
    end,
    before_filter = function(self, fn)
      if not (rawget(self, "before_filters")) then
        self.before_filters = { }
      end
      return insert(self.before_filters, fn)
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
      return error("Failed to find route: " .. tostring(self.req.cmd_url))
    end,
    handle_error = function(self, err, trace)
      self.status = 500
      self.err = err
      self.trace = trace
      return {
        status = 500,
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
  self.find_action = function(self, name)
    self._named_route_cache = self._named_route_cache or { }
    local route = self._named_route_cache[name]
    if not (route) then
      for app_route in pairs(self.__base) do
        if type(app_route) == "table" then
          local app_route_name = next(app_route)
          self._named_route_cache[app_route_name] = app_route
          if app_route_name == name then
            route = app_route
          end
        end
      end
    end
    return route and self[route], route
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
      if handler == nil then
        handler = path
        path = route_name
        route_name = nil
      end
      self.responders = self.responders or { }
      local existing = self.responders[route_name or path]
      local tbl = {
        [upper_meth] = handler
      }
      if existing then
        setmetatable(tbl, {
          __index = function(self, key)
            if key:match("%u") then
              return existing
            end
          end
        })
      end
      local responder = respond_to(tbl)
      self.responders[route_name or path] = responder
      return self:match(route_name, path, responder)
    end
  end
  self.before_filter = function(self, ...)
    return self.__base.before_filter(self.__base, ...)
  end
  self.include = function(self, other_app, opts, into)
    if into == nil then
      into = self.__base
    end
    if type(other_app) == "string" then
      other_app = require(other_app)
    end
    local path_prefix = opts and opts.path or other_app.path
    local name_prefix = opts and opts.name or other_app.name
    for path, action in pairs(other_app.__base) do
      local _continue_0 = false
      repeat
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
          _continue_0 = true
          break
        end
        do
          local before_filters = other_app.before_filters
          if before_filters then
            local fn = action
            action = function(r)
              for _index_0 = 1, #before_filters do
                local filter = before_filters[_index_0]
                if run_before_filter(filter, r) then
                  return 
                end
              end
              return fn(r)
            end
          end
        end
        into[path] = action
        _continue_0 = true
      until true
      if not _continue_0 then
        break
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
  respond_to = function(tbl)
    if not (tbl.HEAD) then
      tbl.HEAD = default_head
    end
    local out
    out = function(self)
      local fn = tbl[self.req.cmd_mth]
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
        return error("don't know how to respond to " .. tostring(self.req.cmd_mth))
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
  return coroutine.yield("error", {
    msg
  })
end
local assert_error
assert_error = function(thing, msg, ...)
  if not (thing) then
    yield_error(msg)
  end
  return thing, msg, ...
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
