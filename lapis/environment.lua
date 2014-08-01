local default_environment
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment = _obj_0.default_environment
end
local popper
local push
push = function(name)
  if name == nil then
    name = default_environment()
  end
  print("PUSHING", name)
  local config_module = require("lapis.config")
  local old_getter = config_module.get
  local config = old_getter(name)
  config_module.get = function()
    return config
  end
  local old_popper = popper
  popper = function()
    config_module.get = old_getter
    popper = old_popper
  end
end
local pop
pop = function()
  return assert(popper, "no environment pushed")()
end
return {
  push = push,
  pop = pop
}
