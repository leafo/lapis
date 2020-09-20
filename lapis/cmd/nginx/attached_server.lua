local path = require("lapis.cmd.path")
local get_free_port
get_free_port = require("lapis.cmd.util").get_free_port
local loadstring = loadstring or load
local AttachedServer
AttachedServer = require("lapis.cmd.attached_server").AttachedServer
local NginxAttachedServer
do
  local _class_0
  local _parent_0 = AttachedServer
  local _base_0 = {
    start = function(self, environment, env_overrides)
      if path.exists(self.runner.compiled_config_path) then
        self.existing_config = path.read_file(self.runner.compiled_config_path)
      end
      self.port = get_free_port()
      if type(environment) == "string" then
        environment = require("lapis.config").get(environment)
      end
      if env_overrides then
        assert(not getmetatable(env_overrides), "env_overrides already has metatable, aborting")
        environment = setmetatable(env_overrides, {
          __index = environment
        })
      end
      local env = require("lapis.environment")
      env.push(environment)
      self.runner:write_config_for(environment, (function()
        local _base_1 = self
        local _fn_0 = _base_1.process_config
        return function(...)
          return _fn_0(_base_1, ...)
        end
      end)())
      local pid = self.runner:get_pid()
      self.fresh = not pid
      if pid then
        self.runner:send_hup()
      else
        assert(self.runner:start_nginx(true))
      end
      return self:wait_until_ready()
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
    exec = function(self, lua_code)
      assert(loadstring(lua_code))
      local ltn12 = require("ltn12")
      local http = require("socket.http")
      local buffer = { }
      local _, status = http.request({
        url = "http://127.0.0.1:" .. tostring(self.port) .. "/run_lua",
        sink = ltn12.sink.table(buffer),
        source = ltn12.source.string(lua_code),
        headers = {
          ["content-length"] = #lua_code
        }
      })
      if not (status == 200) then
        error("Failed to exec code on server, got: " .. tostring(status) .. "\n\n" .. tostring(table.concat(buffer)))
      end
      return table.concat(buffer)
    end,
    process_config = function(self, cfg)
      assert(self.port, "attached server doesn't have a port to bind rpc to")
      local run_code_action = [[      ngx.req.read_body()

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
      local test_server = [[      server {
        allow 127.0.0.1;
        deny all;
        listen ]] .. self.port .. [[;

        location = /run_lua {
          client_body_buffer_size 10m;
          client_max_body_size 10m;
          content_by_lua "
            ]] .. run_code_action .. [[
          ";
        }
      }
    ]]
      if self.runner.base_path ~= "" then
        local default_path = os.getenv("LUA_PATH")
        local default_cpath = os.getenv("LUA_CPATH")
        local server_path = path.join(self.runner.base_path, "?.lua")
        local server_cpath = path.join(self.runner.base_path, "?.so")
        test_server = "\n        lua_package_path '" .. tostring(server_path) .. ";" .. tostring(default_path) .. "';\n        lua_package_cpath '" .. tostring(server_cpath) .. ";" .. tostring(default_cpath) .. "';\n      " .. test_server
      end
      return cfg:gsub("%f[%a]http%s-{", "http {\n" .. test_server)
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, runner)
      self.runner = runner
    end,
    __base = _base_0,
    __name = "NginxAttachedServer",
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
  NginxAttachedServer = _class_0
end
return {
  AttachedServer = NginxAttachedServer
}
