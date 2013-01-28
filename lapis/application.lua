local logger = require("lapis.logging")
local url = require("socket.url")
local json = require("cjson")
local session = require("lapis.session")
local Router
do
  local _table_0 = require("lapis.router")
  Router = _table_0.Router
end
local html_writer
do
  local _table_0 = require("lapis.html")
  html_writer = _table_0.html_writer
end
local parse_cookie_string
do
  local _table_0 = require("lapis.util")
  parse_cookie_string = _table_0.parse_cookie_string
end
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
local auto_table
auto_table = function(fn)
  return setmetatable({ }, {
    __index = function(self, name)
      local result = fn()
      setmetatable(self, {
        __index = result
      })
      return result[name]
    end
  })
end
local Request
do
  local _parent_0 = nil
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
      if self.options.json then
        self.res.headers["Content-type"] = "application/json"
        self.res.content = json.encode(self.options.json)
        return 
      end
      if not self.res.headers["Content-type"] then
        self.res.headers["Content-type"] = "text/html"
      end
      if self.options.redirect_to then
        self.res:add_header("Location", self:build_url(self.options.redirect_to))
        self.res.status = 302
      end
      if self.options.status then
        self.res.status = self.options.status
      end
      session.write_session(self)
      self:write_cookies()
      do
        local rpath = self.options.render
        if rpath then
          if rpath == true then
            rpath = self.route_name
          end
          local widget = require(tostring(self.app.views_prefix) .. "." .. tostring(rpath))
          local view = widget(self.options.locals)
          view:include_helper(self)
          self:write(view)
        end
      end
      if self.app.layout and set_and_truthy(self.options.layout, true) then
        local inner = self.buffer
        self.buffer = { }
        local layout = self.app.layout({
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
    url_for = function(self, ...)
      return self.app.router:url_for(...)
    end,
    build_url = function(self, path, options)
      local parsed = (function()
        local _tbl_0 = { }
        for k, v in pairs(self.req.parsed_url) do
          _tbl_0[k] = v
        end
        return _tbl_0
      end)()
      parsed.authority = nil
      if path and not path:match("^/") then
        path = "/" .. tostring(path)
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
      return url.build(parsed)
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
      local parts = (function()
        local _accum_0 = { }
        local _len_0 = 1
        for k, v in pairs(self.cookies) do
          _accum_0[_len_0] = tostring(url.escape(k)) .. "=" .. tostring(url.escape(v))
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)()
      return self.res:add_header("Set-cookie", table.concat(parts, "; "))
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
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, app, req, res)
      self.app, self.req, self.res = app, req, res
      self.buffer = { }
      self.params = { }
      self.options = { }
      self.cookies = auto_table(function()
        return parse_cookie_string(self.req.headers.cookie)
      end)
      self.session = auto_table(function()
        return session.get_session(self)
      end)
    end,
    __base = _base_0,
    __name = "Request",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Request = _class_0
end
local Application
do
  local _parent_0 = nil
  local _base_0 = {
    layout = require("lapis.views.layout"),
    error_page = require("lapis.views.error"),
    views_prefix = "views",
    before_filters = { },
    wrap_handler = function(self, handler)
      return function(params, path, name, r)
        do
          local _with_0 = r
          _with_0.route_name = name
          _with_0:add_params(r.req.params_get, "GET")
          _with_0:add_params(r.req.params_post, "POST")
          _with_0:add_params(params, "url_params")
          local _list_0 = self.before_filters
          for _index_0 = 1, #_list_0 do
            local filter = _list_0[_index_0]
            filter(r)
          end
          _with_0:write(handler(r))
          return _with_0
        end
      end
    end,
    dispatch = function(self, req, res)
      local err, trace
      local success = xpcall((function()
        local r = Request(self, req, res)
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
        local r = Request(self, req, res)
        r:write({
          status = 500,
          layout = false,
          self.error_page({
            staus = 500,
            err = err,
            trace = trace
          })
        })
        r:render()
        logger.request(r)
      end
      return res
    end,
    serve = function(self) end,
    default_route = function(self)
      if self.req.cmd_url:match("./$") then
        local stripped = self.req.cmd_url:match("^(.+)/+$")
        return {
          redirect_to = stripped,
          status = 301
        }
      else
        return error("Failed to find route: " .. tostring(self.req.cmd_url))
      end
    end
  }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self)
      self.router = Router()
      self.router.default_route = function(self)
        return false
      end
      do
        local _with_0 = require("lapis.server")
        self.__class.__base["/static/*"] = _with_0.make_static_handler("static")
        self.__class.__base["/favicon.ico"] = _with_0.serve_from_static()
      end
      for path, handler in pairs(self.__class.__base) do
        local t = type(path)
        if t == "table" or t == "string" and path:match("^/") then
          self.router:add_route(path, self:wrap_handler(handler))
        end
      end
    end,
    __base = _base_0,
    __name = "Application",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
        return _parent_0[name]
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  local self = _class_0
  self.before_filter = function(self, fn)
    return table.insert(self.before_filters, fn)
  end
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Application = _class_0
end
local respond_to
respond_to = function(tbl)
  return function(self)
    local fn = tbl[self.req.cmd_mth]
    if fn then
      do
        local before = tbl.before
        if before then
          before(self)
        end
      end
      return fn(self)
    else
      return error("don't know how to respond to " .. tostring(self.req.cmd_mth))
    end
  end
end
local default_error_response
default_error_response = function()
  return {
    render = true
  }
end
local capture_errors
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
local capture_errors_json
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
