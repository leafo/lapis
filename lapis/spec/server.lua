local TEST_ENV = "test"
local normalize_headers
normalize_headers = require("lapis.spec.request").normalize_headers
local ltn12 = require("ltn12")
local json = require("cjson")
local parse_query_string, encode_query_string
do
  local _obj_0 = require("lapis.util")
  parse_query_string, encode_query_string = _obj_0.parse_query_string, _obj_0.encode_query_string
end
local current_server = nil
local load_test_server
load_test_server = function()
  local attach_server
  attach_server = require("lapis.cmd.nginx").attach_server
  local get_free_port
  get_free_port = require("lapis.cmd.util").get_free_port
  local app_port = get_free_port()
  current_server = attach_server(TEST_ENV, {
    port = app_port
  })
  current_server.app_port = app_port
  return current_server
end
local close_test_server
close_test_server = function()
  local detach_server
  detach_server = require("lapis.cmd.nginx").detach_server
  detach_server()
  current_server = nil
end
local get_current_server
get_current_server = function()
  return current_server
end
local request
request = function(path, opts)
  if path == nil then
    path = ""
  end
  if opts == nil then
    opts = { }
  end
  if not (current_server) then
    error("The test server is not loaded! (did you forget to load_test_server?)")
  end
  local http = require("socket.http")
  local headers = { }
  local method = opts.method
  local port = opts.port or current_server.app_port
  local source
  do
    local data = opts.post or opts.data
    if data then
      if opts.post then
        method = method or "POST"
      end
      if type(data) == "table" then
        headers["Content-type"] = "application/x-www-form-urlencoded"
        data = encode_query_string(data)
      end
      headers["Content-length"] = #data
      source = ltn12.source.string(data)
    end
  end
  local url_host, url_path = path:match("^https?://([^/]+)(.*)$")
  if url_host then
    headers.Host = url_host
    path = url_path
    do
      local override_port = url_host:match(":(%d+)$")
      if override_port then
        port = override_port
      end
    end
  end
  path = path:gsub("^/", "")
  if opts.get then
    local url_base, url_query = path:match("^(.-)%?(.*)$")
    local get_params
    if url_query then
      get_params = parse_query_string(url_query)
    else
      get_params = { }
    end
    for k, v in pairs(opts.get) do
      get_params[k] = v
    end
    path = path:gsub("^.-(%?.*)$", "") .. "?" .. encode_query_string(get_params)
  end
  if opts.headers then
    for k, v in pairs(opts.headers) do
      headers[k] = v
    end
  end
  local buffer = { }
  local res, status
  res, status, headers = http.request({
    url = "http://127.0.0.1:" .. tostring(port) .. "/" .. tostring(path),
    redirect = false,
    sink = ltn12.sink.table(buffer),
    headers = headers,
    method = method,
    source = source
  })
  assert(res, status)
  local body = table.concat(buffer)
  headers = normalize_headers(headers)
  if headers.x_lapis_error then
    json = require("cjson")
    local err, trace
    do
      local _obj_0 = json.decode(body)
      status, err, trace = _obj_0.status, _obj_0.err, _obj_0.trace
    end
    error("\n" .. tostring(status) .. "\n" .. tostring(err) .. "\n" .. tostring(trace))
  end
  if opts.expect == "json" then
    json = require("cjson")
    if not (pcall(function()
      body = json.decode(body)
    end)) then
      error("expected to get json from " .. tostring(path))
    end
  end
  return status, body, headers
end
return {
  load_test_server = load_test_server,
  close_test_server = close_test_server,
  get_current_server = get_current_server,
  request = request,
  run_on_server = run_on_server
}
