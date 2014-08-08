
import type, tostring, pairs, select from _G
import NULL, TRUE, FALSE, raw, is_raw from require "lapis.db.base"

local conn
local *

backends = {
  luasql: ->
    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing mysql configuration"

    luasql = require("luasql.mysql").mysql!
    conn = assert luasql\connect mysql_config.database, mysql_config.user

    escape_literal = (q) ->
      conn\escape q

    raw_query = (q) ->
      cur = assert conn\execute q
      result = {
        affected_rows: cur\numrows!
      }

      while true
        if row = cur\fetch {}, "a"
          table.insert result, row
        else
          break

      result
}

set_backend = (name="default", ...) ->
  assert(backends[name]) ...

escape_literal = (val) ->
  assert(conn)\escape val

raw_query = (...) ->
  config = require("lapis.config").get!
  set_backend "luasql"
  raw_query ...

{
  :escape_literal
  :raw_query
}
