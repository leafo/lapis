
{
  new: (args) =>
    import find_nginx from require "lapis.cmd.nginx"
    nginx = find_nginx!

    if not nginx and not args.force
      @fail_with_message "Unable to find an OpenResty installation on your system. You can bypass this error with --force or use LAPIS_OPENRESTY environment variable to directly specify the path of the OpenResty binary"

    import config_path, config_path_etlua from require("lapis.cmd.nginx").nginx_runner

    if @path.exists(config_path) or @path.exists(config_path_etlua)
      @fail_with_message "nginx.conf already exists"

    if args.etlua_config
      @write_file_safe config_path_etlua, require "lapis.cmd.nginx.templates.config_etlua"
    else
      @write_file_safe config_path, require "lapis.cmd.nginx.templates.config"

    @write_file_safe "mime.types", require "lapis.cmd.nginx.templates.mime_types"

    writer = @make_template_writer!
    config_tpl = require "lapis.cmd.cqueues.templates.config"

    config_tpl.write writer, setmetatable {
      server: "nginx"
    }, __index: args

  server: (args) =>
    import find_nginx, start_nginx, write_config_for from require "lapis.cmd.nginx"

    {:environment} = args

    nginx = find_nginx!

    unless nginx
      @fail_with_message "Unable to find an OpenResty installation on your system. The LAPIS_OPENRESTY environment variable can be used to directly specify the path of the OpenResty binary"

    write_config_for environment
    start_nginx!
}
