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
local build_request
build_request = function(stream)
  local req_headers = assert(stream:get_headers())
  local url = req_headers:get(":path")
  local path, query = url:match("^([^?]+)%?(.*)$")
  path = path or url
  query = query and filter_array(parse_query_string(query)) or { }
  local method = req_headers:get(":method")
  local body = stream:get_body_as_string():gsub("+", " ")
  local post = body and filter_array(parse_query_string(body)) or { }
  return setmetatable({
    body = body,
    cmd_mth = method,
    cmd_url = url,
    params_get = query,
    params_post = post,
    parsed_url = {
      scheme = "http",
      path = path,
      query = query,
      host = req_headers:get("host"),
      port = "8080"
    }
  }, {
    __index = function(self, name)
      return print("Getting", name)
    end
  })
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
local dispatch
dispatch = function(app, server, stream)
  local res = build_response(stream)
  app:dispatch(res.req, res)
  local res_headers = http_headers.new()
  res_headers:append(":status", res.status and tostring(res.status) or "200")
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
  dispatch = dispatch
}
