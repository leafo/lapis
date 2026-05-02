unpack = unpack or table.unpack

{
  new: (args, template_flags) =>
    valid_install = pcall ->
      require("cqueues")
      require("http.version")

    if not valid_install and not args.force
      @fail_with_message "Unable to load necessary modules for server. Please use LuaRocks to install `cqueues` and `http` modules. You can bypass this error with --force"

    @execute {"generate", "config", "--cqueues", unpack template_flags}

  server: (args) =>
    {:environment} = args

    import push, pop from require "lapis.environment"
    import start_server from require "lapis.cmd.cqueues"

    push environment

    start_server require("lapis.config").get_app_module!

    pop!
}
