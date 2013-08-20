
path = require "lapis.cmd.path"

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

start_nginx = (environment, background=false) ->
  nginx = find_nginx!
  return nil, "can't find nginx" unless nginx

  path.mkdir "logs"
  os.execute "touch logs/error.log"
  os.execute "touch logs/access.log"

  cmd =  nginx .. ' -p "$(pwd)"/ -c "nginx.conf.compiled"'

  if environment
    cmd = "LAPIS_ENVIRONMENT='#{environment}' " .. cmd

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
  out

write_config_for = (environment, out_fname="nginx.conf.compiled") ->
  config = require "lapis.config"
  import compile_config from require "lapis.cmd.nginx"

  vars = config.get environment
  compiled = compile_config path.read_file"nginx.conf", vars
  path.write_file "nginx.conf.compiled", compiled

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

with_server = (environment, fn) ->
  -- try to hijack it
  fresh_server = unless send_hup!
    start_nginx environment, true
    true

  os.execute "sleep 0.1" -- wait for workers to load

  -- make sure it's running
  return nil, "nginx failed to start, check error log" unless get_pid!

  out = { fn! }

  if fresh_server
    send_term!
  else
    write_config_for environment
    send_hup!

  unpack out

execute_on_server = (code, environment) ->
  assert loadstring code -- syntax check code

  config = require "lapis.config"
  vars = config.get environment

  compiled = compile_config path.read_file("nginx.conf"), vars

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

  import random_string from require "lapis.cmd.util"
  command_url = "/#{random_string 20}"

  inserted_server = false
  replace_server = (server) ->
    return "" if inserted_server
    inserted_server = true
    [[
      server {
        listen ]] .. vars.port .. [[;

        location = ]] .. command_url .. [[ {
          default_type 'text/plain';
          allow 127.0.0.1;
          deny all;

          content_by_lua "
            ]] .. code .. [[

          ";
        }

        location / {
          return 503;
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

  temp_config = parse\match compiled
  assert inserted_server, "Failed to find server directive in config"

  path.write_file "nginx.conf.compiled", temp_config

  assert with_server environment, ->
    http = require "socket.http"
    res, code = http.request "http://127.0.0.1:#{vars.port}/#{command_url}"
    res

{ :compile_config, :filters, :find_nginx, :start_nginx, :send_hup, :send_term,
  :get_pid, :execute_on_server, :write_config_for }
