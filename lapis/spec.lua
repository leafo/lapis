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
local assert_no_queries
assert_no_queries = function(fn)
  if fn == nil then
    fn = error("missing function")
  end
  local assert = require("luassert")
  local db = require("lapis.db")
  local old_query = db.get_raw_query()
  local query_log = { }
  db.set_raw_query(function(...)
    table.insert(query_log, (...))
    return old_query(...)
  end)
  local res, err = pcall(fn)
  db.set_raw_query(old_query)
  assert(res, err)
  return assert.same({ }, query_log)
end
return {
  use_test_env = use_test_env,
  use_test_server = use_test_server,
  assert_no_queries = assert_no_queries
}
