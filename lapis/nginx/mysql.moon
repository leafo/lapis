
import type, tostring, pairs, select from _G
import NULL, TRUE, FALSE, raw, is_raw, format_date from require "lapis.db.base"

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

escape_identifier = (ident) ->
  return ident if is_raw ident
  ident = tostring ident
  '`' ..  (ident\gsub '`', '``') .. '`'

raw_query = (...) ->
  config = require("lapis.config").get!
  set_backend "luasql"
  raw_query ...


-- To be implemented
-- {
--   :query,
--   :escape_identifier
--   :encode_values
--   :encode_assigns
--   :encode_clause
--   :interpolate_query
--   :parse_clause
--   :format_date
-- 
--   select: _select
--   insert: _insert
--   update: _update
--   delete: _delete
--   truncate: _truncate
-- }


{
  :raw, :is_raw, :NULL, :TRUE, :FALSE,

  :escape_literal
  :set_backend
  :raw_query
  :format_date
}
