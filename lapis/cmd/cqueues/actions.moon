{
  new: (flags) =>
    -- no new files needed

  server: (flags, environment) =>
    import push, pop from require "lapis.environment"
    import start_server from require "lapis.cmd.cqueues"

    push environment

    config = require("lapis.config").get!
    cls = config.app_class or "app"

    app_cls = require(cls)

    app = if app_cls.__base -- is a class
      app_cls!
    else
      app_cls\build_router!
      app_cls

    start_server app

    pop!
}
