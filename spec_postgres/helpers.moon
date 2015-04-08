
import push, pop from require "lapis.environment"
import set_backend, init_logger from require "lapis.db.postgres"

setup_db = (opts) ->
  push "test", {
    postgres: {
      backend: "pgmoon"
      database: "lapis_test"
    }
  }

  set_backend "pgmoon"
  init_logger!

teardown_db = ->
  pop!

{:setup_db, :teardown_db}

