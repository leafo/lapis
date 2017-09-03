{
  new: (flags) =>
    if @path.exists("config.lua")
      @fail_with_message "config.lua already exists"

    @write_file_safe "config.lua", require "lapis.cmd.cqueues.templates.config"

  server: (flags, environment) =>
    import push, pop from require "lapis.environment"
    import start_server from require "lapis.cmd.cqueues"

    push environment

    config = require("lapis.config").get!
    app_module = config.app_class or "app"
    start_server app_module

    pop!
}
