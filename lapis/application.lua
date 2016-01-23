local logger = require("lapis.logging")
local url = require("socket.url")
local session = require("lapis.session")
local lapis_config = require("lapis.config")
local Router
Router = require("lapis.router").Router
local html_writer
html_writer = require("lapis.html").html_writer
local increment_perf
increment_perf = require("lapis.nginx.context").increment_perf
local parse_cookie_string, to_json, build_url, auto_table
do
  local _obj_0 = require("lapis.util")
  parse_cookie_string, to_json, build_url, auto_table = _obj_0.parse_cookie_string, _obj_0.to_json, _obj_0.build_url, _obj_0.auto_table
end
local insert
insert = table.insert
local json = require("cjson")
local capture_errors, capture_errors_json, respond_to
local set_and_truthy
set_and_truthy = function(val, default)
  if default == nil then
    default = true
  end
  if val == nil then
    return default
  end
  return val
end
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
local Request
do
  local _class_0
  local _base_0 = {
    add_params = function(self, params, name)
      self[name] = params
      for k, v in pairs(params) do
        local front
        if type(k) == "string" then
          front = k:match("^([^%[]+)%[")
        end
        if front then
          local curr = self.params
          for match in k:gmatch("%[(.-)%]") do
            local new = curr[front]
            if new == nil then
              new = { }
              curr[front] = new
            end
            curr = new
            front = match
          end
          curr[front] = v
        else
          self.params[k] = v
        end
      end
    end,
    render = function(self, opts)
      if opts == nil then
        opts = false
      end
      if opts then
        self.options = opts
      end
      session.write_session(self)
      self:write_cookies()
      if self.options.status then
        self.res.status = self.options.status
      end
      do
        local obj = self.options.json
        if obj then
          self.res.headers["Content-Type"] = "application/json"
          self.res.content = to_json(obj)
          return 
        end
      end
      do
        local ct = self.options.content_type
        if ct then
          self.res.headers["Content-Type"] = ct
        end
      end
      if not self.res.headers["Content-Type"] then
        self.res.headers["Content-Type"] = "text/html"
      end
      do
        local redirect_url = self.options.redirect_to
        if redirect_url then
          if redirect_url:match("^/") then
            redirect_url = self:build_url(redirect_url)
          end
          self.res:add_header("Location", redirect_url)
          self.res.status = self.res.status or 302
          return ""
        end
      end
      local has_layout = self.app.layout and set_and_truthy(self.options.layout, true)
      if has_layout then
        self.layout_opts = {
          _content_for_inner = nil
        }
      end
      local widget = self.options.render
      if widget == true then
        widget = self.route_name
      end
      local config = lapis_config.get()
      if widget then
        if type(widget) == "string" then
          widget = require(tostring(self.app.views_prefix) .. "." .. tostring(widget))
        end
        local start_time
        if config.measure_performance then
          ngx.update_time()
          start_time = ngx.now()
        end
        local view = widget(self.options.locals)
        if self.layout_opts then
          self.layout_opts.view_widget = view
        end
        view:include_helper(self)
        self:write(view)
        if start_time then
          ngx.update_time()
          increment_perf("view_time", ngx.now() - start_time)
        end
      end
      if has_layout then
        local inner = self.buffer
        self.buffer = { }
        local layout_path = self.options.layout
        local layout_cls
        if type(layout_path) == "string" then
          layout_cls = require(tostring(self.app.views_prefix) .. "." .. tostring(layout_path))
        elseif type(self.app.layout) == "string" then
          layout_cls = require(tostring(self.app.views_prefix) .. "." .. tostring(self.app.layout))
        else
          layout_cls = self.app.layout
        end
        local start_time
        if config.measure_performance then
          ngx.update_time()
          start_time = ngx.now()
        end
        self.layout_opts._content_for_inner = self.layout_opts._content_for_inner or function()
          return raw(inner)
        end
        local layout = layout_cls(self.layout_opts)
        layout:include_helper(self)
        layout:render(self.buffer)
        if start_time then
          ngx.update_time()
          increment_perf("layout_time", ngx.now() - start_time)
        end
      end
      if next(self.buffer) then
        local content = table.concat(self.buffer)
        if self.res.content then
          self.res.content = self.res.content .. content
        else
          self.res.content = content
        end
      end
    end,
    html = function(self, fn)
      return html_writer(fn)
    end,
    url_for = function(self, first, ...)
      if type(first) == "table" then
        return self.app.router:url_for(first:url_params(self, ...))
      else
        return self.app.router:url_for(first, ...)
      end
    end,
    build_url = function(self, path, options)
      if path and (path:match("^%a+:") or path:match("^//")) then
        return path
      end
      local parsed
      do
        local _tbl_0 = { }
        for k, v in pairs(self.req.parsed_url) do
          _tbl_0[k] = v
        end
        parsed = _tbl_0
      end
      parsed.query = nil
      if path then
        local _path, query = path:match("^(.-)%?(.*)$")
        path = _path or path
        parsed.query = query
      end
      parsed.path = path
      local scheme = parsed.scheme or "http"
      if scheme == "http" and parsed.port == "80" then
        parsed.port = nil
      end
      if scheme == "https" and parsed.port == "443" then
        parsed.port = nil
      end
      if options then
        for k, v in pairs(options) do
          parsed[k] = v
        end
      end
      return build_url(parsed)
    end,
    write = function(self, ...)
      local _list_0 = {
        ...
      }
      for _index_0 = 1, #_list_0 do
        local thing = _list_0[_index_0]
        local t = type(thing)
        if t == "table" then
          local mt = getmetatable(thing)
          if mt and mt.__call then
            t = "function"
          end
        end
        local _exp_0 = t
        if "string" == _exp_0 then
          insert(self.buffer, thing)
        elseif "table" == _exp_0 then
          for k, v in pairs(thing) do
            if type(k) == "string" then
              self.options[k] = v
            else
              self:write(v)
            end
          end
        elseif "function" == _exp_0 then
          self:write(thing(self.buffer))
        elseif "nil" == _exp_0 then
          local _ = nil
        else
          error("Don't know how to write: (" .. tostring(t) .. ") " .. tostring(thing))
        end
      end
    end,
    write_cookies = function(self)
      if not (next(self.cookies)) then
        return 
      end
      for k, v in pairs(self.cookies) do
        local cookie = tostring(url.escape(k)) .. "=" .. tostring(url.escape(v))
        do
          local extra = self.app.cookie_attributes(self, k, v)
          if extra then
            cookie = cookie .. ("; " .. extra)
          end
        end
        self.res:add_header("Set-Cookie", cookie)
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, app, req, res)
      self.app, self.req, self.res = app, req, res
      self.buffer = { }
      self.params = { }
      self.options = { }
      self.cookies = auto_table(function()
        return parse_cookie_string(self.req.headers.cookie)
      end)
      self.session = session.lazy_session(self)
    end,
    __base = _base_0,
    __name = "Request"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Request = _class_0
end
local Application
do
  local _class_0
  local _base_0 = {
    Request = Request,
    layout = require("lapis.views.layout"),
    error_page = require("lapis.views.error"),
    views_prefix = "views",
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
        do
          local _with_0 = r
          _with_0.route_name = name
          _with_0:add_params(r.req.params_get, "GET")
          _with_0:add_params(r.req.params_post, "POST")
          _with_0:add_params(params, "url_params")
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
    dispatch = function(self, req, res)
      local err, trace, r
      local success = xpcall((function()
        r = self.Request(self, req, res)
        if not (self.router:resolve(req.parsed_url.path, r)) then
          local handler = self:wrap_handler(self.default_route)
          handler({ }, nil, "default_route", r)
        end
        r:render()
        return logger.request(r)
      end), function(_err)
        err = _err
        trace = debug.traceback("", 2)
      end)
      if not (success) then
        self.handle_error(r, err, trace)
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
    handle_error = function(self, err, trace, error_page)
      if error_page == nil then
        error_page = self.app.error_page
      end
      local r = self.app.Request(self, self.req, self.res)
      local config = lapis_config.get()
      if config._name == "test" then
        local param_dump = logger.flatten_params(self.url_params)
        r.res:add_header("X-Lapis-Error", "true")
        r:write({
          status = 500,
          json = {
            status = "[" .. tostring(r.req.cmd_mth) .. "] " .. tostring(r.req.cmd_url) .. " " .. tostring(param_dump),
            err = err,
            trace = trace
          }
        })
      else
        r:write({
          status = 500,
          layout = false,
          content_type = "text/html",
          error_page({
            status = 500,
            err = err,
            trace = trace
          })
        })
      end
      r:render()
      logger.request(r)
      return r
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
    if not (out[1]) then
      error(debug.traceback(co, out[2]))
    end
    if coroutine.status(co) == "suspended" then
      if out[2] == "error" then
        self.errors = out[3]
        return error_response(self)
      else
        return error("Unknown yield")
      end
    else
      return unpack(out, 2)
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
          ngx.req.read_body()
          local obj
          pcall(function()
            local err
            obj, err = json.decode(ngx.req.get_body_data())
          end)
          if obj then
            self:add_params(obj, "json")
          end
        end
      end
    end
    return fn(self, ...)
  end
end
return {
  Request = Request,
  Application = Application,
  respond_to = respond_to,
  capture_errors = capture_errors,
  capture_errors_json = capture_errors_json,
  json_params = json_params,
  assert_error = assert_error,
  yield_error = yield_error
}
