local _env = nil
local set_default_environment
set_default_environment = function(name)
  _env = name
end
local default_environment
default_environment = function()
  if not (_env == nil) then
    return _env
  end
  _env = os.getenv("LAPIS_ENVIRONMENT")
  local running_in_test
  running_in_test = require("lapis.spec").running_in_test
  if running_in_test() then
    if _env == "production" then
      error("You attempt to set the `production` environment name while running in a test suite")
    end
    _env = _env or "test"
  elseif not _env then
    _env = "development"
    pcall(function()
      _env = require("lapis_environment")
    end)
  end
  return _env
end
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
  assert_env = assert_env,
  default_environment = default_environment,
  set_default_environment = set_default_environment
}
