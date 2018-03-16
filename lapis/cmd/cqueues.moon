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
    overrides or= {}
    overrides.logging = false

    assert not @current_server, "there's already a server thread"
    import AttachedServer from require "lapis.cmd.cqueues.attached_server"
    server = AttachedServer!
    server\start env, overrides
    @current_server = server
    @current_server

  detach_server: =>
    assert @current_server, "no current server"

class Server
  new: (@server) =>

  stop: =>
    @server\close!

  start: =>
    logger = require "lapis.logging"
    port = select 3, @server\localname!
    config = require("lapis.config").get!
    logger.start_server port, config._name
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
    host: config.bind_host or "0.0.0.0"
    port: assert config.port, "missing server port"

    :onstream
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
