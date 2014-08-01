
CONFIG_PATH = "nginx.conf"
CONFIG_PATH_ETLUA = "nginx.conf.etlua"

COMPILED_CONFIG_PATH = "nginx.conf.compiled"

path = require "lapis.cmd.path"
import get_free_port, default_environment from require "lapis.cmd.util"


local *

current_server = nil

find_nginx = do
  nginx_bin = "nginx"
  nginx_search_paths = {
    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""
  }

  local nginx_path

  -- check if the path is openresty binary
  is_openresty = (path) ->
    cmd = "#{path} -v 2>&1"
    handle = io.popen cmd
    out = handle\read!
    handle\close!

    matched = out\match"^nginx version: ngx_openresty/" or out\match"^nginx version: openresty/"

    if matched
      return path

  ->
    return nginx_path if nginx_path
    if to_check = os.getenv "LAPIS_OPENRESTY"
      if is_openresty to_check
        nginx_path = to_check
        return nginx_path

    for prefix in *nginx_search_paths
      to_check = "#{prefix}#{nginx_bin}"

      if is_openresty to_check
        nginx_path = to_check
        return nginx_path

filters = {
  pg: (val) ->
    user, password, host, db = switch type(val)
      when "table"
        db = assert val.database, "missing database name"
        val.user or "postgres", val.password or "", val.host or "127.0.0.1", db
      when "string"
        val\match "^postgres://(.*):(.*)@(.*)/(.*)$"

    error "failed to create postgres connect string" unless user
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

wrap_environment = (env) ->
  setmetatable {}, __index: (key) =>
    v = os.getenv "LAPIS_" .. key\upper!
    return v if v != nil
    env[key\lower!]

add_config_header = (compiled, env) ->
  header = if name = env._name
    "env LAPIS_ENVIRONMENT=#{name};\n"
  else
    "env LAPIS_ENVIRONMENT;\n"

  header .. compiled

compile_config = (config, env={}, opts={}) ->
  wrapped = opts.os_env == false and env or wrap_environment(env)

  out = config\gsub "(${%b{}})", (w) ->
    name = w\sub 4, -3
    filter_name, filter_arg = name\match "^(%S+)%s+(.+)$"
    if filter = filters[filter_name]
      value = wrapped[filter_arg]
      if value == nil then w else filter value
    else
      value = wrapped[name]
      if value == nil then w else value

  if opts.header == false
    out
  else
    add_config_header out, env

compile_etlua_config = (config, env={}, opts={}) ->
  etlua = require "etlua"
  wrapped = opts.os_env == false and env or wrap_environment(env)

  template = assert etlua.compile config
  out = template wrapped

  if opts.header == false
    out
  else
    add_config_header out, env

write_config_for = (environment, process_fn, ...) ->
  if type(environment) == "string"
    config = require "lapis.config"
    environment = config.get environment

  compiled = if path.exists CONFIG_PATH_ETLUA
    compile_etlua_config path.read_file(CONFIG_PATH_ETLUA), environment
  else
    compile_config path.read_file(CONFIG_PATH), environment

  if process_fn
    compiled = process_fn compiled, ...

  path.write_file COMPILED_CONFIG_PATH, compiled

get_pid = ->
  pidfile = io.open "logs/nginx.pid"
  return unless pidfile
  pid = pidfile\read "*a"
  pidfile\close!
  pid\match "[^%s]+"

send_signal = (signal) ->
  if pid = get_pid!
    os.execute "kill -s #{signal} #{pid}"
    pid

send_hup = ->
  if pid = get_pid!
    os.execute "kill -HUP #{pid}"
    pid

send_term = ->
  if pid = get_pid!
    os.execute "kill #{pid}"
    pid

-- injects a debug server into the config
process_config = (cfg, port) ->
  run_code_action = [[
    ngx.req.read_body()

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

  -- escape for nginx config
  run_code_action = run_code_action\gsub("\\", "\\\\")\gsub('"', '\\"')

  test_server = {
    [[
      server {
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

  -- add query locations if upstream can be found
  if cfg\match "upstream%s+database"
    table.insert test_server, [[
      location = /http_query {
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
    ]]

  table.insert test_server, "}"

  cfg\gsub "%f[%a]http%s-{", "http { " .. table.concat test_server, "\n"

class AttachedServer
  new: (opts) =>
    for k,v in pairs opts
      @[k] = v

    env = require "lapis.environment"
    env.push @environment

    pg_config = @environment.postgres
    if pg_config and not pg_config.backend == "pgmoon"
      @old_backend = db.set_backend "raw", @\query

  wait_until: (server_status="open")=>
    socket = require "socket"
    max_tries = 1000
    while true
      sock = socket.connect "127.0.0.1", @port
      switch server_status
        when "open"
          if sock
            sock\close!
            break
        when "close"
          if sock
            sock\close!
          else
            break
        else
          error "don't know how to wait for #{server_status}"

      max_tries -= 1
      if max_tries == 0
        error "Timed out waiting for server to #{server_status}"

      socket.sleep 0.001

  wait_until_ready: => @wait_until "open"
  wait_until_closed: => @wait_until "close"

  detach: =>
    if @existing_config
      path.write_file COMPILED_CONFIG_PATH, @existing_config

    if @fresh
      send_term!
      @wait_until_closed!
    else
      send_hup!

    if @old_backend
      db = require "lapis.db"
      db.set_backend "raw", @old_backend

    env = require "lapis.environment"
    env.pop!

    true

  query: (q) =>
    ltn12 = require "ltn12"
    http = require "socket.http"
    mime = require "mime"
    json = require "cjson"

    buffer = {}
    http.request {
      url: "http://127.0.0.1:#{@port}/http_query"
      sink: ltn12.sink.table(buffer)
      headers: {
        "x-query": mime.b64 q
      }
    }

    json.decode table.concat buffer

  exec: (lua_code) =>
    assert loadstring lua_code -- syntax check code

    ltn12 = require "ltn12"
    http = require "socket.http"

    buffer = {}
    http.request {
      url: "http://127.0.0.1:#{@port}/run_lua"
      sink: ltn12.sink.table buffer
      source: ltn12.source.string lua_code
      headers: {
        "content-length": #lua_code
      }
    }

    table.concat buffer

-- attaches or starts a new server in a specified environment
attach_server = (environment, env_overrides) ->
  assert not current_server, "a server is already attached (did you forget to detach?)"

  pid = get_pid!

  existing_config = if path.exists COMPILED_CONFIG_PATH
    path.read_file COMPILED_CONFIG_PATH

  port = get_free_port!

  if type(environment) == "string"
    environment = require("lapis.config").get environment

  if env_overrides
    assert not getmetatable(env_overrides), "env_overrides already has metatable, aborting"
    environment = setmetatable env_overrides, __index: environment

  write_config_for environment, process_config, port

  if pid
    send_hup!
  else
    start_nginx true

  server = AttachedServer {
    :environment
    fresh: not pid
    :port, :existing_config
  }

  server\wait_until_ready!
  current_server = server
  server

detach_server = ->
  error "no server is attached" unless current_server
  current_server\detach!
  current_server = nil
  true

-- combines attach_server and detach_server to run code with temporary server
run_with_server = (fn) ->
  port = get_free_port!
  current_server = attach_server default_environment!, { :port }
  current_server.app_port = port
  fn!
  current_server\detach!


{ :compile_config, :compile_etlua_config, :filters, :find_nginx, :start_nginx,
  :send_hup, :send_term, :get_pid, :write_config_for, :attach_server,
  :detach_server, :send_signal, :run_with_server, :CONFIG_PATH,
  :CONFIG_PATH_ETLUA }
