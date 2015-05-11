local path = require("lapis.cmd.path")
local get_free_port, default_environment
do
  local _obj_0 = require("lapis.cmd.util")
  get_free_port, default_environment = _obj_0.get_free_port, _obj_0.default_environment
end
local NginxRunner
do
  local _base_0 = {
    ConfigCompiler = require("lapis.cmd.nginx.config").ConfigCompiler,
    AttachedServer = require("lapis.cmd.nginx.attached_server").AttachedServer,
    config_path = "nginx.conf",
    config_path_etlua = "nginx.conf.etlua",
    compiled_config_path = "nginx.conf.compiled",
    current_server = nil,
    nginx_bin = "nginx",
    nginx_search_paths = {
      "/usr/local/openresty/nginx/sbin/",
      "/usr/local/opt/openresty/bin/",
      "/usr/sbin/",
      ""
    },
    start_nginx = function(self, background)
      if background == nil then
        background = false
      end
      local nginx = self:find_nginx()
      if not (nginx) then
        return nil, "can't find nginx"
      end
      path.mkdir("logs")
      os.execute("touch logs/error.log")
      os.execute("touch logs/access.log")
      local cmd = nginx .. ' -p "$(pwd)"/ -c "' .. self.compiled_config_path .. '"'
      if background then
        cmd = cmd .. " > /dev/null 2>&1 &"
      end
      return os.execute(cmd)
    end,
    get_pid = function(self)
      local pidfile = io.open("logs/nginx.pid")
      if not (pidfile) then
        return 
      end
      local pid = pidfile:read("*a")
      pidfile:close()
      return pid:match("[^%s]+")
    end,
    send_signal = function(self, signal)
      do
        local pid = self:get_pid()
        if pid then
          os.execute("kill -s " .. tostring(signal) .. " " .. tostring(pid))
          return pid
        end
      end
    end,
    send_hup = function(self)
      do
        local pid = self:get_pid()
        if pid then
          os.execute("kill -HUP " .. tostring(pid))
          return pid
        end
      end
    end,
    send_term = function(self)
      do
        local pid = self:get_pid()
        if pid then
          os.execute("kill " .. tostring(pid))
          return pid
        end
      end
    end,
    find_nginx = function(self)
      if self._nginx_path then
        return self._nginx_path
      end
      do
        local to_check = os.getenv("LAPIS_OPENRESTY")
        if to_check then
          if self:check_binary_is_openresty(to_check) then
            self._nginx_path = to_check
            return self._nginx_path
          end
        end
      end
      local _list_0 = self.nginx_search_paths
      for _index_0 = 1, #_list_0 do
        local prefix = _list_0[_index_0]
        local to_check = tostring(prefix) .. tostring(self.nginx_bin)
        if self:check_binary_is_openresty(to_check) then
          self._nginx_path = to_check
          return self._nginx_path
        end
      end
    end,
    check_binary_is_openresty = function(self, path)
      local cmd = tostring(path) .. " -v 2>&1"
      local handle = io.popen(cmd)
      local out = handle:read()
      handle:close()
      local matched = out:match("^nginx version: ngx_openresty/") or out:match("^nginx version: openresty/")
      if matched then
        return path
      end
    end,
    attach_server = function(self, environment, env_overrides)
      assert(not self.current_server, "a server is already attached (did you forget to detach?)")
      local debug_config_process
      debug_config_process = require("lapis.cmd.nginx.attached_server").debug_config_process
      local pid = self:get_pid()
      local existing_config
      if path.exists(self.compiled_config_path) then
        existing_config = path.read_file(self.compiled_config_path)
      end
      local port = get_free_port()
      if type(environment) == "string" then
        environment = require("lapis.config").get(environment)
      end
      if env_overrides then
        assert(not getmetatable(env_overrides), "env_overrides already has metatable, aborting")
        environment = setmetatable(env_overrides, {
          __index = environment
        })
      end
      self:write_config_for(environment, debug_config_process, port)
      if pid then
        self:send_hup()
      else
        self:start_nginx(true)
      end
      local server = self:AttachedServer({
        environment = environment,
        fresh = not pid,
        port = port,
        existing_config = existing_config
      })
      server:wait_until_ready()
      self.current_server = server
      return server
    end,
    detach_server = function(self)
      if not (self.current_server) then
        error("no server is attached")
      end
      self.current_server:detach()
      self.current_server = nil
      return true
    end,
    write_config_for = function(self, environment, process_fn, ...)
      if type(environment) == "string" then
        local config = require("lapis.config")
        environment = config.get(environment)
      end
      local compiler = self.ConfigCompiler()
      local compiled
      if path.exists(self.config_path_etlua) then
        compiled = compiler:compile_etlua_config(path.read_file(self.config_path_etlua), environment)
      else
        compiled = compiler:compile_config(path.read_file(self.config_path), environment)
      end
      if process_fn then
        compiled = process_fn(compiled, ...)
      end
      return path.write_file(self.compiled_config_path, compiled)
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, opts)
      if opts == nil then
        opts = { }
      end
      for k, v in pairs(opts) do
        self[k] = v
      end
    end,
    __base = _base_0,
    __name = "NginxRunner"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  NginxRunner = _class_0
end
local runner = NginxRunner()
local compiler = NginxRunner.ConfigCompiler()
return {
  NginxRunner = NginxRunner,
  nginx_runner = runner,
  get_pid = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.get_pid
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  send_signal = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.send_signal
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  send_term = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.send_term
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  send_hup = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.send_hup
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  start_nginx = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.start_nginx
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  find_nginx = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.find_nginx
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  write_config_for = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.write_config_for
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  compile_config = (function()
    local _base_0 = compiler
    local _fn_0 = _base_0.compile_config
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  compile_etlua_config = (function()
    local _base_0 = compiler
    local _fn_0 = _base_0.compile_etlua_config
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  attach_server = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.attach_server
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)(),
  detach_server = (function()
    local _base_0 = runner
    local _fn_0 = _base_0.detach_server
    return function(...)
      return _fn_0(_base_0, ...)
    end
  end)()
}
