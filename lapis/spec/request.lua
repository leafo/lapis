local normalize_headers
do
  local normalize
  normalize = function(header)
    return header:lower():gsub("-", "_")
  end
  normalize_headers = function(t)
    return setmetatable((function()
      local _tbl_0 = { }
      for k, v in pairs(t) do
        _tbl_0[normalize(k)] = v
      end
      return _tbl_0
    end)(), {
      __index = function(self, name)
        return rawget(self, normalize(name))
      end
    })
  end
end
local mock_request
mock_request = function(app, url, opts)
  if opts == nil then
    opts = { }
  end
  local stack = require("lapis.spec.stack")
  local parse_query_string, encode_query_string
  do
    local _obj_0 = require("lapis.util")
    parse_query_string, encode_query_string = _obj_0.parse_query_string, _obj_0.encode_query_string
  end
  local insert, concat
  do
    local _obj_0 = table
    insert, concat = _obj_0.insert, _obj_0.concat
  end
  local logger = require("lapis.logging")
  local old_logger = logger.request
  logger.request = function() end
  local url_base, url_query = url:match("^(.-)%?(.*)$")
  if not (url_base) then
    url_base = url
  end
  local get_params
  if url_query then
    get_params = parse_query_string(url_query)
  else
    get_params = { }
  end
  if opts.get then
    for k, v in pairs(opts.get) do
      if type(k) == "number" then
        insert(get_params, v)
      else
        get_params[k] = v
      end
    end
  end
  for k, v in pairs(get_params) do
    if type(v) == "table" then
      get_params[v[1]] = nil
    end
  end
  url_query = encode_query_string(get_params)
  local request_uri = url_base
  if url_query == "" then
    url_query = nil
  else
    request_uri = request_uri .. ("?" .. url_query)
  end
  local host = opts.host or "localhost"
  local request_method = opts.method or "GET"
  local scheme = opts.scheme or "http"
  local server_port = opts.port or 80
  local prev_request = normalize_headers(opts.prev or { })
  local headers = {
    Host = host,
    Cookie = prev_request.set_cookie
  }
  if opts.headers then
    for k, v in pairs(opts.headers) do
      headers[k] = v
    end
  end
  headers = normalize_headers(headers)
  local out_headers = { }
  local old_ngx = ngx
  local nginx = require("lapis.nginx")
  local buffer = { }
  local flatten
  flatten = function(tbl, accum)
    if accum == nil then
      accum = { }
    end
    for _index_0 = 1, #tbl do
      local thing = tbl[_index_0]
      if type(thing) == "table" then
        flatten(thing, accum)
      else
        insert(accum, thing)
      end
    end
    return accum
  end
  stack.push({
    print = function(...)
      local args = flatten({
        ...
      })
      local str
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #args do
          local a = args[_index_0]
          _accum_0[_len_0] = tostring(a)
          _len_0 = _len_0 + 1
        end
        str = _accum_0
      end
      for _index_0 = 1, #args do
        local a = args[_index_0]
        insert(buffer, a)
      end
      return true
    end,
    say = function(...)
      ngx.print(...)
      return ngx.print("\n")
    end,
    header = out_headers,
    var = setmetatable({
      host = host,
      request_method = request_method,
      request_uri = request_uri,
      scheme = scheme,
      server_port = server_port,
      args = url_query,
      query_string = url_query,
      uri = url_base
    }, {
      __index = function(self, name)
        do
          local header_name = name:match("^http_(.+)")
          if header_name then
            return headers[header_name]
          end
        end
      end
    }),
    req = {
      read_body = function() end,
      get_headers = function()
        return headers
      end,
      get_uri_args = function()
        local out = { }
        local add_arg
        add_arg = function(k, v)
          do
            local current = out[k]
            if current then
              if type(current) == "table" then
                return insert(current, v)
              else
                out[k] = {
                  current,
                  v
                }
              end
            else
              out[k] = v
            end
          end
        end
        for k, v in pairs(get_params) do
          if type(v) == "table" then
            add_arg(unpack(v))
          else
            add_arg(k, v)
          end
        end
        return out
      end,
      get_post_args = function()
        return opts.post or { }
      end
    }
  })
  local response = nginx.dispatch(app)
  stack.pop()
  logger.request = old_logger
  return response.status or 200, concat(buffer), out_headers
end
local assert_request
assert_request = function(...)
  local res = {
    mock_request(...)
  }
  if res[1] == 500 then
    assert(false, "Request failed: " .. res[2])
  end
  return unpack(res)
end
return {
  mock_request = mock_request,
  assert_request = assert_request,
  normalize_headers = normalize_headers
}
