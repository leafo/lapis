import concat from table
import type, tostring, pairs, select from _G
unpack = unpack or table.unpack

local raw_query, raw_disconnect

import
  FALSE
  NULL
  TRUE
  build_helpers
  format_date
  is_raw
  raw
  is_list
  list
  is_clause
  clause
  is_encodable
  from require "lapis.db.base"

logger = require "lapis.logging"

array = (t) ->
  import PostgresArray from require "pgmoon.arrays"
  PostgresArray t

is_array = (v) ->
  import PostgresArray from require "pgmoon.arrays"
  getmetatable(v) == PostgresArray.__base

_is_encodable = (item) ->
  return true if is_encodable item
  return true if is_array item
  false

local gettime

BACKENDS = {
  pgmoon: ->
    import after_dispatch, increment_perf, set_perf from require "lapis.nginx.context"

    config = require("lapis.config").get!
    pg_config = assert config.postgres, "missing postgres configuration"

    local pgmoon_conn

    measure_performance = not not config.measure_performance

    if measure_performance
      gettime = require("socket").gettime

    _query = (str) ->
      -- cache the connection in the nginx context if true, otherwise it there
      -- is one global connection cached for the instantiated backend
      use_nginx = ngx and ngx.ctx and ngx.socket

      pgmoon = if use_nginx
        ngx.ctx.pgmoon
      else
        pgmoon_conn

      unless pgmoon
        import Postgres from require "pgmoon"
        pgmoon = Postgres pg_config

        if pg_config.timeout
          pg_timeout = assert tonumber(pg_config.timeout), "timeout must be a number (ms)"
          pgmoon\settimeout pg_timeout

        success, connect_err = pgmoon\connect!
        unless success
          error "postgres failed to connect: #{connect_err}"

        if measure_performance
          switch pgmoon.sock_type
            when "nginx"
              set_perf "pgmoon_conn", "nginx.#{pgmoon.sock\getreusedtimes! > 0 and "reuse" or "new"}"
            else
              set_perf "pgmoon_conn", "#{pgmoon.sock_type}.new"

        if use_nginx
          ngx.ctx.pgmoon = pgmoon
          after_dispatch -> pgmoon\keepalive!
        else
          pgmoon_conn = pgmoon

      start_time = if measure_performance
        gettime!

      res, err = pgmoon\query str

      if start_time
        dt = gettime! - start_time
        increment_perf "db_time", dt
        increment_perf "db_count", 1
        logger.query str, dt
      else
        logger.query str

      if not res and err
        error "#{str}\n#{err}"
      res

    _disconnect = ->
      return unless pgmoon_conn

      pgmoon_conn\disconnect!
      pgmoon_conn = nil
      true

    _query, _disconnect
}

set_raw_query = (fn) ->
  raw_query = fn

get_raw_query = ->
  raw_query

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

      if is_array val
        import encode_array from require "pgmoon.arrays"
        return encode_array val, escape_literal

      return val[1] if is_raw val
      error "unknown table passed to `escape_literal`"

  error "don't know how to escape value: #{val}"

interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers escape_literal, escape_identifier

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

-- NOTE: this doesn't actually connect, sets up config for lazy connection on
-- next query
connect = ->
  config = require("lapis.config").get!
  backend_name = config.postgres and config.postgres.backend

  unless backend_name
    backend_name = "pgmoon"

  backend = BACKENDS[backend_name]
  unless backend
    error "Failed to find PostgreSQL backend: #{backend_name}"

  raw_query, raw_disconnect = backend!

disconnect = ->
  assert raw_disconnect, "no active connection"
  raw_disconnect!

-- this default implementation is replaced when the connection is established
raw_query = (...) ->
  connect!
  raw_query ...

query = (str, ...) ->
  if select("#", ...) > 0
    str = interpolate_query str, ...
  raw_query str

_select = (str, ...) ->
  query "SELECT " .. str, ...

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

_insert = (tbl, values, opts, ...) ->
  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff

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

  raw_query concat buff

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_clause cond, buffer
    when "string"
      append_all buffer, interpolate_query cond, ...

_update = (table, values, cond, ...) ->
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

  raw_query concat buff

_delete = (table, cond, ...) ->
  buff = {
    "DELETE FROM "
    escape_identifier(table)
  }

  if cond
    add_cond buff, cond, ...

  if type(cond) == "table"
    add_returning buff, true, ...

  raw_query concat buff

-- truncate many tables
_truncate = (...) ->
  tables = concat [escape_identifier t for t in *{...}], ", "
  raw_query "TRUNCATE " .. tables .. " RESTART IDENTITY"

encode_case = (exp, t, on_else) ->
  buff = {
    "CASE ", exp
  }

  for k,v in pairs t
    append_all buff, "\nWHEN ", escape_literal(k), " THEN ", escape_literal(v)

  if on_else != nil
    append_all buff, "\nELSE ", escape_literal on_else

  append_all buff, "\nEND"
  concat buff

{
  __type: "postgres"

  :connect
  :disconnect
  :query

  :raw, :is_raw
  :list, :is_list
  :array, :is_array
  :clause, :is_clause

  :NULL, :TRUE, :FALSE

  :escape_literal, :escape_identifier, :encode_values, :encode_assigns,
  :encode_clause, :interpolate_query, :format_date,
  :encode_case

  :set_raw_query
  :get_raw_query

  parse_clause: require "lapis.db.postgres.parse_clause"

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate
  is_encodable: _is_encodable

  :BACKENDS
}
