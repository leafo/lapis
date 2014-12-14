local default_environment
default_environment = require("lapis.cmd.util").default_environment
local popper
local push
push = function(name_or_env, overrides)
  assert(name_or_env, "missing name or env for push")
  local config_module = require("lapis.config")
  local old_getter = config_module.get
  local env
  if type(name_or_env) == "table" then
    env = name_or_env
  else
    env = old_getter(name_or_env)
  end
  if overrides then
    env = setmetatable(overrides, {
      __index = env
    })
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
local assert_env
assert_env = function(env, opts)
  if opts == nil then
    opts = { }
  end
  local config = require("lapis.config").get()
  local pat
  if opts.exact then
    pat = "^" .. tostring(env) .. "$"
  else
    pat = "^" .. tostring(env)
  end
  if not (config._name:match(pat)) then
    local suffix = "(" .. tostring(pat) .. "), you are in `" .. tostring(config._name) .. "`"
    local msg
    do
      local feature = opts["for"]
      if feature then
        msg = "`" .. tostring(feature) .. "` can only be run in `" .. tostring(env) .. "` environment " .. tostring(suffix)
      else
        msg = "aborting, exepcting `" .. tostring(env) .. "` environment " .. tostring(suffix)
      end
    end
    error(msg)
  end
  return true
end
return {
  push = push,
  pop = pop,
  assert_env = assert_env
}
