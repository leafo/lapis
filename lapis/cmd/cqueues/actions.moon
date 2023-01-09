{
  new: (args) =>
    writer = @make_template_writer!
    config_tpl = require "lapis.cmd.cqueues.templates.config"

    config_tpl.write writer, setmetatable {
      server: "cqueues"
    }, __index: args

  server: (args) =>
    {:environment} = args

    import push, pop from require "lapis.environment"
    import start_server from require "lapis.cmd.cqueues"

    push environment

    config = require("lapis.config").get!
    app_module = config.app_class or "app"
    start_server app_module

    pop!
}
