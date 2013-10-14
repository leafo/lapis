
CONFIG_PATH = "nginx.conf"
COMPILED_CONFIG_PATH = "nginx.conf.compiled"

path = require "lapis.cmd.path"

local *

find_nginx = do
  nginx_bin = "nginx"
  nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/"
    "/usr/sbin/"
    ""
  }

  local nginx_path
  ->
    return nginx_path if nginx_path
    for prefix in *nginx_search_paths
      cmd = "#{prefix}#{nginx_bin} -v 2>&1"
      handle = io.popen cmd
      out = handle\read!
      handle\close!

      if out\match "^nginx version: ngx_openresty/"
        nginx_path = "#{prefix}#{nginx_bin}"
        return nginx_path

filters = {
  pg: (url) ->
    user, password, host, db = url\match "^postgres://(.*):(.*)@(.*)/(.*)$"
    error "failed to parse postgres server url" unless user
    "%s dbname=%s user=%s password=%s"\format host, db, user, password
}

start_nginx = (background=false) ->
  nginx = find_nginx!
  return nil, "can't find nginx" unless nginx

  path.mkdir "logs"
  os.execute "touch logs/error.log"
  os.execute "touch logs/access.log"

  cmd = nginx .. ' -p "$(pwd)"/ -c "' .. COMPILED_CONFIG_PATH .. '"'

  if background
    cmd = cmd .. " > /dev/null 2>&1 &"

  os.execute cmd

compile_config = (config, opts={}) ->
  env = setmetatable {}, __index: (key) =>
    v = os.getenv "LAPIS_" .. key\upper!
    return v if v != nil
    opts[key\lower!]

  out = config\gsub "(${%b{}})", (w) ->
    name = w\sub 4, -3
    filter_name, filter_arg = name\match "^(%S+)%s+(.+)$"
    if filter = filters[filter_name]
      value = env[filter_arg]
      if value == nil then w else filter value
    else
      value = env[name]
      if value == nil then w else value

  env_header = if opts._name
    "env LAPIS_ENVIRONMENT=#{opts._name};\n"
  else
    "env LAPIS_ENVIRONMENT;\n"

  env_header .. out

write_config_for = (environment, process_fn, ...) ->
  if type(environment) == "string"
    config = require "lapis.config"
    environment = config.get environment

  compiled = compile_config path.read_file(CONFIG_PATH), environment

  if process_fn
    compiled = process_fn compiled, ...

  path.write_file COMPILED_CONFIG_PATH, compiled

get_pid = ->
  pidfile = io.open "logs/nginx.pid"
  return unless pidfile
  pid = pidfile\read "*a"
  pidfile\close!
  pid\match "[^%s]+"

send_hup = ->
  if pid = get_pid!
    os.execute "kill -HUP #{pid}"
    pid

send_term = ->
  if pid = get_pid!
    os.execute "kill #{pid}"
    pid


wait_for_server = (port) ->
  socket = require "socket"
  max_tries = 1000
  while true
    status = socket.connect "127.0.0.1", port
    if status
      break

    max_tries -= 1
    error "Timed out waiting for server to start" if max_tries == 0
    socket.sleep 0.001

server_stack = nil
push_server = (environment, process_fn) ->
  pid = get_pid!

  socket = require "socket"

  existing_config = path.read_file COMPILED_CONFIG_PATH

  -- get a free port
  sock = socket.bind "*", 0
  _, port = sock\getsockname!
  sock\close!

  if type(environment) == "string"
    environment = require("lapis.config").get environment

  -- Override the port with our temporary one
  -- TODO: this will fail when LAPIS_PORT set
  environment = setmetatable { :port }, __index: environment

  write_config_for environment, process_fn, port

  if pid
    send_hup!
  else
    start_nginx true

  wait_for_server port

  server_stack = {
    name: environment.__name
    previous: server_stack
    :port, :pid, :existing_config
  }

  server_stack

pop_server = ->
  error "no server was pushed" unless server_stack
  path.write_file COMPILED_CONFIG_PATH, assert server_stack.existing_config

  if server_stack.pid
    send_hup!
  else
    send_term!

  server_stack = server_stack.previous
  wait_for_server server_stack.port if server_stack
  server_stack

-- helper to push and pop in one go
with_server = (environment, fn) ->
  push_server environment
  out = { fn! }
  pop_server!
  unpack out

--
execute_on_server = (code, environment) ->
  assert loadstring code -- syntax check code

  -- wrap code
  code = [[
    print = function(...)
      local str = table.concat({...}, "\t")
      io.stdout:write(str .. "\n")
      ngx.say(str)
    end

    local success, err = pcall(function()
     ]] .. code .. [[
    end)

    if not success then
      print(err)
    end
  ]]

  code = code\gsub("\\", "\\\\")\gsub('"', '\\"')

  pushed = push_server environment, (compiled_config, port) ->
    -- override the config, replacing the first server with an action that runs
    -- the code and remove all the others
    inserted_server = false
    replace_server = (server) ->
      return "" if inserted_server
      inserted_server = true
      [[
        server {
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

    lpeg = require "lpeg"

    import R, S, V, P, V from lpeg
    import C, Cs, Ct, Cmt, Cg, Cb, Cc from lpeg

    white = S" \t\r\n"^0
    parse = P {
      V"root"
      balanced: P"{" * (V"balanced" + (1 - P"}"))^0 * P"}"
      server_block: S" \t"^0 * P"server" * white * V"balanced" / replace_server
      root: Cs (V"server_block" + 1)^1 * -1
    }

    compiled_config = parse\match compiled_config
    assert compiled_config, "Failed to find server directive in config"

  http = require "socket.http"
  res, code = http.request "http://127.0.0.1:#{pushed.port}/"
  pop_server!

  res

{ :compile_config, :filters, :find_nginx, :start_nginx, :send_hup, :send_term,
  :get_pid, :execute_on_server, :write_config_for, :push_server, :pop_server }
