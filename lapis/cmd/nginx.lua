local CONFIG_PATH = "nginx.conf"
local COMPILED_CONFIG_PATH = "nginx.conf.compiled"
local path = require("lapis.cmd.path")
local find_nginx, filters, start_nginx, compile_config, write_config_for, get_pid, send_hup, send_term, wait_for_server, server_stack, push_server, pop_server, with_server, execute_on_server
do
  local nginx_bin = "nginx"
  local nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/",
    "/usr/sbin/",
    ""
  }
  local nginx_path
  find_nginx = function()
    if nginx_path then
      return nginx_path
    end
    for _index_0 = 1, #nginx_search_paths do
      local prefix = nginx_search_paths[_index_0]
      local cmd = tostring(prefix) .. tostring(nginx_bin) .. " -v 2>&1"
      local handle = io.popen(cmd)
      local out = handle:read()
      handle:close()
      if out:match("^nginx version: ngx_openresty/") then
        nginx_path = tostring(prefix) .. tostring(nginx_bin)
        return nginx_path
      end
    end
  end
end
filters = {
  pg = function(url)
    local user, password, host, db = url:match("^postgres://(.*):(.*)@(.*)/(.*)$")
    if not (user) then
      error("failed to parse postgres server url")
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
compile_config = function(config, opts)
  if opts == nil then
    opts = { }
  end
  local env = setmetatable({ }, {
    __index = function(self, key)
      local v = os.getenv("LAPIS_" .. key:upper())
      if v ~= nil then
        return v
      end
      return opts[key:lower()]
    end
  })
  local out = config:gsub("(${%b{}})", function(w)
    local name = w:sub(4, -3)
    local filter_name, filter_arg = name:match("^(%S+)%s+(.+)$")
    do
      local filter = filters[filter_name]
      if filter then
        local value = env[filter_arg]
        if value == nil then
          return w
        else
          return filter(value)
        end
      else
        local value = env[name]
        if value == nil then
          return w
        else
          return value
        end
      end
    end
  end)
  local env_header
  if opts._name then
    env_header = "env LAPIS_ENVIRONMENT=" .. tostring(opts._name) .. ";\n"
  else
    env_header = "env LAPIS_ENVIRONMENT;\n"
  end
  return env_header .. out
end
write_config_for = function(environment, process_fn, ...)
  if type(environment) == "string" then
    local config = require("lapis.config")
    environment = config.get(environment)
  end
  local compiled = compile_config(path.read_file(CONFIG_PATH), environment)
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
wait_for_server = function(port)
  local socket = require("socket")
  local max_tries = 1000
  while true do
    local status = socket.connect("127.0.0.1", port)
    if status then
      break
    end
    max_tries = max_tries - 1
    if max_tries == 0 then
      error("Timed out waiting for server to start")
    end
    socket.sleep(0.001)
  end
end
server_stack = nil
push_server = function(environment, process_fn)
  local pid = get_pid()
  local socket = require("socket")
  local existing_config = path.read_file(COMPILED_CONFIG_PATH)
  local sock = socket.bind("*", 0)
  local _, port = sock:getsockname()
  sock:close()
  if type(environment) == "string" then
    environment = require("lapis.config").get(environment)
  end
  environment = setmetatable({
    port = port
  }, {
    __index = environment
  })
  write_config_for(environment, process_fn, port)
  if pid then
    send_hup()
  else
    start_nginx(true)
  end
  wait_for_server(port)
  server_stack = {
    name = environment.__name,
    previous = server_stack,
    port = port,
    pid = pid,
    existing_config = existing_config
  }
  return server_stack
end
pop_server = function()
  if not (server_stack) then
    error("no server was pushed")
  end
  path.write_file(COMPILED_CONFIG_PATH, assert(server_stack.existing_config))
  if server_stack.pid then
    send_hup()
  else
    send_term()
  end
  server_stack = server_stack.previous
  if server_stack then
    wait_for_server(server_stack.port)
  end
  return server_stack
end
with_server = function(environment, fn)
  push_server(environment)
  local out = {
    fn()
  }
  pop_server()
  return unpack(out)
end
execute_on_server = function(code, environment)
  assert(loadstring(code))
  code = [[    local buffer = {}

    print = function(...)
      local str = table.concat({...}, "\t")
      io.stdout:write(str .. "\n")
      table.insert(buffer, str)
    end

    local success, err = pcall(function()
     ]] .. code .. [[    end)

    if not success then
      ngx.status = 500
      print(err)
    end

    ngx.print(table.concat(buffer, "\n"))
  ]]
  code = code:gsub("\\", "\\\\"):gsub('"', '\\"')
  local pushed = push_server(environment, function(compiled_config, port)
    local inserted_server = false
    local replace_server
    replace_server = function(server)
      if inserted_server then
        return ""
      end
      inserted_server = true
      return [[        server {
          listen ]] .. port .. [[;

          location = / {
            default_type 'text/plain';
            allow 127.0.0.1;
            deny all;

            content_by_lua "
              ]] .. code .. [[
            ";
          }

          location = /query {
            internal;
            postgres_pass database;
            postgres_query $echo_request_body;
          }
        }
      ]]
    end
    local lpeg = require("lpeg")
    local R, S, V, P
    R, S, V, P, V = lpeg.R, lpeg.S, lpeg.V, lpeg.P, lpeg.V
    local C, Cs, Ct, Cmt, Cg, Cb, Cc
    C, Cs, Ct, Cmt, Cg, Cb, Cc = lpeg.C, lpeg.Cs, lpeg.Ct, lpeg.Cmt, lpeg.Cg, lpeg.Cb, lpeg.Cc
    local white = S(" \t\r\n") ^ 0
    local parse = P({
      V("root"),
      balanced = P("{") * (V("balanced") + (1 - P("}"))) ^ 0 * P("}"),
      server_block = S(" \t") ^ 0 * P("server") * white * V("balanced") / replace_server,
      root = Cs((V("server_block") + 1) ^ 1 * -1)
    })
    compiled_config = parse:match(compiled_config)
    return assert(compiled_config, "Failed to find server directive in config")
  end)
  local http = require("socket.http")
  local res, headers
  res, code, headers = http.request("http://127.0.0.1:" .. tostring(pushed.port) .. "/")
  pop_server()
  return res
end
return {
  compile_config = compile_config,
  filters = filters,
  find_nginx = find_nginx,
  start_nginx = start_nginx,
  send_hup = send_hup,
  send_term = send_term,
  get_pid = get_pid,
  execute_on_server = execute_on_server,
  write_config_for = write_config_for,
  push_server = push_server,
  pop_server = pop_server
}
