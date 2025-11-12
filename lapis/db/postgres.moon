
import concat from table
import type, tostring, pairs, select from _G
unpack = unpack or table.unpack

POOL_PREFIX = "pgmoon_"

local configure

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


append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

array = (t) ->
  import PostgresArray from require "pgmoon.arrays"
  PostgresArray t

is_array = (v) ->
  import PostgresArray from require "pgmoon.arrays"
  getmetatable(v) == PostgresArray.__base

_is_encodable = (item) ->
  is_encodable(item) or is_array(item) or false

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

PG_DB_T = {
  __index: {
    __type: "postgres"

    :raw, :is_raw
    :list, :is_list
    :array, :is_array
    :clause, :is_clause

    :NULL, :TRUE, :FALSE

    :escape_literal, :escape_identifier, :encode_values, :encode_assigns,
    :encode_clause, :interpolate_query, :format_date,
    :encode_case

    is_encodable: _is_encodable

    parse_clause: require "lapis.db.postgres.parse_clause"
  }
}


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


-- creates a new postgres db object with independent connection pool
-- pool_name: unique name for connection pool storage in ngx.ctx
-- config: postgres configuration table (overrides default config)
configure = (pool_name, config) ->
  local db -- the db module that will be created
  assert type(config) == "table", "configure: config must be a table"

  local ctx_name

  if pool_name
    ctx_name = "#{POOL_PREFIX}#{pool_name}"

    -- bake the pool name into the config instead of using the default
    -- generated one by pgmoon
    config = {k,v for k,v in pairs config}
    config.pool_name or= ctx_name

  is_default_pool = pool_name == "default"

  import increment_perf from require "lapis.nginx.context"

  global_config = require("lapis.config").get!
  measure_performance = not not global_config.measure_performance

  gettime = if measure_performance
    require("socket").gettime

  -- the active connection when not stored in request context
  local pgmoon_conn, use_nginx

  connect = ->
    use_nginx = ngx and ngx.ctx and ngx.socket

    if use_nginx and ctx_name
      if ngx.ctx[ctx_name]
        return nil, "already connected"
    else
      if pgmoon_conn
        return nil, "already connected"

    import Postgres from require "pgmoon"
    pgmoon = Postgres config

    if config.timeout
      pg_timeout = assert tonumber(config.timeout), "timeout must be a number (ms)"
      pgmoon\settimeout pg_timeout

    success, connect_err = pgmoon\connect!

    if logger = db.logger
      if logger.db_connection
        logger.db_connection db, pgmoon, success, connect_err

    unless success
      error "postgres (#{pool_name}) failed to connect: #{connect_err}"

    -- NOTE: these are legacy metrics that have been removed in favor of the
    -- logging callback since they can innacurate if you have multiple
    -- connections happening per request
    -- if measure_performance
    --   switch pgmoon.sock_type
    --     when "nginx"
    --       set_perf "pgmoon_conn_#{pool_name}", "nginx.#{pgmoon.sock\getreusedtimes! > 0 and "reuse" or "new"}"
    --     else
    --       set_perf "pgmoon_conn_#{pool_name}", "#{pgmoon.sock_type}.new"

    if use_nginx
      import after_dispatch from require "lapis.nginx.context"

      if ctx_name
        ngx.ctx[ctx_name] = pgmoon
      else
        pgmoon_conn = pgmoon

      after_dispatch ->
        pgmoon\keepalive!
    else
      pgmoon_conn = pgmoon

    pgmoon

  connection_raw_query = (str) ->
    pgmoon = if use_nginx
      ngx.ctx[ctx_name]
    else
      pgmoon_conn

    unless pgmoon
      pgmoon = connect!

    start_time = if measure_performance
      gettime!

    res, err = pgmoon\query str

    query_time = if start_time
      with dt = gettime! - start_time
        -- TODO: consider moving performance callbacks into the logger
        increment_perf "db_time", dt
        increment_perf "db_count", 1

    -- TODO: consider a different naming convention here
    if logger = db.logger
      if logger.query
        if is_default_pool and ctx_name
          logger.query str, query_time
        else
          logger.query "#{pool_name}: #{str}", query_time

    if not res and err
      error "#{str}\n#{err}"
    res

  connection_raw_disconnect = ->
    return unless pgmoon_conn

    if use_nginx
      pgmoon_conn\keepalive!
    else
      pgmoon_conn\disconnect!

    pgmoon_conn = nil
    true

  -- create connection-specific query functions
  connection_query = (str, ...) ->
    if select("#", ...) > 0
      str = interpolate_query str, ...
    connection_raw_query str

  connection_select = (str, ...) ->
    connection_query "SELECT " .. str, ...

  connection_insert = (tbl, values, opts, ...) ->
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

    connection_raw_query concat buff

  connection_update = (table, values, cond, ...) ->
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

    connection_raw_query concat buff

  connection_delete = (table, cond, ...) ->
    buff = {
      "DELETE FROM "
      escape_identifier(table)
    }

    if cond
      add_cond buff, cond, ...

    if type(cond) == "table"
      add_returning buff, true, ...

    connection_raw_query concat buff

  connection_truncate = (...) ->
    tables = concat [escape_identifier t for t in *{...}], ", "
    connection_raw_query "TRUNCATE " .. tables .. " RESTART IDENTITY"

  connection_connect = ->
    connect!

  connection_disconnect = ->
    connection_raw_disconnect! if connection_raw_disconnect

  db = setmetatable {
    __pool_name: pool_name
    logger: require "lapis.logging"

    connect: connection_connect
    disconnect: connection_disconnect
    query: connection_query

    set_raw_query: (fn) ->
      connection_raw_query = fn

    get_raw_query: ->
      connection_raw_query

    select: connection_select
    insert: connection_insert
    update: connection_update
    delete: connection_delete
    truncate: connection_truncate
  }, PG_DB_T

  db

-- default connection when using lapis.db.postgres module directly, looks at
-- the configuration stored in config.postgres
local default_connection

get_default_connection = ->
  unless default_connection
    config = require("lapis.config").get!
    pg_config = assert config.postgres, "missing postgres configuration"
    default_connection = configure "default", pg_config
  default_connection

setmetatable {
  :configure

  set_default_connection: (db) ->
    default_connection = db

  -- proxy methods to the underlying default connection
  connect: ->
    get_default_connection!.connect!

  disconnect: ->
    get_default_connection!.disconnect!

  query: (str, ...) ->
    get_default_connection!.query str, ...

  set_raw_query: (fn) ->
    get_default_connection!.set_raw_query fn

  get_raw_query: ->
    get_default_connection!.get_raw_query!

  select: (str, ...) ->
    get_default_connection!.select str, ...

  insert: (tbl, values, opts, ...) ->
    get_default_connection!.insert tbl, values, opts, ...

  update: (table, values, cond, ...) ->
    get_default_connection!.update table, values, cond, ...

  delete: (table, cond, ...) ->
    get_default_connection!.delete table, cond, ...

  truncate: (...) ->
    get_default_connection!.truncate ...

}, PG_DB_T
