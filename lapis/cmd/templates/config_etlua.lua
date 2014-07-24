local config = require("lapis.cmd.templates.config")
local compile_config
do
  local _obj_0 = require("lapis.cmd.nginx")
  compile_config = _obj_0.compile_config
end
local env = setmetatable({ }, {
  __index = function(self, key)
    return "<%- " .. tostring(key:lower()) .. " %>"
  end
})
return compile_config(config, env, {
  os_env = false,
  header = false
})
