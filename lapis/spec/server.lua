local TEST_ENV = "test"
local normalize_headers
do
  local _obj_0 = require("lapis.spec.request")
  normalize_headers = _obj_0.normalize_headers
end
local ltn12 = require("ltn12")
local json = require("cjson")
local server_loaded = 0
local current_server = nil
local load_test_server
load_test_server = function()
  server_loaded = server_loaded + 1
  if not (server_loaded == 1) then
    return 
  end
  local attach_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    attach_server = _obj_0.attach_server
  end
  local get_free_port
  do
    local _obj_0 = require("lapis.cmd.util")
    get_free_port = _obj_0.get_free_port
  end
  local port = get_free_port()
  current_server = attach_server(TEST_ENV, {
    port = port
  })
  current_server.app_port = port
  return current_server
end
local close_test_server
close_test_server = function()
  server_loaded = server_loaded - 1
  if not (server_loaded == 0) then
    return 
  end
  current_server:detach()
  current_server = nil
end
local request
request = function(path, opts)
  if path == nil then
    path = ""
  end
  if opts == nil then
    opts = { }
  end
  if not (server_loaded > 0) then
    error("The test server is not loaded!")
  end
  local http = require("socket.http")
  local headers = { }
  local method = opts.method
  local source
  do
    local data = opts.post or opts.data
    if data then
      if opts.post then
        method = method or "POST"
      end
      if type(data) == "table" then
        local encode_query_string
        do
          local _obj_0 = require("lapis.util")
          encode_query_string = _obj_0.encode_query_string
        end
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
  end
  path = path:gsub("^/", "")
  if opts.headers then
    for k, v in pairs(opts.headers) do
      headers[k] = v
    end
  end
  local buffer = { }
  local res, status
  res, status, headers = http.request({
    url = "http://127.0.0.1:" .. tostring(current_server.app_port) .. "/" .. tostring(path),
    redirect = false,
    sink = ltn12.sink.table(buffer),
    headers = headers,
    method = method,
    source = source
  })
  assert(res, status)
  return status, table.concat(buffer), normalize_headers(headers)
end
return {
  load_test_server = load_test_server,
  close_test_server = close_test_server,
  request = request,
  run_on_server = run_on_server
}
