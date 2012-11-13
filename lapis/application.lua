local logger = require("lapis.logging")
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
local Request
do
  local _parent_0 = nil
  local _base_0 = {
    add_params = function(self, params, name)
      self[name] = params
      for k, v in pairs(params) do
        self.params[k] = v
      end
    end,
    render = function(self)
      if not self.res.headers["Content-type"] then
        self.res.headers["Content-type"] = "text/html"
      end
      if self.app.layout and set_and_truthy(self.options.layout, true) then
        local inner = self.buffer
        self.buffer = { }
        local layout = self.app.layout({
          inner = function()
            return raw(inner)
          end
        })
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
    write = function(self, thing)
      local t = type(thing)
      if t == "table" then
        local mt = getmetatable(thing)
        if mt and mt.__call then
          t = "function"
        end
      end
      local _exp_0 = t
      if "string" == _exp_0 then
        return table.insert(self.buffer, thing)
      elseif "table" == _exp_0 then
        for k, v in pairs(thing) do
          if type(k) == "string" then
            self.options[k] = v
          else
            self:write(v)
          end
        end
      elseif "function" == _exp_0 then
        return self:write(thing(self.buffer))
      elseif "nil" == _exp_0 then
        return nil
      else
        return error("Don't know how to write:", tostring(thing))
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
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, app, req, res)
      self.app, self.req, self.res = app, req, res
      self.buffer = { }
      self.params = { }
      self.options = { }
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
    layout = require("lapis.layout").Default,
    wrap_handler = function(self, handler)
      return function(params, path, name, r)
        do
          local _with_0 = r
          _with_0.route_name = name
          _with_0:add_params(r.req.params_get, "GET")
          _with_0:add_params(r.req.params_post, "POST")
          _with_0:add_params(params, "url_params")
          _with_0:write(handler(r))
          return _with_0
        end
      end
    end,
    dispatch = function(self, req, res)
      local r = Request(self, req, res)
      self.router:resolve(req.parsed_url.path, r)
      r:render()
      logger.request(r)
      return res
    end,
    serve = function(self) end
  }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self)
      self.router = Router()
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
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Application = _class_0
end
return {
  Request = Request,
  Application = Application
}
