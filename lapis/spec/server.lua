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
request = function(url, opts)
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
  local buffer = { }
  local res, status
  res, status, headers = http.request({
    url = "http://127.0.0.1:" .. tostring(server_port) .. "/" .. tostring(url or ""),
    redirect = false,
    sink = ltn12.sink.table(buffer),
    headers = headers,
    method = method,
    source = source
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
  local res, code, headers = execute_on_server("\n    local logger = require 'lapis.logging'\n    local json = require 'cjson'\n\n    local queries = {}\n\n    local old_log = logger.query\n    logger.query = function(q)\n      local old_print = print\n      print = function(...)\n        local buff = {...}\n        io.stdout:write(table.concat(buff, '\\t') .. '\\n')\n      end\n      old_log(q)\n      print = old_print\n      table.insert(queries, q)\n    end\n\n    local fn = loadstring(" .. tostring(encoded) .. ")\n    local res = {fn()}\n    ngx.header.x_queries = json.encode(queries)\n    ngx.print(json.encode(res))\n  ", TEST_ENV)
  if code ~= 200 then
    error(res)
  end
  return unpack(json.decode(res))
end
return {
  load_test_server = load_test_server,
  close_test_server = close_test_server,
  request = request,
  run_on_server = run_on_server
}
