local unpack = unpack or table.unpack
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
local add_cookie
add_cookie = function(headers, name, val)
  local escape
  escape = require("lapis.util").escape
  local assign = tostring(escape(name)) .. "=" .. tostring(escape(val))
  do
    local old = headers.Cookie
    if old then
      headers.Cookie = tostring(old) .. "; " .. tostring(assign)
    else
      headers.Cookie = assign
    end
  end
end
local extract_cookies
extract_cookies = function(response_headers)
  local set_cookies = response_headers.set_cookie
  if not (set_cookies) then
    return 
  end
  if type(set_cookies) == "string" then
    set_cookies = {
      set_cookies
    }
  end
  local parsed_cookies = { }
  for _index_0 = 1, #set_cookies do
    local cookie_header = set_cookies[_index_0]
    local parse_cookie_string
    parse_cookie_string = require("lapis.util").parse_cookie_string
    local tmp = parse_cookie_string(cookie_header)
    local set_name = cookie_header:match("[^=]+")
    parsed_cookies[set_name] = tmp[set_name]
  end
  return parsed_cookies
end
local mock_request
mock_request = function(app_cls, url, opts)
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
  local request_method = opts.method or (opts.post and "POST") or "GET"
  local scheme = opts.scheme or "http"
  local server_port = opts.port or 80
  local http_host = host
  if not (server_port == 80) then
    http_host = http_host .. ":" .. tostring(server_port)
  end
  local prev_request = normalize_headers(opts.prev or { })
  local headers = {
    Host = host,
    Cookie = prev_request.set_cookie
  }
  if opts.cookies then
    for k, v in pairs(opts.cookies) do
      add_cookie(headers, k, v)
    end
  end
  if opts.post then
    headers["Content-type"] = "application/x-www-form-urlencoded"
  end
  if opts.session then
    local config = require("lapis.config").get()
    local encode_session
    encode_session = require("lapis.session").encode_session
    add_cookie(headers, config.session_name, encode_session(opts.session))
  end
  if opts.headers then
    for k, v in pairs(opts.headers) do
      headers[k] = v
    end
  end
  headers = normalize_headers(headers)
  local out_headers = { }
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
  local hex
  hex = function(str)
    return (str:gsub(".", function(c)
      return string.format("%02x", string.byte(c))
    end))
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
    md5 = function(str)
      local digest = require("openssl.digest")
      return hex((digest.new("md5")):final(str))
    end,
    header = out_headers,
    now = function()
      return os.time()
    end,
    update_time = function()
      return os.time()
    end,
    time = function()
      return os.time()
    end,
    get_phase = function()
      return "init"
    end,
    ctx = { },
    var = setmetatable({
      host = host,
      http_host = http_host,
      request_method = request_method,
      request_uri = request_uri,
      scheme = scheme,
      server_port = server_port,
      args = url_query,
      query_string = url_query,
      remote_addr = "127.0.0.1",
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
      get_body_data = function()
        return opts.body or opts.post and encode_query_string(opts.post) or nil
      end,
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
        if opts.post then
          return opts.post
        end
        if opts.body and headers["Content-type"] == "application/x-www-form-urlencoded" then
          do
            local args = parse_query_string(opts.body)
            if args then
              local _tbl_0 = { }
              for k, v in pairs(args) do
                if type(k) == "string" then
                  _tbl_0[k] = v
                end
              end
              return _tbl_0
            end
          end
        end
        return { }
      end
    },
    location = {
      capture = function()
        return {
          status = 200,
          header = { },
          body = ""
        }
      end,
      capture_multi = function(args)
        local _accum_0 = { }
        local _len_0 = 1
        for i = 1, #args do
          _accum_0[_len_0] = {
            status = 200,
            header = { },
            body = ""
          }
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end
    }
  })
  local app = app_cls.__base and app_cls() or app_cls
  if not (app.router) then
    app:build_router()
  end
  local response = nginx.dispatch(app)
  stack.pop()
  logger.request = old_logger
  out_headers = normalize_headers(out_headers)
  local body = concat(buffer)
  if not (opts.allow_error) then
    do
      local error_blob = out_headers.x_lapis_error
      if error_blob then
        local json = require("cjson")
        local summary, err, trace
        do
          local _obj_0 = json.decode(error_blob)
          summary, err, trace = _obj_0.summary, _obj_0.err, _obj_0.trace
        end
        error("\n" .. tostring(summary) .. "\n" .. tostring(err) .. "\n" .. tostring(trace))
      end
    end
  end
  if opts.expect == "json" then
    local json = require("cjson")
    if not (pcall(function()
      body = json.decode(body)
    end)) then
      error("expected to get json from " .. tostring(url))
    end
  end
  return response.status or 200, body, out_headers
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
local mock_action
mock_action = function(app_cls, url, opts, fn)
  if type(url) == "function" and opts == nil then
    fn = url
    url = "/"
    opts = { }
  end
  if type(opts) == "function" and fn == nil then
    fn = opts
    opts = { }
  end
  local ret
  local handler
  handler = function(...)
    ret = {
      fn(...)
    }
    return {
      layout = false
    }
  end
  local A
  do
    local _class_0
    local _parent_0 = app_cls
    local _base_0 = {
      ["/*"] = handler,
      ["/"] = handler
    }
    _base_0.__index = _base_0
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
      __init = function(self, ...)
        return _class_0.__parent.__init(self, ...)
      end,
      __base = _base_0,
      __name = "A",
      __parent = _parent_0
    }, {
      __index = function(cls, name)
        local val = rawget(_base_0, name)
        if val == nil then
          local parent = rawget(cls, "__parent")
          if parent then
            return parent[name]
          end
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
    if _parent_0.__inherited then
      _parent_0.__inherited(_parent_0, _class_0)
    end
    A = _class_0
  end
  assert_request(A, url, opts)
  return unpack(ret)
end
local stub_request
stub_request = function(app_cls, url, opts)
  if url == nil then
    url = "/"
  end
  if opts == nil then
    opts = { }
  end
  local stub
  local app = app_cls()
  app.dispatch = function(self, req, res)
    stub = self.Request(self, req, res)
  end
  mock_request(app, url, opts)
  return stub
end
return {
  mock_request = mock_request,
  assert_request = assert_request,
  normalize_headers = normalize_headers,
  mock_action = mock_action,
  stub_request = stub_request,
  extract_cookies = extract_cookies
}
