local url = require("socket.url")
local ngx_req = {
  headers = function()
    return ngx.req.get_headers()
  end,
  cmd_mth = function()
    return ngx.var.request_method
  end,
  cmd_url = function()
    return ngx.var.request_uri
  end,
  relpath = function()
    return url.unescape(ngx.var.uri)
  end,
  scheme = function()
    return ngx.var.scheme
  end,
  port = function()
    return ngx.var.server_port
  end,
  srv = function()
    return ngx.var.server_addr
  end,
  parsed_url = function(t)
    return url.parse(tostring(t.scheme) .. "://" .. tostring(ngx.var.http_host) .. tostring(t.cmd_url))
  end,
  built_url = function(t)
    return url.build(t.parsed_url)
  end
}
local lazy_tbl
lazy_tbl = function(tbl, index)
  return setmetatable(tbl, {
    __index = function(self, key)
      local fn = index[key]
      if fn then
        do
          local _with_0 = fn(self)
          local res = _with_0
          self[key] = res
          return _with_0
        end
      end
    end
  })
end
local build_request
build_request = function(unlazy)
  if unlazy == nil then
    unlazy = false
  end
  do
    local _with_0 = lazy_tbl({ }, ngx_req)
    local t = _with_0
    if unlazy then
      for k in pairs(ngx_req) do
        local _ = t[k]
      end
    end
    return _with_0
  end
end
local build_response
build_response = function()
  return {
    req = build_request(),
    add_header = function(self, k, v)
      local old = self.headers[k]
      local _exp_0 = type(old)
      if "nil" == _exp_0 then
        self.headers[k] = v
      elseif "table" == _exp_0 then
        old[#old + 1] = v
      else
        self.headers[k] = {
          old,
          v
        }
      end
    end,
    headers = ngx.header
  }
end
local dispatch
dispatch = function(app)
  local res = build_response()
  app:dispatch(res.req, res)
  ngx.say(res.content)
  return res
end
return {
  build_request = build_request,
  build_response = build_response,
  dispatch = dispatch
}
