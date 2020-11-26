local path = require("lapis.cmd.path")
local shell_escape
shell_escape = path.shell_escape
local NginxRunner
do
  local _class_0
  local _base_0 = {
    ConfigCompiler = require("lapis.cmd.nginx.config").ConfigCompiler,
    AttachedServer = require("lapis.cmd.nginx.attached_server").AttachedServer,
    config_path = "nginx.conf",
    config_path_etlua = "nginx.conf.etlua",
    compiled_config_path = "nginx.conf.compiled",
    base_path = "",
    current_server = nil,
    nginx_bins = {
      "nginx",
      "openresty"
    },
    nginx_search_paths = {
      "/opt/openresty/nginx/sbin/",
      "/usr/local/openresty/nginx/sbin/",
      "/usr/local/opt/openresty/bin/",
      "/usr/sbin/",
      ""
    },
    exec = function(self, cmd)
      return os.execute(cmd)
    end,
    set_base_path = function(self, p)
      if p == nil then
        p = ""
      end
      self.base_path = p
      local _list_0 = {
        "config_path",
        "config_path_etlua",
        "compiled_config_path"
      }
      for _index_0 = 1, #_list_0 do
        local k = _list_0[_index_0]
        self[k] = path.join(self.base_path, self.__class.__base[k])
      end
    end,
    start_nginx = function(self, background)
      if background == nil then
        background = false
      end
      local nginx = self:find_nginx()
      if not (nginx) then
        return nil, "can't find nginx"
      end
      path.mkdir(path.join(self.base_path, "logs"))
      self:exec("touch '" .. tostring(shell_escape(path.join(self.base_path, "logs/error.log"))) .. "'")
      self:exec("touch '" .. tostring(shell_escape(path.join(self.base_path, "logs/access.log"))) .. "'")
      local root
      if self.base_path:match("^/") then
        root = "'" .. tostring(shell_escape(self.base_path)) .. "'"
      else
        root = '"$(pwd)"/' .. "'" .. tostring(shell_escape(self.base_path)) .. "'"
      end
      local cmd = nginx .. " -p " .. tostring(root) .. " -c '" .. tostring(shell_escape(path.filename(self.compiled_config_path))) .. "'"
      if background then
        cmd = cmd .. " > /dev/null 2>&1 &"
      end
      return self:exec(cmd)
    end,
    get_pid = function(self)
      local pidfile = io.open(path.join(self.base_path, "logs/nginx.pid"))
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
          self:exec("kill -s " .. tostring(signal) .. " " .. tostring(pid))
          return pid
        end
      end
    end,
    send_hup = function(self)
      do
        local pid = self:get_pid()
        if pid then
          self:exec("kill -HUP " .. tostring(pid))
          return pid
        end
      end
    end,
    send_term = function(self)
      do
        local pid = self:get_pid()
        if pid then
          self:exec("kill " .. tostring(pid))
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
      local _list_0 = self.nginx_bins
      for _index_0 = 1, #_list_0 do
        local nginx_bin = _list_0[_index_0]
        local _list_1 = self.nginx_search_paths
        for _index_1 = 1, #_list_1 do
          local prefix = _list_1[_index_1]
          local to_check = tostring(prefix) .. tostring(nginx_bin)
          if self:check_binary_is_openresty(to_check) then
            self._nginx_path = to_check
            return self._nginx_path
          end
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
      local server = self:AttachedServer()
      server:start(environment, env_overrides)
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
  _class_0 = setmetatable({
    __init = function(self, opts)
      if opts == nil then
        opts = { }
      end
      do
        local bp = opts.base_path
        if bp then
          self:set_base_path(bp)
        end
      end
      for k, v in pairs(opts) do
        local _continue_0 = false
        repeat
          if k == "base_path" then
            _continue_0 = true
            break
          end
          self[k] = v
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
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
  type = "nginx",
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
