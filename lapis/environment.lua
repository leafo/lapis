local default_environment
do
  local _obj_0 = require("lapis.cmd.util")
  default_environment = _obj_0.default_environment
end
local popper
local push
push = function(name_or_env)
  assert(name_or_env, "missing name or env for push")
  local config_module = require("lapis.config")
  local old_getter = config_module.get
  local env
  if type(name_or_env) == "table" then
    env = name_or_env
  else
    env = old_getter(name_or_env)
  end
  config_module.get = function(...)
    if ... then
      return old_getter(...)
    else
      return env
    end
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
