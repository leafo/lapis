
import default_environment from require "lapis.cmd.util"

local popper

-- ensure that everything runs in test env, sets up db to execute queries
push = (name_or_env) ->
  assert name_or_env, "missing name or env for push"

  config_module = require("lapis.config")
  old_getter = config_module.get

  env = if type(name_or_env) == "table"
    name_or_env
  else
    old_getter name_or_env

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

{ :push, :pop }
