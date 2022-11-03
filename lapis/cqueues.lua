local http_headers = require("http.headers")
local parse_query_string
parse_query_string = require("lapis.util").parse_query_string
local filter_array
filter_array = function(t)
  if not (t) then
    return 
  end
  for k = #t, 1, -1 do
    t[k] = nil
  end
  return t
end
local headers_proxy_mt = {
  __index = function(self, name)
    return self[1]:get(name:lower())
  end,
  __tostring = function(self)
    return "<HeadersProxy>"
  end
}
local request_mt = {
  __index = function(self, name)
    return error("Request has no implementation for: " .. tostring(name))
  end
}
local build_request
build_request = function(stream)
  local req_headers = assert(stream:get_headers())
  local uri = req_headers:get(":path")
  local path, query = uri:match("^([^?]+)%?(.*)$")
  path = path or uri
  query = query and filter_array(parse_query_string(query)) or { }
  local method = req_headers:get(":method")
  local content_type = req_headers:get("content-type")
  local params_post
  if content_type == "application/x-www-form-urlencoded" then
    local body = stream:get_body_as_string():gsub("+", " ")
    params_post = body and filter_array(parse_query_string(body)) or { }
  end
  local h = req_headers:get(":authority")
  local host, port = h:match("^(.-):(%d+)$")
  host = host or h
  local scheme = stream:checktls() and "https" or "http"
  local family, remote_addr = stream:peername()
  return setmetatable({
    cmd_mth = method,
    cmd_url = uri,
    method = method,
    request_uri = uri,
    remote_addr = remote_addr,
    scheme = scheme,
    port = port,
    headers = setmetatable({
      req_headers
    }, headers_proxy_mt),
    read_body_as_string = function()
      return stream:get_body_as_string()
    end,
    params_get = query,
    params_post = params_post or { },
    parsed_url = {
      scheme = scheme,
      path = path,
      query = query,
      host = host,
      port = port
    }
  }, request_mt)
end
local build_response
build_response = function(stream)
  return {
    req = build_request(stream),
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
    headers = { }
  }
end
local protected_call
protected_call = function(stream, fn)
  local err, trace, r
  local capture_error
  capture_error = function(_err) end
  local success = xpcall(fn, function(_err)
    err = _err
    trace = debug.traceback("", 2)
  end)
  if success then
    return true
  end
  local req_headers = stream:get_headers()
  local logger = require("lapis.logging")
  logger.request({
    req = {
      method = req_headers:get(":method"),
      request_uri = req_headers:get(":path")
    },
    res = {
      status = "503"
    }
  })
  local full_error = table.concat({
    "App failed to boot:\n",
    err,
    trace
  }, "\n")
  io.stderr:write(full_error, "\n")
  local res_headers = http_headers.new()
  res_headers:append(":status", "503")
  local config = require("lapis.config").get()
  if config._name == "development" then
    res_headers:append("content-type", "text/plain")
    stream:write_headers(res_headers, false)
    stream:write_chunk(full_error, true)
  else
    stream:write_headers(res_headers, true)
  end
  return false
end
local dispatch
dispatch = function(app, server, stream)
  local res = build_response(stream)
  app:dispatch(res.req, res)
  local res_headers = http_headers.new()
  res_headers:append(":status", res.status and string.format("%d", res.status) or "200")
  for k, v in pairs(res.headers) do
    res_headers:append(k, v)
  end
  stream:write_headers(res_headers, not res.content)
  if res.content then
    stream:write_chunk(res.content, true)
  end
  return res
end
return {
  dispatch = dispatch,
  protected_call = protected_call
}
