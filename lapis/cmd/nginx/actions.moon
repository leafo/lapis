import find_nginx, start_nginx, write_config_for, get_pid from require "lapis.cmd.nginx"

{
  new: (flags) =>
    import config_path, config_path_etlua from require("lapis.cmd.nginx").nginx_runner

    if @path.exists(config_path) or @path.exists(config_path_etlua)
      @fail_with_message "nginx.conf already exists"

    if flags["etlua-config"]
      @write_file_safe config_path_etlua, require "lapis.cmd.templates.config_etlua"
    else
      @write_file_safe config_path, require "lapis.cmd.templates.config"

    @write_file_safe "mime.types", require "lapis.cmd.templates.mime_types"

  server: (flags, environment) =>
    nginx = find_nginx!

    unless nginx
      @fail_with_message "can not find suitable server installation"

    write_config_for environment
    start_nginx!
}
