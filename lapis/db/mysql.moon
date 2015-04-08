
import type, tostring, pairs, select from _G
import concat from table

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
  raw: (fn) ->
    with raw_query
      raw_query = fn

  luasql: ->
    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing mysql configuration"

    luasql = require("luasql.mysql").mysql!
    conn = assert luasql\connect mysql_config.database, mysql_config.user

    raw_query = (q) ->
      logger.query q if logger
      cur = assert conn\execute q
      has_rows = type(cur) != "number"

      result = {
        affected_rows: has_rows and cur\numrows! or cur
        last_auto_id: conn\getlastautoid!
      }

      if has_rows
        while true
          if row = cur\fetch {}, "a"
            table.insert result, row
          else
            break

      result
}

set_backend = (name="default", ...) ->
  assert(backends[name]) ...

escape_err = "a connection is required to escape a string literal"
escape_literal = (val) ->
  switch type val
    when "number"
      return tostring val
    when "string"
      return "'#{assert(conn, escape_err)\escape val}'"
    when "boolean"
      return val and "TRUE" or "FALSE"
    when "table"
      return "NULL" if val == NULL
      return val[2] if is_raw val
      error "unknown table passed to `escape_literal`"

  error "don't know how to escape value: #{val}"

escape_identifier = (ident) ->
  return ident[2] if is_raw ident
  ident = tostring ident
  '`' ..  (ident\gsub '`', '``') .. '`'

raw_query = (...) ->
  set_backend "luasql"
  raw_query ...

init_logger = ->
  config = require("lapis.config").get!
  logger = if ngx or os.getenv("LAPIS_SHOW_QUERIES") or config.show_queries
    require "lapis.logging"

interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers escape_literal, escape_identifier

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_clause cond, buffer
    when "string"
      append_all buffer, interpolate_query cond, ...

query = (str, ...) ->
  if select("#", ...) > 0
    str = interpolate_query str, ...
  raw_query str

_select = (str, ...) ->
  query "SELECT " .. str, ...


_insert = (tbl, values, ...) ->
  if values._timestamp
    values._timestamp = nil
    time = format_date!

    values.created_at or= time
    values.updated_at or= time

  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff

  raw_query concat buff

_update = (table, values, cond, ...) ->
  if values._timestamp
    values._timestamp = nil
    values.updated_at or= format_date!

  buff = {
    "UPDATE "
    escape_identifier(table)
    " SET "
  }

  encode_assigns values, buff

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

_delete = (table, cond, ...) ->
  buff = {
    "DELETE FROM "
    escape_identifier(table)
  }

  if cond
    add_cond buff, cond, ...

  raw_query concat buff

_truncate = (table) ->
  raw_query "TRUNCATE " .. escape_identifier table

-- To be implemented
-- {
--   :parse_clause
-- 
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

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate
}
