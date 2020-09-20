path = require "lapis.cmd.path"
import get_free_port from require "lapis.cmd.util"

loadstring = loadstring or load

import AttachedServer from require "lapis.cmd.attached_server"

class NginxAttachedServer extends AttachedServer
  new: (@runner) =>

  start: (environment, env_overrides) =>
    @existing_config = if path.exists @runner.compiled_config_path
      path.read_file @runner.compiled_config_path

    @port = get_free_port!

    if type(environment) == "string"
      environment = require("lapis.config").get environment

    if env_overrides
      assert not getmetatable(env_overrides), "env_overrides already has metatable, aborting"
      environment = setmetatable env_overrides, __index: environment

    env = require "lapis.environment"
    env.push environment

    @runner\write_config_for environment, @\process_config

    pid = @runner\get_pid!
    @fresh = not pid
    if pid
      @runner\send_hup!
    else
      assert @runner\start_nginx true

    @wait_until_ready!

  detach: =>
    if @existing_config
      path.write_file @runner.compiled_config_path, @existing_config

    if @fresh
      @runner\send_term!
      @wait_until_closed!
    else
      @runner\send_hup!

    env = require "lapis.environment"
    env.pop!

    true

  exec: (lua_code) =>
    assert loadstring lua_code -- syntax check code

    ltn12 = require "ltn12"
    http = require "socket.http"

    buffer = {}
    _, status = http.request {
      url: "http://127.0.0.1:#{@port}/run_lua"
      sink: ltn12.sink.table buffer
      source: ltn12.source.string lua_code
      headers: {
        "content-length": #lua_code
      }
    }

    unless status == 200
      error "Failed to exec code on server, got: #{status}\n\n#{table.concat buffer}"

    table.concat buffer

  -- this inserts a special server block in the config that gives remote access
  -- to it over a special port/location.
  process_config: (cfg) =>
    assert @port, "attached server doesn't have a port to bind rpc to"
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

    test_server = [[
      server {
        allow 127.0.0.1;
        deny all;
        listen ]] .. @port .. [[;

        location = /run_lua {
          client_body_buffer_size 10m;
          client_max_body_size 10m;
          content_by_lua "
            ]] .. run_code_action .. [[

          ";
        }
      }
    ]]

    -- inject the lua path
    if @runner.base_path != ""
      default_path = os.getenv "LUA_PATH"
      default_cpath = os.getenv "LUA_CPATH"

      server_path = path.join @runner.base_path, "?.lua"
      server_cpath = path.join @runner.base_path, "?.so"

      test_server = "
        lua_package_path '#{server_path};#{default_path}';
        lua_package_cpath '#{server_cpath};#{default_cpath}';
      " .. test_server


    cfg\gsub "%f[%a]http%s-{", "http {\n" .. test_server

{ AttachedServer: NginxAttachedServer }
