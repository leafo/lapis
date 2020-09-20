local escape_pattern, parse_content_disposition, build_url
do
  local _obj_0 = require("lapis.util")
  escape_pattern, parse_content_disposition, build_url = _obj_0.escape_pattern, _obj_0.parse_content_disposition, _obj_0.build_url
end
local run_after_dispatch
run_after_dispatch = require("lapis.nginx.context").run_after_dispatch
local lapis_config = require("lapis.config")
local unpack = unpack or table.unpack
local flatten_params
flatten_params = function(t)
  local _tbl_0 = { }
  for k, v in pairs(t) do
    _tbl_0[k] = type(v) == "table" and v[#v] or v
  end
  return _tbl_0
end
local parse_multipart
parse_multipart = function()
  local out = { }
  local upload = require("resty.upload")
  local input, err = upload:new(1024 * 4)
  if not (input) then
    return nil, err
  end
  input:set_timeout(5000)
  local current = {
    content = { }
  }
  while true do
    local t, res
    t, res, err = input:read()
    local _exp_0 = t
    if "body" == _exp_0 then
      table.insert(current.content, res)
    elseif "header" == _exp_0 then
      if not (type(res) == "table") then
        return nil, err or "failed to read upload header"
      end
      local name, value = unpack(res)
      if name:lower() == "content-disposition" then
        do
          local params = parse_content_disposition(value)
          if params then
            for _index_0 = 1, #params do
              local tuple = params[_index_0]
              current[tuple[1]] = tuple[2]
            end
          end
        end
      else
        current[name:lower()] = value
      end
    elseif "part_end" == _exp_0 then
      current.content = table.concat(current.content)
      if current.name then
        if current["content-type"] then
          out[current.name] = current
        else
          out[current.name] = current.content
        end
      end
      current = {
        content = { }
      }
    elseif "eof" == _exp_0 then
      break
    else
      return nil, err or "failed to read upload"
    end
  end
  return out
end
local ngx_req = {
  referer = function()
    return ngx.var.http_referer or ""
  end,
  cmd_mth = function()
    return ngx.var.request_method
  end,
  cmd_url = function()
    return ngx.var.request_uri
  end,
  relpath = function(t)
    return t.parsed_url.path
  end,
  srv = function()
    return ngx.var.server_addr
  end,
  built_url = function(t)
    return build_url(t.parsed_url)
  end,
  headers = function()
    return ngx.req.get_headers()
  end,
  method = function()
    return ngx.var.request_method
  end,
  scheme = function()
    return ngx.var.scheme
  end,
  port = function()
    return ngx.var.server_port
  end,
  server_addr = function()
    return ngx.var.server_addr
  end,
  remote_addr = function()
    return ngx.var.remote_addr
  end,
  request_uri = function()
    return ngx.var.request_uri
  end,
  read_body_as_string = function()
    return function(self)
      ngx.req.read_body()
      return ngx.req.get_body_data()
    end
  end,
  parsed_url = function(t)
    local uri = ngx.var.request_uri
    local pos = uri:find("?")
    uri = pos and uri:sub(1, pos - 1) or uri
    local host_header = ngx.var.http_host
    return {
      scheme = ngx.var.scheme,
      path = uri,
      host = ngx.var.host,
      port = host_header and host_header:match(":(%d+)$"),
      query = ngx.var.args
    }
  end,
  params_post = function(t)
    local content_type = t.headers["content-type"] or ""
    if not (type(content_type) == "string") then
      content_type = ""
    end
    content_type = content_type:lower()
    local params
    if content_type:match(escape_pattern("multipart/form-data")) then
      params = parse_multipart()
    elseif content_type:match(escape_pattern("application/x-www-form-urlencoded")) then
      ngx.req.read_body()
      local args
      do
        local max = lapis_config.get().max_request_args
        if max then
          args = ngx.req.get_post_args(max)
        else
          args = ngx.req.get_post_args()
        end
      end
      if args then
        params = flatten_params(args)
      end
    end
    return params or { }
  end,
  params_get = function()
    local args
    do
      local max = lapis_config.get().max_request_args
      if max then
        args = ngx.req.get_uri_args(max)
      else
        args = ngx.req.get_uri_args()
      end
    end
    if args then
      return flatten_params(args)
    else
      return { }
    end
  end
}
local lazy_tbl
lazy_tbl = function(tbl, index)
  return setmetatable(tbl, {
    __index = function(self, key)
      local fn = index[key]
      if fn then
        do
          local res = fn(self)
          self[key] = res
          return res
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
    local t = lazy_tbl({ }, ngx_req)
    if unlazy then
      for k in pairs(ngx_req) do
        local _ = t[k]
      end
    end
    return t
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
        self.headers[k] = old
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
  if res.status then
    ngx.status = res.status
  end
  if res.content then
    ngx.print(res.content)
  end
  run_after_dispatch()
  return res
end
return {
  build_request = build_request,
  build_response = build_response,
  dispatch = dispatch
}
