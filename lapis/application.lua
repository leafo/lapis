local logger = require("lapis.logging")
local url = require("socket.url")
local session = require("lapis.session")
local Router
do
  local _obj_0 = require("lapis.router")
  Router = _obj_0.Router
end
local html_writer
do
  local _obj_0 = require("lapis.html")
  html_writer = _obj_0.html_writer
end
local parse_cookie_string, to_json, build_url, auto_table
do
  local _obj_0 = require("lapis.util")
  parse_cookie_string, to_json, build_url, auto_table = _obj_0.parse_cookie_string, _obj_0.to_json, _obj_0.build_url, _obj_0.auto_table
end
local capture_errors, capture_errors_json
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
  local _base_0 = {
    add_params = function(self, params, name)
      self[name] = params
      for k, v in pairs(params) do
        do
          local front = k:match("^([^%[]+)%[")
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
          self.res.headers["Content-type"] = "application/json"
          self.res.content = to_json(obj)
          return 
        end
      end
      do
        local ct = self.options.content_type
        if ct then
          self.res.headers["Content-type"] = ct
        end
      end
      if not self.res.headers["Content-type"] then
        self.res.headers["Content-type"] = "text/html"
      end
      do
        local redirect_url = self.options.redirect_to
        if redirect_url then
          if redirect_url:match("^/") then
            redirect_url = self:build_url(redirect_url)
          end
          self.res:add_header("Location", redirect_url)
          self.res.status = self.res.status or 302
        end
      end
      do
        local widget = self.options.render
        if widget then
          if widget == true then
            widget = self.route_name
          end
          if type(widget) == "string" then
            widget = require(tostring(self.app.views_prefix) .. "." .. tostring(widget))
          end
          local view = widget(self.options.locals)
          view:include_helper(self)
          self:write(view)
        end
      end
      if self.app.layout and set_and_truthy(self.options.layout, true) then
        local inner = self.buffer
        self.buffer = { }
        local layout_path = self.options.layout
        local layout_cls
        if type(layout_path) == "string" then
          layout_cls = require(tostring(self.app.views_prefix) .. "." .. tostring(layout_path))
        else
          layout_cls = self.app.layout
        end
        local layout = layout_cls({
          inner = function()
            return raw(inner)
          end
        })
        layout:include_helper(self)
        layout:render(self.buffer)
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
      if path and path:match("^%a+:") then
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
      if parsed.port == "80" then
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
          table.insert(self.buffer, thing)
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
      local extra = self.app.cookie_attributes
      if extra then
        extra = "; " .. table.concat(self.app.cookie_attributes, "; ")
      end
      for k, v in pairs(self.cookies) do
        local cookie = tostring(url.escape(k)) .. "=" .. tostring(url.escape(v)) .. "; Path=/; HttpOnly"
        if extra then
          cookie = cookie .. extra
        end
        self.res:add_header("Set-cookie", cookie)
      end
    end,
    _debug = function(self)
      self.buffer = {
        "<html>",
        "req:",
        "<pre>",
        moon.dump(self.req),
        "</pre>",
        "res:",
        "<pre>",
        moon.dump(self.res),
        "</pre>",
        "</html>"
      }
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
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
  local _base_0 = {
    Request = Request,
    layout = require("lapis.views.layout"),
    error_page = require("lapis.views.error"),
    views_prefix = "views",
    build_router = function(self)
      self.router = Router()
      self.router.default_route = function(self)
        return false
      end
      local add_routes
      add_routes = function(cls)
        for path, handler in pairs(cls.__base) do
          local t = type(path)
          if t == "table" or t == "string" and path:match("^/") then
            self.router:add_route(path, self:wrap_handler(handler))
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
          r:write(handler({ }, nil, "default_route", r))
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
      return res
    end,
    serve = function(self) end,
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
      local r = self.app.Request(self, self.req, self.res)
      r:write({
        status = 500,
        layout = false,
        content_type = "text/html",
        self.app.error_page({
          status = 500,
          err = err,
          trace = trace
        })
      })
      r:render()
      logger.request(r)
      return r
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
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
  self.before_filter = function(self, fn)
    self.__base.before_filters = self.__base.before_filters or { }
    return table.insert(self.before_filters, fn)
  end
  self.include = function(self, other_app, opts, into)
    if into == nil then
      into = self.__base
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
local respond_to
respond_to = function(tbl)
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
    error_response = fn.on_error
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
assert_error = function(thing, msg)
  if not (thing) then
    yield_error(msg)
  end
  return thing
end
return {
  Request = Request,
  Application = Application,
  respond_to = respond_to,
  capture_errors = capture_errors,
  capture_errors_json = capture_errors_json,
  assert_error = assert_error,
  yield_error = yield_error
}
