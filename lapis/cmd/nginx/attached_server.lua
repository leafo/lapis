local path = require("lapis.cmd.path")
local debug_config_process
debug_config_process = function(cfg, port)
  local run_code_action = [[    ngx.req.read_body()

    -- hijack print to write to buffer
    local old_print = print

    local buffer = {}
    print = function(...)
      local str = table.concat({...}, "\t")
      io.stdout:write(str .. "\n")
      table.insert(buffer, str)
    end

    local success, err = pcall(loadstring(ngx.var.request_body))

    if not success then
      ngx.status = 500
      print(err)
    end

    ngx.print(table.concat(buffer, "\n"))
    print = old_print
  ]]
  run_code_action = run_code_action:gsub("\\", "\\\\"):gsub('"', '\\"')
  local test_server = [[    server {
      allow 127.0.0.1;
      deny all;
      listen ]] .. port .. [[;

      location = /run_lua {
        client_body_buffer_size 10m;
        client_max_body_size 10m;
        content_by_lua "
          ]] .. run_code_action .. [[
        ";
      }
    }
  ]]
  table.insert(test_server, "}")
  return cfg:gsub("%f[%a]http%s-{", "http { " .. table.concat(test_server, "\n"))
end
local AttachedServer
do
  local _base_0 = {
    wait_until = function(self, server_status)
      if server_status == nil then
        server_status = "open"
      end
      local socket = require("socket")
      local max_tries = 1000
      while true do
        local sock = socket.connect("127.0.0.1", self.port)
        local _exp_0 = server_status
        if "open" == _exp_0 then
          if sock then
            sock:close()
            break
          end
        elseif "close" == _exp_0 then
          if sock then
            sock:close()
          else
            break
          end
        else
          error("don't know how to wait for " .. tostring(server_status))
        end
        max_tries = max_tries - 1
        if max_tries == 0 then
          error("Timed out waiting for server to " .. tostring(server_status))
        end
        socket.sleep(0.001)
      end
    end,
    wait_until_ready = function(self)
      return self:wait_until("open")
    end,
    wait_until_closed = function(self)
      return self:wait_until("close")
    end,
    detach = function(self)
      if self.existing_config then
        path.write_file(self.runner.compiled_config_path, self.existing_config)
      end
      if self.fresh then
        self.runner:send_term()
        self:wait_until_closed()
      else
        self.runner:send_hup()
      end
      local env = require("lapis.environment")
      env.pop()
      return true
    end,
    query = function(self, q)
      local ltn12 = require("ltn12")
      local http = require("socket.http")
      local mime = require("mime")
      local json = require("cjson")
      local buffer = { }
      http.request({
        url = "http://127.0.0.1:" .. tostring(self.port) .. "/http_query",
        sink = ltn12.sink.table(buffer),
        headers = {
          ["x-query"] = mime.b64(q)
        }
      })
      return json.decode(table.concat(buffer))
    end,
    exec = function(self, lua_code)
      assert(loadstring(lua_code))
      local ltn12 = require("ltn12")
      local http = require("socket.http")
      local buffer = { }
      http.request({
        url = "http://127.0.0.1:" .. tostring(self.port) .. "/run_lua",
        sink = ltn12.sink.table(buffer),
        source = ltn12.source.string(lua_code),
        headers = {
          ["content-length"] = #lua_code
        }
      })
      return table.concat(buffer)
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, runner, opts)
      self.runner = runner
      for k, v in pairs(opts) do
        self[k] = v
      end
      local env = require("lapis.environment")
      return env.push(self.environment)
    end,
    __base = _base_0,
    __name = "AttachedServer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  AttachedServer = _class_0
end
return {
  AttachedServer = AttachedServer,
  debug_config_process = debug_config_process
}
