
import to_json from require "lapis.util"

module_reset = ->
  keep = {k, true for k in pairs package.loaded}
  ->
    count = 0
    for mod in *[k for k in pairs package.loaded when not keep[k]]
      count += 1
      package.loaded[mod] = nil

    true, count

class Runner
  attach_server: (env, overrides) =>
    thread = require "cqueues.thread"
    assert not @current_thread, "there's already a server thread"
    -- TODO: add message passing for server

    @current_thread, @thread_socket = assert thread.start(
      (sock, env, overrides using nil) ->
        import from_json from require "lapis.util"
        import push, pop from require "lapis.environment"
        import start_server from require "lapis.cmd.cqueues"

        overrides = from_json overrides
        overrides = nil unless next overrides

        push env, overrides

        config = require("lapis.config").get!
        app_module = config.app_class or "app"
        start_server app_module

      env, to_json overrides or {}
    )

    {
      thread: @current_thread
      socket: @thread_socket
    }

  detach_server: =>
    assert @current_thread, "no current thread"

class Server
  new: (@server) =>

  stop: =>
    @server\close!

  start: =>
    port = select 3, @server\localname!
    print "Listening on #{port}"
    package.loaded["lapis.running_server"] = "cqueues"
    assert @server\loop!
    package.loaded["lapis.running_server"] = nil

create_server = (app_module) ->
  config = require("lapis.config").get!
  http_server = require "http.server"
  import dispatch from require "lapis.cqueues"

  load_app = ->
    app_cls = if type(app_module) == "string"
      require(app_module)
    else
      app_module

    if app_cls.__base -- is a class
      app_cls!
    else
      app_cls\build_router!
      app_cls

  onstream = if config.code_cache == false or config.code_cache == "off"
    reset = module_reset!
    (stream) =>
      reset!
      app = load_app!
      dispatch app, @, stream
  else
    app = load_app!
    (stream) => dispatch app, @, stream

  server = http_server.listen {
    host: "127.0.0.1"
    port: assert config.port, "missing server port"

    :onstream

    onerror: (context, op, err, errno) =>
      msg = op .. " on " .. tostring(context) .. " failed"
      if err
        msg = msg .. ": " .. tostring(err)

      assert io.stderr\write msg, "\n"
  }

  Server server

start_server =  (...) ->
  server = create_server ...
  server\start!

{
  type: "cqueues"
  :create_server
  :start_server
  runner:  Runner!
}
