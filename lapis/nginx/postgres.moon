
-- This is a simple interface form making queries to postgres on top of
-- ngx_postgres
--
-- Add the following upstream to your http:
--
-- upstream database {
--   postgres_server  127.0.0.1 dbname=... user=... password=...;
-- }
--
-- Add the following location to your server:
--
-- location /query {
--   postgres_pass database;
--   postgres_query $echo_request_body;
-- }
--

import concat from table

local raw_query

proxy_location = "/query"

local logger

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

backends = {
  default: (_proxy=proxy_location) ->
    parser = require "rds.parser"
    raw_query = (str) ->
      logger.query str if logger
      res, m = ngx.location.capture _proxy, {
        body: str
      }
      out, err = parser.parse res.body
      error "#{err}: #{str}" unless out

      if resultset = out.resultset
        return resultset
      out

  raw: (fn) ->
    with raw_query
      raw_query = fn

  pgmoon: ->
    import after_dispatch, increment_perf from require "lapis.nginx.context"

    config = require("lapis.config").get!
    pg_config = assert config.postgres, "missing postgres configuration"
    local pgmoon_conn

    raw_query = (str) ->
      pgmoon = ngx and ngx.ctx.pgmoon or pgmoon_conn

      unless pgmoon
        import Postgres from require "pgmoon"
        pgmoon = Postgres pg_config
        assert pgmoon\connect!

        if ngx
          ngx.ctx.pgmoon = pgmoon
          after_dispatch -> pgmoon\keepalive!
        else
          pgmoon_conn = pgmoon

      start_time = if ngx and config.measure_performance
        ngx.update_time!
        ngx.now!

      logger.query str if logger
      res, err = pgmoon\query str

      if start_time
        ngx.update_time!
        increment_perf "db_time", ngx.now! - start_time
        increment_perf "db_count", 1

      if not res and err
        error "#{str}\n#{err}"
      res
}

set_backend = (name="default", ...) ->
  assert(backends[name]) ...

init_logger = ->
  if ngx or os.getenv "LAPIS_SHOW_QUERIES"
    logger = require "lapis.logging"

init_db = ->
  config = require("lapis.config").get!
  default_backend = config.postgres and config.postgres.backend or "default"
  set_backend default_backend

escape_identifier = (ident) ->
  if type(ident) == "table" and ident[1] == "raw"
    return ident[2]

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
      if val[1] == "raw" and val[2]
        return val[2]

  error "don't know how to escape value: #{val}"

interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers escape_literal, escape_identifier

append_all = (t, ...) ->
  for i=1, select "#", ...
    t[#t + 1] = select i, ...

raw_query = (...) ->
  init_logger!
  init_db! -- sets raw query to default backend
  raw_query ...

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

  returning = {...}
  if next returning
    append_all buff, " RETURNING "
    for i, r in ipairs returning
      append_all buff, escape_identifier r
      append_all buff, ", " if i != #returning

  raw_query concat buff

add_cond = (buffer, cond, ...) ->
  append_all buffer, " WHERE "
  switch type cond
    when "table"
      encode_clause cond, buffer
    when "string"
      append_all buffer, interpolate_query cond, ...

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

-- truncate many tables
_truncate = (...) ->
  tables = concat [escape_identifier t for t in *{...}], ", "
  raw_query "TRUNCATE " .. tables .. " RESTART IDENTITY"

parse_clause = do
  local grammar

  make_grammar = ->
    basic_keywords = {"where", "having", "limit", "offset"}

    import P, R, C, S, Cmt, Ct, Cg, V from require "lpeg"

    alpha = R("az", "AZ", "__")
    alpha_num = alpha + R("09")
    white = S" \t\r\n"^0
    some_white = S" \t\r\n"^1
    word = alpha_num^1

    single_string = P"'" * (P"''" + (P(1) - P"'"))^0 * P"'"
    double_string = P'"' * (P'""' + (P(1) - P'"'))^0 * P'"'
    strings = single_string + double_string

    -- case insensitive word
    ci = (str) ->
      import S from require "lpeg"
      local p

      for c in str\gmatch "."
        char = S"#{c\lower!}#{c\upper!}"
        p = if p
          p * char
        else
          char
      p * -alpha_num

    balanced_parens = P {
      P"(" * (V(1) + strings + (P(1) - ")"))^0  * P")"
    }

    order_by = ci"order" * some_white * ci"by" / "order"
    group_by = ci"group" * some_white * ci"by" / "group"

    keyword = order_by + group_by

    for k in *basic_keywords
      part = ci(k) / k
      keyword += part

    keyword = keyword * white
    clause_content = (balanced_parens + strings + (word + P(1) - keyword))^1

    outer_join_type = (ci"left" + ci"right" + ci"full") * (white * ci"outer")^-1
    join_type = (ci"natural" * white)^-1 * ((ci"inner" + outer_join_type) * white)^-1
    start_join = join_type * ci"join"

    join_body = (balanced_parens + strings + (P(1) - start_join - keyword))^1
    join_tuple = Ct C(start_join) * C(join_body)

    joins = (#start_join * Ct join_tuple^1) / (joins) -> {"join", joins}

    clause = Ct (keyword * C clause_content)
    grammar = white * Ct joins^-1 * clause^0

  (clause) ->
    make_grammar! unless grammar
    if out = grammar\match clause
      { unpack t for t in *out }


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
  :query, :raw, :is_raw, :NULL, :TRUE, :FALSE, :escape_literal,
  :escape_identifier, :encode_values, :encode_assigns, :encode_clause,
  :interpolate_query, :parse_clause, :format_date, :encode_case

  :set_backend

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate
}
