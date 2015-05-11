
path = require "lapis.cmd.path"
import get_free_port, default_environment from require "lapis.cmd.util"

class NginxRunner
  ConfigCompiler: require("lapis.cmd.nginx.config").ConfigCompiler
  AttachedServer: require("lapis.cmd.nginx.attached_server").AttachedServer

  config_path: "nginx.conf"
  config_path_etlua: "nginx.conf.etlua"
  compiled_config_path: "nginx.conf.compiled"
  current_server: nil

  nginx_bin: "nginx"
  nginx_search_paths: {
    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""
  }

  new: (opts={}) =>
    for k,v in pairs opts
      @[k] = v

  start_nginx: (background=false) =>
    nginx = @find_nginx!
    return nil, "can't find nginx" unless nginx

    path.mkdir "logs"
    os.execute "touch logs/error.log"
    os.execute "touch logs/access.log"

    cmd = nginx .. ' -p "$(pwd)"/ -c "' .. @compiled_config_path .. '"'

    if background
      cmd = cmd .. " > /dev/null 2>&1 &"

    os.execute cmd

  get_pid: =>
    pidfile = io.open "logs/nginx.pid"
    return unless pidfile
    pid = pidfile\read "*a"
    pidfile\close!
    pid\match "[^%s]+"

  send_signal: (signal) =>
    if pid = @get_pid!
      os.execute "kill -s #{signal} #{pid}"
      pid

  send_hup: =>
    if pid = @get_pid!
      os.execute "kill -HUP #{pid}"
      pid

  send_term: =>
    if pid = @get_pid!
      os.execute "kill #{pid}"
      pid

  -- find the path to the (openresty) nginx binary
  find_nginx: =>
    return @_nginx_path if @_nginx_path

    -- check for overriden openresty path
    if to_check = os.getenv "LAPIS_OPENRESTY"
      if @check_binary_is_openresty to_check
        @_nginx_path = to_check
        return @_nginx_path

    for prefix in *@nginx_search_paths
      to_check = "#{prefix}#{@nginx_bin}"

      if @check_binary_is_openresty to_check
        @_nginx_path = to_check
        return @_nginx_path

  -- test if bath to binary is an openresty binary (instead of nginx one)
  check_binary_is_openresty: (path) =>
    cmd = "#{path} -v 2>&1"
    handle = io.popen cmd
    out = handle\read!
    handle\close!

    matched = out\match"^nginx version: ngx_openresty/" or
      out\match"^nginx version: openresty/"

    if matched
      return path

  attach_server: (environment, env_overrides) =>
    assert not @current_server, "a server is already attached (did you forget to detach?)"

    import debug_config_process from require "lapis.cmd.nginx.attached_server"

    pid = @get_pid!

    existing_config = if path.exists @compiled_config_path
      path.read_file @compiled_config_path

    port = get_free_port!

    if type(environment) == "string"
      environment = require("lapis.config").get environment

    if env_overrides
      assert not getmetatable(env_overrides), "env_overrides already has metatable, aborting"
      environment = setmetatable env_overrides, __index: environment

    @write_config_for environment, debug_config_process, port

    if pid
      @send_hup!
    else
      @start_nginx true

    server = @AttachedServer {
      :environment
      fresh: not pid
      :port, :existing_config
    }

    server\wait_until_ready!
    @current_server = server
    server

  detach_server: =>
    error "no server is attached" unless @current_server
    @current_server\detach!
    @current_server = nil
    true

  write_config_for: (environment, process_fn, ...) =>
    if type(environment) == "string"
      config = require "lapis.config"
      environment = config.get environment

    compiler = @.ConfigCompiler!

    compiled = if path.exists @config_path_etlua
      compiler\compile_etlua_config path.read_file(@config_path_etlua), environment
    else
      compiler\compile_config path.read_file(@config_path), environment

    if process_fn
      compiled = process_fn compiled, ...

    path.write_file @compiled_config_path, compiled

runner = NginxRunner!
compiler = NginxRunner.ConfigCompiler!

{
  :NginxRunner
  nginx_runner: runner

  get_pid: runner\get_pid

  send_signal: runner\send_signal
  send_term: runner\send_term
  send_hup: runner\send_hup

  start_nginx: runner\start_nginx
  find_nginx: runner\find_nginx

  write_config_for: runner\write_config_for

  compile_config: compiler\compile_config
  compile_etlua_config: compiler\compile_etlua_config

  attach_server: runner\attach_server
  detach_server: runner\detach_server
}
