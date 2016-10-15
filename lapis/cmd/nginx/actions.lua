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
      self:write_file_safe(config_path_etlua, require("lapis.cmd.templates.config_etlua"))
    else
      self:write_file_safe(config_path, require("lapis.cmd.templates.config"))
    end
    return self:write_file_safe("mime.types", require("lapis.cmd.templates.mime_types"))
  end
}
