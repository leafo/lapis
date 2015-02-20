
import type, tostring, pairs, select from _G

import
  FALSE
  NULL
  TRUE
  build_helpers
  format_date
  is_raw
  raw
  from require "lapis.db.base"

local conn, logger
local *

backends = {
  luasql: ->
    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing mysql configuration"

    luasql = require("luasql.mysql").mysql!
    conn = assert luasql\connect mysql_config.database, mysql_config.user

    raw_query = (q) ->
      logger.query q if logger
      cur = assert conn\execute q

      if type(cur) == "number"
        return { affected_rows: cur }

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
  switch type val
    when "number"
      return tostring val
    when "string"
      "'#{assert(conn)\escape val}'"
    when "boolean"
      return val and "TRUE" or "FALSE"
    when "table"
      return "NULL" if val == NULL
      return val[2] if is_raw val
      error "unknown table passed to `escape_literal`"
    else
      error "Don't know how to escape type #{type val}"

escape_identifier = (ident) ->
  return ident if is_raw ident
  ident = tostring ident
  '`' ..  (ident\gsub '`', '``') .. '`'

raw_query = (...) ->
  config = require("lapis.config").get!
  set_backend "luasql"
  raw_query ...

init_logger = ->
  config = require("lapis.config").get!
  logger = if ngx or os.getenv("LAPIS_SHOW_QUERIES") or config.show_queries
    require "lapis.logging"

interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers escape_literal, escape_identifier

query = (str, ...) ->
  if select("#", ...) > 0
    str = interpolate_query str, ...
  raw_query str

-- To be implemented
-- {
--   :parse_clause
-- 
--   select: _select
--   insert: _insert
--   update: _update
--   delete: _delete
--   truncate: _truncate
-- }

{
  :raw, :is_raw, :NULL, :TRUE, :FALSE,

  :encode_values
  :encode_assigns
  :encode_clause
  :interpolate_query

  :query
  :escape_literal
  :escape_identifier
  :set_backend
  :raw_query
  :format_date
  :init_logger
}
