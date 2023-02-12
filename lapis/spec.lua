local use_test_env
use_test_env = function(env_name)
  if env_name == nil then
    env_name = "test"
  end
  local setup, teardown
  do
    local _obj_0 = require("busted")
    setup, teardown = _obj_0.setup, _obj_0.teardown
  end
  local env = require("lapis.environment")
  setup(function()
    return env.push(env_name)
  end)
  return teardown(function()
    return env.pop()
  end)
end
local use_test_server
use_test_server = function()
  local setup, teardown
  do
    local _obj_0 = require("busted")
    setup, teardown = _obj_0.setup, _obj_0.teardown
  end
  local load_test_server, close_test_server
  do
    local _obj_0 = require("lapis.spec.server")
    load_test_server, close_test_server = _obj_0.load_test_server, _obj_0.close_test_server
  end
  setup(function()
    return load_test_server()
  end)
  return teardown(function()
    return close_test_server()
  end)
end
local running_in_test
running_in_test = function()
  local busted = package.loaded.busted
  if busted and busted.publish then
    return "busted"
  end
  return false
end
return {
  use_test_env = use_test_env,
  use_test_server = use_test_server,
  running_in_test = running_in_test
}
