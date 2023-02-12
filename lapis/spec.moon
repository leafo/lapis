
use_test_env = (env_name="test") ->
  import setup, teardown from require "busted"
  env = require "lapis.environment"

  setup -> env.push env_name
  teardown -> env.pop!

use_test_server = ->
  import setup, teardown from require "busted"
  import load_test_server, close_test_server from require "lapis.spec.server"

  setup -> load_test_server!
  teardown -> close_test_server!

-- used to determine if default environment should be test intead of development
-- should return the name of the test harness being used, otherwise false
running_in_test = ->
  busted = package.loaded.busted
  if busted and busted.publish
    return "busted"

  false

{:use_test_env, :use_test_server, :running_in_test}
