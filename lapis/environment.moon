
import default_environment from require "lapis.cmd.util"

local old_getter, old_backend

-- ensure that everything runs in test env, sets up db to execute queries
push = (name=default_environment!) ->
  assert not old_getter, "environment already pushed"

  config_module = require("lapis.config")
  old_getter = config_module.get
  config = old_getter name
  config_module.get = -> config

  -- TODO: make this part of setting default backend
  pg_config = config.postgres
  if pg_config and pg_config.backend == "pgmoon"
    logger = require("lapis.db").get_logger!
    logger = nil unless os.getenv "LAPIS_SHOW_QUERIES"

    db = require "lapis.nginx.postgres"
    import Postgres from require "pgmoon"

    local pgmoon

    old_backend = db.set_backend "raw", (...) ->
      unless pgmoon
        pgmoon = Postgres pg_config
        assert pgmoon\connect!

      logger.query ... if logger
      assert pgmoon\query ...

pop = ->
  assert old_getter!

  config_module = require("lapis.config")
  config_module.get = old_getter
  old_getter = nil

  db = require "lapis.nginx.postgres"
  db.set_backend "raw", old_backend
  old_backend = nil

{ :push, :pop }
