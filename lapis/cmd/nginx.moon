
path = require "lapis.cmd.path"
import shell_escape from path

class NginxRunner
  ConfigCompiler: require("lapis.cmd.nginx.config").ConfigCompiler
  AttachedServer: require("lapis.cmd.nginx.attached_server").AttachedServer

  config_path: "nginx.conf"
  config_path_etlua: "nginx.conf.etlua"
  compiled_config_path: "nginx.conf.compiled"
  base_path: ""
  current_server: nil

  nginx_bins: {
    "nginx"
    "openresty"
  }
  nginx_search_paths: {
    "/opt/openresty/nginx/sbin/"
    "/usr/local/openresty/nginx/sbin/"
    "/usr/local/opt/openresty/bin/"
    "/usr/sbin/"
    ""
  }

  new: (opts={}) =>
    if bp = opts.base_path
      @set_base_path bp

    for k,v in pairs opts
      continue if k == "base_path"
      @[k] = v

  exec: (cmd) =>
    -- colors = require "ansicolors"
    -- print colors("%{bright}%{red}exec: %{reset}") .. cmd
    os.execute cmd

  -- set the path of where nginx will run
  set_base_path: (p="") =>
    @base_path = p

    for k in *{"config_path", "config_path_etlua", "compiled_config_path"}
      @[k] = path.join @base_path, @@.__base[k]

  -- the -p prefix argument passed to nginx, accounting for relative base paths
  nginx_prefix: =>
    if @base_path\match "^/"
      "'#{shell_escape @base_path}'"
    else
      '"$(pwd)"/' .. "'#{shell_escape @base_path}'"

  -- create the logs directory and log files nginx expects to exist. nginx (even
  -- nginx -t) will refuse to start if the pid/log paths' directory is missing
  prepare_runtime: =>
    path.mkdir path.join @base_path, "logs"
    @exec "touch '#{shell_escape path.join @base_path, "logs/error.log"}'"
    @exec "touch '#{shell_escape path.join @base_path, "logs/access.log"}'"

  -- run nginx -t to validate the compiled config, returns true if valid. The
  -- output of nginx (including any error) is left on stderr for the user to see
  test_config: =>
    nginx = @find_nginx!
    return nil, "can't find nginx" unless nginx

    @prepare_runtime!

    cmd = nginx .. " -t -p #{@nginx_prefix!} -c '#{shell_escape path.filename @compiled_config_path}'"
    status = @exec cmd
    -- os.execute's return value differs between Lua versions: LuaJIT/5.1
    -- returns the exit code (0 on success), 5.2+ returns a success boolean
    status == true or status == 0

  start_nginx: (background=false) =>
    nginx = @find_nginx!
    return nil, "can't find nginx" unless nginx

    @prepare_runtime!

    cmd = nginx .. " -p #{@nginx_prefix!} -c '#{shell_escape path.filename @compiled_config_path}'"

    if background
      cmd = cmd .. " > /dev/null 2>&1 &"

    @exec cmd

  get_pid: =>
    pidfile = io.open path.join @base_path, "logs/nginx.pid"
    return unless pidfile
    pid = pidfile\read "*a"
    pidfile\close!
    pid\match "[^%s]+"

  send_signal: (signal) =>
    if pid = @get_pid!
      @exec "kill -s #{signal} #{pid}"
      pid

  send_hup: =>
    if pid = @get_pid!
      @exec "kill -HUP #{pid}"
      pid

  send_term: =>
    if pid = @get_pid!
      @exec "kill #{pid}"
      pid

  -- find the path to the (openresty) nginx binary
  find_nginx: =>
    return @_nginx_path if @_nginx_path

    -- check for overridden openresty path
    if to_check = os.getenv "LAPIS_OPENRESTY"
      if @check_binary_is_openresty to_check
        @_nginx_path = to_check
        return @_nginx_path

    for nginx_bin in *@nginx_bins
      for prefix in *@nginx_search_paths
        to_check = "#{prefix}#{nginx_bin}"

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

    server = @AttachedServer!
    server\start environment, env_overrides
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
  type: "nginx"
  nginx_runner: runner

  get_pid: runner\get_pid

  send_signal: runner\send_signal
  send_term: runner\send_term
  send_hup: runner\send_hup

  start_nginx: runner\start_nginx
  find_nginx: runner\find_nginx
  test_config: runner\test_config

  write_config_for: runner\write_config_for

  compile_config: compiler\compile_config
  compile_etlua_config: compiler\compile_etlua_config

  attach_server: runner\attach_server
  detach_server: runner\detach_server
}
