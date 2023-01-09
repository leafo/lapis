{
  new: (args) =>
    valid_install = pcall ->
      require("cqueues")
      require("http.version")

    if not valid_install and not args.force
      @fail_with_message "Unable to load necessary modules for server. Please use LuaRocks to install `cqueues` and `http` modules. You can bypass this error with --force"

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
