local CONFIG_PATH = "nginx.conf"
local CONFIG_PATH_ETLUA = "nginx.conf.etlua"
local COMPILED_CONFIG_PATH = "nginx.conf.compiled"
local path = require("lapis.cmd.path")
local get_free_port, default_environment
do
  local _obj_0 = require("lapis.cmd.util")
  get_free_port, default_environment = _obj_0.get_free_port, _obj_0.default_environment
end
local current_server, find_nginx, filters, start_nginx, wrap_environment, add_config_header, compile_config, compile_etlua_config, write_config_for, get_pid, send_signal, send_hup, send_term, process_config, AttachedServer, attach_server, detach_server, run_with_server
current_server = nil
do
  local nginx_bin = "nginx"
  local nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/",
    "/usr/local/opt/openresty/bin/",
    "/usr/sbin/",
    ""
  }
  local nginx_path
  local is_openresty
  is_openresty = function(path)
    local cmd = tostring(path) .. " -v 2>&1"
    local handle = io.popen(cmd)
    local out = handle:read()
    handle:close()
    local matched = out:match("^nginx version: ngx_openresty/") or out:match("^nginx version: openresty/")
    if matched then
      return path
    end
  end
  find_nginx = function()
    if nginx_path then
      return nginx_path
    end
    do
      local to_check = os.getenv("LAPIS_OPENRESTY")
      if to_check then
        if is_openresty(to_check) then
          nginx_path = to_check
          return nginx_path
        end
      end
    end
    for _index_0 = 1, #nginx_search_paths do
      local prefix = nginx_search_paths[_index_0]
      local to_check = tostring(prefix) .. tostring(nginx_bin)
      if is_openresty(to_check) then
        nginx_path = to_check
        return nginx_path
      end
    end
  end
end
filters = {
  pg = function(val)
    local user, password, host, db
    local _exp_0 = type(val)
    if "table" == _exp_0 then
      db = assert(val.database, "missing database name")
      user, password, host, db = val.user or "postgres", val.password or "", val.host or "127.0.0.1", db
    elseif "string" == _exp_0 then
      user, password, host, db = val:match("^postgres://(.*):(.*)@(.*)/(.*)$")
    end
    if not (user) then
      error("failed to create postgres connect string")
    end
    return ("%s dbname=%s user=%s password=%s"):format(host, db, user, password)
  end
}
start_nginx = function(background)
  if background == nil then
    background = false
  end
  local nginx = find_nginx()
  if not (nginx) then
    return nil, "can't find nginx"
  end
  path.mkdir("logs")
  os.execute("touch logs/error.log")
  os.execute("touch logs/access.log")
  local cmd = nginx .. ' -p "$(pwd)"/ -c "' .. COMPILED_CONFIG_PATH .. '"'
  if background then
    cmd = cmd .. " > /dev/null 2>&1 &"
  end
  return os.execute(cmd)
end
wrap_environment = function(env)
  return setmetatable({ }, {
    __index = function(self, key)
      local v = os.getenv("LAPIS_" .. key:upper())
      if v ~= nil then
        return v
      end
      return env[key:lower()]
    end
  })
end
add_config_header = function(compiled, env)
  local header
  do
    local name = env._name
    if name then
      header = "env LAPIS_ENVIRONMENT=" .. tostring(name) .. ";\n"
    else
      header = "env LAPIS_ENVIRONMENT;\n"
    end
  end
  return header .. compiled
end
compile_config = function(config, env, opts)
  if env == nil then
    env = { }
  end
  if opts == nil then
    opts = { }
  end
  local wrapped = opts.os_env == false and env or wrap_environment(env)
  local out = config:gsub("(${%b{}})", function(w)
    local name = w:sub(4, -3)
    local filter_name, filter_arg = name:match("^(%S+)%s+(.+)$")
    do
      local filter = filters[filter_name]
      if filter then
        local value = wrapped[filter_arg]
        if value == nil then
          return w
        else
          return filter(value)
        end
      else
        local value = wrapped[name]
        if value == nil then
          return w
        else
          return value
        end
      end
    end
  end)
  if opts.header == false then
    return out
  else
    return add_config_header(out, env)
  end
end
compile_etlua_config = function(config, env, opts)
  if env == nil then
    env = { }
  end
  if opts == nil then
    opts = { }
  end
  local etlua = require("etlua")
  local wrapped = opts.os_env == false and env or wrap_environment(env)
  local template = assert(etlua.compile(config))
  local out = template(wrapped)
  if opts.header == false then
    return out
  else
    return add_config_header(out, env)
  end
end
write_config_for = function(environment, process_fn, ...)
  if type(environment) == "string" then
    local config = require("lapis.config")
    environment = config.get(environment)
  end
  local compiled
  if path.exists(CONFIG_PATH_ETLUA) then
    compiled = compile_etlua_config(path.read_file(CONFIG_PATH_ETLUA), environment)
  else
    compiled = compile_config(path.read_file(CONFIG_PATH), environment)
  end
  if process_fn then
    compiled = process_fn(compiled, ...)
  end
  return path.write_file(COMPILED_CONFIG_PATH, compiled)
end
get_pid = function()
  local pidfile = io.open("logs/nginx.pid")
  if not (pidfile) then
    return 
  end
  local pid = pidfile:read("*a")
  pidfile:close()
  return pid:match("[^%s]+")
end
send_signal = function(signal)
  do
    local pid = get_pid()
    if pid then
      os.execute("kill -s " .. tostring(signal) .. " " .. tostring(pid))
      return pid
    end
  end
end
send_hup = function()
  do
    local pid = get_pid()
    if pid then
      os.execute("kill -HUP " .. tostring(pid))
      return pid
    end
  end
end
send_term = function()
  do
    local pid = get_pid()
    if pid then
      os.execute("kill " .. tostring(pid))
      return pid
    end
  end
end
process_config = function(cfg, port)
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
  local test_server = {
    [[      server {
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
    ]]
  }
  if cfg:match("upstream%s+database") then
    table.insert(test_server, [[      location = /http_query {
        postgres_pass database;
        set_decode_base64 $query $http_x_query;
        log_by_lua '
          local logger = require "lapis.logging"
          logger.query(ngx.var.query)
        ';
        postgres_query $query;
        rds_json on;
      }

      location = /query {
        internal;
        postgres_pass database;
        postgres_query $echo_request_body;
      }
    ]])
  end
  table.insert(test_server, "}")
  return cfg:gsub("%f[%a]http%s-{", "http { " .. table.concat(test_server, "\n"))
end
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
        path.write_file(COMPILED_CONFIG_PATH, self.existing_config)
      end
      if self.fresh then
        send_term()
        self:wait_until_closed()
      else
        send_hup()
      end
      if self.old_backend then
        local db = require("lapis.db")
        db.set_backend("raw", self.old_backend)
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
    __init = function(self, opts)
      for k, v in pairs(opts) do
        self[k] = v
      end
      local env = require("lapis.environment")
      env.push(self.environment)
      local pg_config = self.environment.postgres
      if pg_config and not pg_config.backend == "pgmoon" then
        local db = require("lapis.db")
        self.old_backend = db.set_backend("raw", (function()
          local _base_1 = self
          local _fn_0 = _base_1.query
          return function(...)
            return _fn_0(_base_1, ...)
          end
        end)())
      end
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
attach_server = function(environment, env_overrides)
  assert(not current_server, "a server is already attached (did you forget to detach?)")
  local pid = get_pid()
  local existing_config
  if path.exists(COMPILED_CONFIG_PATH) then
    existing_config = path.read_file(COMPILED_CONFIG_PATH)
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
  write_config_for(environment, process_config, port)
  if pid then
    send_hup()
  else
    start_nginx(true)
  end
  local server = AttachedServer({
    environment = environment,
    fresh = not pid,
    port = port,
    existing_config = existing_config
  })
  server:wait_until_ready()
  current_server = server
  return server
end
detach_server = function()
  if not (current_server) then
    error("no server is attached")
  end
  current_server:detach()
  current_server = nil
  return true
end
run_with_server = function(fn)
  local port = get_free_port()
  current_server = attach_server(default_environment(), {
    port = port
  })
  current_server.app_port = port
  fn()
  return current_server:detach()
end
return {
  compile_config = compile_config,
  compile_etlua_config = compile_etlua_config,
  filters = filters,
  find_nginx = find_nginx,
  start_nginx = start_nginx,
  send_hup = send_hup,
  send_term = send_term,
  get_pid = get_pid,
  write_config_for = write_config_for,
  attach_server = attach_server,
  detach_server = detach_server,
  send_signal = send_signal,
  run_with_server = run_with_server,
  CONFIG_PATH = CONFIG_PATH,
  CONFIG_PATH_ETLUA = CONFIG_PATH_ETLUA
}
