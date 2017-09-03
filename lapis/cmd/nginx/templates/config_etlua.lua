local config = require("lapis.cmd.nginx.templates.config")
local compile_config
compile_config = require("lapis.cmd.nginx").compile_config
local env = setmetatable({ }, {
  __index = function(self, key)
    return "<%- " .. tostring(key:lower()) .. " %>"
  end
})
return compile_config(config, env, {
  os_env = false,
  header = false
})
