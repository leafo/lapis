local find_nginx, start_nginx, write_config_for, get_pid
do
  local _obj_0 = require("lapis.cmd.nginx")
  find_nginx, start_nginx, write_config_for, get_pid = _obj_0.find_nginx, _obj_0.start_nginx, _obj_0.write_config_for, _obj_0.get_pid
end
return {
  new = function(self, flags)
    local config_path, config_path_etlua
    do
      local _obj_0 = require("lapis.cmd.nginx").nginx_runner
      config_path, config_path_etlua = _obj_0.config_path, _obj_0.config_path_etlua
    end
    if self.path.exists(config_path) or self.path.exists(config_path_etlua) then
      self:fail_with_message("nginx.conf already exists")
    end
    if flags["etlua-config"] then
      self:write_file_safe(config_path_etlua, require("lapis.cmd.nginx.templates.config_etlua"))
    else
      self:write_file_safe(config_path, require("lapis.cmd.nginx.templates.config"))
    end
    return self:write_file_safe("mime.types", require("lapis.cmd.nginx.templates.mime_types"))
  end,
  server = function(self, flags, environment)
    local nginx = find_nginx()
    if not (nginx) then
      self:fail_with_message("can not find suitable server installation")
    end
    write_config_for(environment)
    return start_nginx()
  end
}
