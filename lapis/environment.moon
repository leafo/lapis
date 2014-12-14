
import default_environment from require "lapis.cmd.util"

local popper

-- force code to run in environment, sets up db to execute queries
push = (name_or_env, overrides) ->
  assert name_or_env, "missing name or env for push"

  config_module = require("lapis.config")
  old_getter = config_module.get

  env = if type(name_or_env) == "table"
    name_or_env
  else
    old_getter name_or_env

  if overrides
    env = setmetatable overrides, __index: env

  config_module.get = (...) ->
    if ...
      old_getter ...
    else
      env

  old_popper = popper
  popper = ->
    config_module.get = old_getter
    popper = old_popper

pop = ->
  assert(popper, "no environment pushed")!

-- assert_env "test", { for: "feature name", exact: true }
assert_env = (env, opts={}) ->
  config = require("lapis.config").get!
  pat = if opts.exact
    "^#{env}$"
  else
    "^#{env}"

  unless config._name\match pat
    suffix = "(#{pat}), you are in `#{config._name}`"

    msg = if feature = opts.for
      "`#{feature}` can only be run in `#{env}` environment #{suffix}"
    else
      "aborting, exepcting `#{env}` environment #{suffix}"

    error msg

  true

{ :push, :pop, :assert_env }
