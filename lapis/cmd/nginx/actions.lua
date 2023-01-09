return {
  new = function(self, args)
    local find_nginx
    find_nginx = require("lapis.cmd.nginx").find_nginx
    local nginx = find_nginx()
    if not nginx and not args.force then
      self:fail_with_message("Unable to find an OpenResty installation on your system. You can bypass this error with --force or use LAPIS_OPENRESTY environment variable to directly specify the path of the OpenResty binary")
    end
    local config_path, config_path_etlua
    do
      local _obj_0 = require("lapis.cmd.nginx").nginx_runner
      config_path, config_path_etlua = _obj_0.config_path, _obj_0.config_path_etlua
    end
    if self.path.exists(config_path) or self.path.exists(config_path_etlua) then
      self:fail_with_message("nginx.conf already exists")
    end
    if args.etlua_config then
      self:write_file_safe(config_path_etlua, require("lapis.cmd.nginx.templates.config_etlua"))
    else
      self:write_file_safe(config_path, require("lapis.cmd.nginx.templates.config"))
    end
    self:write_file_safe("mime.types", require("lapis.cmd.nginx.templates.mime_types"))
    local writer = self:make_template_writer()
    local config_tpl = require("lapis.cmd.cqueues.templates.config")
    return config_tpl.write(writer, setmetatable({
      server = "nginx"
    }, {
      __index = args
    }))
  end,
  server = function(self, args)
    local find_nginx, start_nginx, write_config_for
    do
      local _obj_0 = require("lapis.cmd.nginx")
      find_nginx, start_nginx, write_config_for = _obj_0.find_nginx, _obj_0.start_nginx, _obj_0.write_config_for
    end
    local environment
    environment = args.environment
    local nginx = find_nginx()
    if not (nginx) then
      self:fail_with_message("Unable to find an OpenResty installation on your system. The LAPIS_OPENRESTY environment variable can be used to directly specify the path of the OpenResty binary")
    end
    write_config_for(environment)
    return start_nginx()
  end
}
