
import concat from table
import type, tostring, pairs, select from _G
unpack = unpack or table.unpack

base_db = require "lapis.db.base"

logger = require "lapis.logging"

import NULL, is_list, is_raw from base_db
 
local active_connection

escape_identifier = (ident) ->
  return ident[1] if is_raw ident
  if is_list ident
    escaped_items = [escape_identifier item for item in *ident[1]]
    assert escaped_items[1], "can't flatten empty list"
    return "(#{concat escaped_items, ", "})"

  ident = tostring ident
  '"' ..  (ident\gsub '"', '""') .. '"'

escape_literal = (val) ->
  switch type val
    when "number"
      return tostring val
    when "string"
      return "'#{(val\gsub "'", "''")}'"
    when "boolean"
      return val and "TRUE" or "FALSE"
    when "table"
      return "NULL" if val == NULL
      if is_list val
        escaped_items = [escape_literal item for item in *val[1]]
        assert escaped_items[1], "can't flatten empty list"
        return "(#{concat escaped_items, ", "})"

      return val[1] if is_raw val
      error "unknown table passed to `escape_literal`"

  error "don't know how to escape value: #{val}"

interpolate_query, encode_values, encode_assigns, encode_clause = base_db.build_helpers escape_literal, escape_identifier

connect = ->
  if active_connection
    active_connection\close!
    active_connection = nil

  sqlite3 = require "lsqlite3"
  config =  require("lapis.config").get!
  db_name = config.sqlite and config.sqlite.database or "lapis.sqlite"
  active_connection = assert sqlite3.open db_name

-- auto-connecting query
query = (str, ...) ->
  unless active_connection
    connect!

  if select("#", ...) > 0
    str = interpolate_query str, ...

  if logger
    logger.query str

  return [row for row in active_connection\nrows str]

insert = (tbl, values, opts, ...) ->
  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff
  query concat buff

setmetatable {
  :query
  :insert

  :connect

  :escape_identifier
  :escape_literal

  :interpolate_query
  :encode_values
  :encode_assigns
  :encode_clause
}, __index: require "lapis.db.base"
