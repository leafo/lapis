
import default_environment from require "lapis.cmd.util"

local popper

-- ensure that everything runs in test env, sets up db to execute queries
push = (name=default_environment!) ->
  config_module = require("lapis.config")
  old_getter = config_module.get

  config = old_getter name
  config_module.get = (...) ->
    if ...
      old_getter ...
    else
      config

  old_popper = popper
  popper = ->
    config_module.get = old_getter
    popper = old_popper

pop = ->
  assert(popper, "no environment pushed")!

{ :push, :pop }
