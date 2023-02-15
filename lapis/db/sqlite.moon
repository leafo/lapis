
import concat from table
import type, tostring, pairs, select from _G
unpack = unpack or table.unpack

base_db = require "lapis.db.base"

logger = require "lapis.logging"

import NULL, is_list, is_raw, raw from base_db

measure_performance = false
local gettime

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

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

-- loads the active configuration and creates the active connection
connect = ->
  if active_connection
    active_connection\close!
    active_connection = nil

  sqlite3 = require "lsqlite3"
  config =  require("lapis.config").get!
  db_name = config.sqlite and config.sqlite.database or "lapis.sqlite"
  open_flags = config.sqlite and config.sqlite.open_flags
  measure_performance = config.measure_performance

  if measure_performance
    gettime = require("socket").gettime

  active_connection = assert sqlite3.open db_name, open_flags

-- run a query to the active_connection, create connection if it doesn't exist
query = (str, ...) ->
  unless active_connection
    connect!

  if select("#", ...) > 0
    str = interpolate_query str, ...

  local start_time
  if measure_performance
    start_time = gettime!
  else
   -- log up front when we aren't collecting timing
    logger.query str

  result = [row for row in active_connection\nrows str]

  if start_time
    dt = gettime! - start_time
    logger.query str, dt


  result

-- Appends a list of column names as past of a returning clause via
-- tail recursion
-- buff: string fragment buffer to append to
-- first: is the the first call in series of recursive calls (initial caller should always set this to true
-- The calling varargs are split into the remaining arguments:
-- cur: the current value in varags
-- following: the next value in varargs
-- ...: remaining arguments
add_returning = (buff, first, cur, following, ...) ->
  return unless cur

  if first
    append_all buff, " RETURNING "

  append_all buff, escape_identifier cur

  if following
    append_all buff, ", "
    add_returning buff, false, following, ...

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_clause cond, buffer
    when "string"
      append_all buffer, interpolate_query cond, ...


-- NOTE: this is copied from postgresql as our implementations currently have
-- perfect overlap. In the future they may not though due to syntax
-- differences, hence the copy
insert = (tbl, values, opts, ...) ->
  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }

  if next values
    encode_values values, buff
  else
    append_all buff, "DEFAULT VALUES"

  opts_type = type(opts)

  if opts_type == "string" or opts_type == "table" and is_raw(opts)
    add_returning buff, true, opts, ...
  elseif opts_type == "table"
    if opts.on_conflict
      if opts.on_conflict == "do_nothing"
        append_all buff, " ON CONFLICT DO NOTHING"
      else
        error "db.insert: unsupported value for on_conflict option: #{tostring opts.on_conflict}"

    if r = opts.returning
      if r == "*"
        add_returning buff, true, raw "*"
      else
        assert type(r) == "table" and not is_raw(r), "db.insert: returning option must be a table array"
        add_returning buff, true, unpack r

  res = query concat buff
  res.affected_rows = active_connection\changes!
  res

_select = (str, ...) -> query "SELECT " .. str, ...

update = (table, values, cond, ...) ->
  buff = {
    "UPDATE "
    escape_identifier(table)
    " SET "
  }

  encode_assigns values, buff

  if cond
    add_cond buff, cond, ...

  if type(cond) == "table"
    add_returning buff, true, ...

  res = query concat buff
  res.affected_rows = active_connection\changes!
  res

delete = (table, cond, ...) ->
  buff = {
    "DELETE FROM "
    escape_identifier(table)
  }

  unless cond and next cond
    error "Blocking call to db.delete with no conditions. Use db.truncate"

  if cond
    add_cond buff, cond, ...

  if type(cond) == "table"
    add_returning buff, true, ...

  res = query concat buff
  res.affected_rows = active_connection\changes!
  res

truncate = (...) ->
  changes = 0
  for table in *{...}
    query "DELETE FROM #{escape_identifier table}"
    changes += active_connection\changes!

  { affected_rows: changes }

setmetatable {
  __type: "sqlite"

  :query
  :insert
  select: _select
  :update
  :delete
  :truncate

  :connect

  :escape_identifier
  :escape_literal

  :interpolate_query
  :encode_values
  :encode_assigns
  :encode_clause
}, __index: require "lapis.db.base"
