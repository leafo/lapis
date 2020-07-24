_env = nil

set_default_environment = (name) ->
  _env = name

default_environment = ->
  unless _env == nil
    return _env

  _env = os.getenv "LAPIS_ENVIRONMENT"

  import running_in_test from require "lapis.spec"
  if running_in_test!
    if _env == "production"
      error "You attempt to set the `production` environment name while running in a test suite"

    _env or= "test"
  elseif not _env
    _env = "development"
    pcall -> _env = require "lapis_environment"

  _env

local popper

-- force code to run in environment
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

{ :push, :pop, :assert_env, :default_environment, :set_default_environment }
