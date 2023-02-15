local url = require("socket.url")
local lapis_config = require("lapis.config")
local session = require("lapis.session")
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
local get_time
get_time = function(config)
  if ngx then
    ngx.update_time()
    return ngx.now()
  elseif config.server == "cqueues" then
    return require("cqueues").monotime()
  end
end
local Request
do
  local _class_0
  local _base_0 = {
    flow = function(self, flow)
      local key = "_flow_" .. tostring(flow)
      if not (self[key]) then
        self[key] = require(tostring(self.app.flows_prefix) .. "." .. tostring(flow))(self)
      end
      return self[key]
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
      local parsed = self.__class.support.default_url_params(self)
      if path then
        local _path, query = path:match("^(.-)%?(.*)$")
        path = _path or path
        parsed.query = query
      end
      parsed.path = path
      local scheme = parsed.scheme or "http"
      if scheme == "http" and (parsed.port == "80" or parsed.port == 80) then
        parsed.port = nil
      end
      if scheme == "https" and (parsed.port == "443" or parsed.port == 443) then
        parsed.port = nil
      end
      if options then
        for k, v in pairs(options) do
          parsed[k] = v
        end
      end
      return build_url(parsed)
    end,
    get_request = function(self)
      return self
    end,
    write = function(self, thing, ...)
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
      if ... then
        return self:write(...)
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
      self.__class.support.load_cookies(self)
      return self.__class.support.load_session(self)
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
  local self = _class_0
  self.__inherited = function(self, child)
    do
      local support = rawget(child, "support")
      if support then
        if getmetatable(support) then
          return 
        end
        return setmetatable(support, {
          __index = self.support
        })
      end
    end
  end
  self.support = {
    default_url_params = function(self)
      local parsed
      do
        local _tbl_0 = { }
        for k, v in pairs(self.req.parsed_url) do
          _tbl_0[k] = v
        end
        parsed = _tbl_0
      end
      parsed.query = nil
      return parsed
    end,
    append_content_for = function(self, name, value)
      local CONTENT_FOR_PREFIX
      CONTENT_FOR_PREFIX = require("lapis.html").CONTENT_FOR_PREFIX
      local full_name = CONTENT_FOR_PREFIX .. name
      local existing = self[full_name]
      local _exp_0 = type(existing)
      if "nil" == _exp_0 then
        self[full_name] = value
      elseif "table" == _exp_0 then
        table.insert(self[full_name], value)
      else
        self[full_name] = {
          existing,
          value
        }
      end
    end,
    load_cookies = function(self)
      self.cookies = auto_table(function()
        local cookie = self.req.headers.cookie
        if type(cookie) == "table" then
          local out = { }
          for _index_0 = 1, #cookie do
            local str = cookie[_index_0]
            for k, v in pairs(parse_cookie_string(str)) do
              out[k] = v
            end
          end
          return out
        else
          return parse_cookie_string(cookie)
        end
      end)
    end,
    load_session = function(self)
      self.session = session.lazy_session(self)
    end,
    render = function(self)
      if self.options.skip_render then
        return 
      end
      self.__class.support.write_session(self)
      self.__class.support.write_cookies(self)
      if self.options.status then
        self.res.status = self.options.status
      end
      if self.options.headers then
        for k, v in pairs(self.options.headers) do
          self.res:add_header(k, v)
        end
      end
      if self.options.json ~= nil then
        self.res.headers["Content-Type"] = self.options.content_type or "application/json"
        self.res.content = to_json(self.options.json)
        self.options.layout = false
        return 
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
          self.options.layout = false
          return 
        end
      end
      if self.options.layout == nil then
        self.options.layout = self.app.layout
      end
      if self.options.layout then
        self.layout_opts = { }
      end
      local widget_cls = self.options.render
      if widget_cls == true then
        widget_cls = self.route_name
      end
      local config = lapis_config.get()
      local view_widget
      if widget_cls then
        if type(widget_cls) == "string" then
          widget_cls = require(tostring(self.app.views_prefix) .. "." .. tostring(widget_cls))
        end
        local start_time
        if config.measure_performance then
          start_time = get_time(config)
        end
        view_widget = widget_cls()
        view_widget:include_helper(self)
        self:write(view_widget)
        if self.layout_opts then
          self.layout_opts.view_widget = view_widget
        end
        if start_time then
          local t = get_time(config)
          increment_perf("view_time", t - start_time)
        end
      end
      do
        local layout = self.options.layout
        if layout then
          self._content_for_inner = self.buffer
          self.buffer = { }
          local layout_cls
          if type(layout) == "string" then
            layout_cls = require(tostring(self.app.views_prefix) .. "." .. tostring(layout))
          else
            layout_cls = layout
          end
          local start_time
          if config.measure_performance then
            start_time = get_time(config)
          end
          layout = layout_cls(self.layout_opts)
          layout:include_helper(self)
          layout:render(self.buffer)
          if start_time then
            local t = get_time(config)
            increment_perf("layout_time", t - start_time)
          end
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
    write_session = session.write_session,
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
    end,
    add_params = function(self, params, name)
      if name then
        self[name] = params
      end
      for k, v in pairs(params) do
        local front
        if type(k) == "string" then
          front = k:match("^([^%[]+)%[")
        end
        if front then
          local curr = self.params
          local has_nesting = false
          for match in k:gmatch("%[([^%]]+)%]") do
            has_nesting = true
            local new = curr[front]
            if type(new) ~= "table" then
              new = { }
              curr[front] = new
            end
            curr = new
            front = match
          end
          if has_nesting then
            curr[front] = v
          else
            self.params[k] = v
          end
        else
          self.params[k] = v
        end
      end
    end
  }
  Request = _class_0
  return _class_0
end
