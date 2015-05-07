
path = require "lapis.cmd.path"

-- injects a debug server into the config
debug_config_process = (cfg, port) ->
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
  new: (@runner, opts) =>
    for k,v in pairs opts
      @[k] = v

    env = require "lapis.environment"
    env.push @environment

    pg_config = @environment.postgres
    if pg_config and not pg_config.backend == "pgmoon"
      db = require "lapis.db"
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
      path.write_file @runner.compiled_config_path, @existing_config

    if @fresh
      @runner\send_term!
      @wait_until_closed!
    else
      @runner\send_hup!

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


{ :AttachedServer, :debug_config_process }
