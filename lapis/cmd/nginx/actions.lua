local unpack = unpack or table.unpack
return {
  new = function(self, args, template_flags)
    local find_nginx
    find_nginx = require("lapis.cmd.nginx").find_nginx
    local nginx = find_nginx()
    if not nginx and not args.force then
      self:fail_with_message("Unable to find an OpenResty installation on your system. You can bypass this error with --force or use LAPIS_OPENRESTY environment variable to directly specify the path of the OpenResty binary")
    end
    self:execute({
      "generate",
      "config",
      "--nginx",
      unpack(template_flags)
    })
    self:execute({
      "generate",
      "nginx.config",
      args.etlua_config and "--etlua" or nil
    })
    return self:execute({
      "generate",
      "nginx.mime_types"
    })
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
