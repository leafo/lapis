unpack = unpack or table.unpack

{
  new: (args, template_flags) =>
    import find_nginx from require "lapis.cmd.nginx"
    nginx = find_nginx!

    if not nginx and not args.force
      @fail_with_message "Unable to find an OpenResty installation on your system. You can bypass this error with --force or use LAPIS_OPENRESTY environment variable to directly specify the path of the OpenResty binary"

    @execute {"generate", "config", "--nginx", unpack template_flags}
    @execute {"generate", "nginx.config", args.etlua_config and "--etlua" or nil}
    @execute {"generate", "nginx.mime_types" }

  server: (args) =>
    import find_nginx, start_nginx, write_config_for from require "lapis.cmd.nginx"

    {:environment} = args

    nginx = find_nginx!

    unless nginx
      @fail_with_message "Unable to find an OpenResty installation on your system. The LAPIS_OPENRESTY environment variable can be used to directly specify the path of the OpenResty binary"

    write_config_for environment
    start_nginx!
}
