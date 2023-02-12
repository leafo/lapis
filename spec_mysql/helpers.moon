import push, pop from require "lapis.environment"
import before_each, after_each, setup, teardown, stub, assert from require "busted"

configure_mysql = ->
  local snapshot

  before_each -> snapshot = assert\snapshot!
  after_each -> snapshot\revert!

  setup ->
    push "test", {
      mysql: {
        user: "root"
        database: "lapis_test"
      }
    }

  teardown ->
    pop!

bind_query_log = (get_query_log) ->
  before_each ->
    logger = require "lapis.logging"
    stub(logger, "query").invokes (query) ->
      if queries = get_query_log!
        table.insert queries, query

{ :configure_mysql, :bind_query_log }

