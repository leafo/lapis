local TEST_ENV = "test"
local normalize_headers
do
  local _obj_0 = require("lapis.spec.request")
  normalize_headers = _obj_0.normalize_headers
end
local ltn12 = require("ltn12")
local json = require("cjson")
local server_loaded = 0
local server_port = nil
local load_test_server
load_test_server = function()
  server_loaded = server_loaded + 1
  if not (server_loaded == 1) then
    return 
  end
  local push_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    push_server = _obj_0.push_server
  end
  local server = assert(push_server(TEST_ENV), "Failed to start test server")
  server_port = server.port
end
local close_test_server
close_test_server = function()
  server_loaded = server_loaded - 1
  if not (server_loaded == 0) then
    return 
  end
  local pop_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    pop_server = _obj_0.pop_server
  end
  return pop_server()
end
local request
request = function(url)
  if not (server_loaded > 0) then
    error("The test server is not loaded!")
  end
  local http = require("socket.http")
  local buffer = { }
  local res, status, headers = http.request({
    url = "http://127.0.0.1:" .. tostring(server_port) .. "/" .. tostring(url or ""),
    redirect = false,
    sink = ltn12.sink.table(buffer)
  })
  return table.concat(buffer), status, normalize_headers(headers)
end
local run_on_server
run_on_server = function(fn)
  local execute_on_server
  do
    local _obj_0 = require("lapis.cmd.nginx")
    execute_on_server = _obj_0.execute_on_server
  end
  local encoded = ("%q"):format(string.dump(fn))
  return execute_on_server("\n    local json = require 'cjson'\n    local fn = loadstring(" .. tostring(encoded) .. ")\n    ngx.print(json.encode({fn()}))\n  ", TEST_ENV)
end
return {
  load_test_server = load_test_server,
  close_test_server = close_test_server,
  request = request,
  run_on_server = run_on_server
}
