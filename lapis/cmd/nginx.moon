
CONFIG_PATH = "nginx.conf"
COMPILED_CONFIG_PATH = "nginx.conf.compiled"

path = require "lapis.cmd.path"
import get_free_port, default_environment from require "lapis.cmd.util"

local *

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

server_stack = nil

class AttachedServer
  new: (opts) =>
    for k,v in pairs opts
      @[k] = v

    db = require "lapis.nginx.postgres"
    pg_config = @environment.postgres
    if pg_config and pg_config.backend == "pgmoon"
      import Postgres from require "pgmoon"
      pgmoon = Postgres pg_config
      assert pgmoon\connect!

      logger = require("lapis.db").get_logger!
      logger = nil unless os.getenv "LAPIS_SHOW_QUERIES"

      @old_backend = db.set_backend "raw", (...) ->
        logger.query ... if logger
        assert pgmoon\query ...
    else
      @old_backend = db.set_backend "raw", @\query

  wait_until_ready: =>
    socket = require "socket"
    max_tries = 1000
    while true
      status = socket.connect "127.0.0.1", @port
      if status
        break

      max_tries -= 1
      error "Timed out waiting for server to start" if max_tries == 0
      socket.sleep 0.001

  detach: =>
    path.write_file COMPILED_CONFIG_PATH, assert @existing_config

    if @fresh
      send_term!
    else
      send_hup!

    server_stack = @previous
    if server_stack
      server_stack\wait_until_ready!

    db = require "lapis.nginx.postgres"
    db.set_backend "raw", @old_backend

    server_stack

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


attach_server = (environment, env_overrides) ->
  pid = get_pid!

  existing_config = path.read_file COMPILED_CONFIG_PATH

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
    previous: server_stack
    fresh: not pid
    :port, :existing_config
  }

  server\wait_until_ready!
  server_stack = server
  server

detach_server = ->
  error "no server was pushed" unless server_stack
  server_stack\detach!


-- combines attach_server and detach_server to run code with temporary server
run_with_server = (fn) ->
  port = get_free_port!
  current_server = attach_server default_environment!, { :port }
  current_server.app_port = port
  fn!
  current_server\detach!


{ :compile_config, :filters, :find_nginx, :start_nginx, :send_hup, :send_term,
  :get_pid, :write_config_for, :attach_server, :detach_server, :send_signal,
  :run_with_server }
