import concat from table
import type, tostring, pairs, select from _G

local raw_query
local logger

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
  from require "lapis.db.base"

backends = {
  -- the raw backend is a debug backend that lets you specify the function that
  -- handles the query
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

set_backend = (name, ...) ->
  assert(backends[name]) ...

init_logger = ->
  config = require("lapis.config").get!
  logger = if ngx or os.getenv("LAPIS_SHOW_QUERIES") or config.show_queries
    require "lapis.logging"

init_db = ->
  config = require("lapis.config").get!
  backend = config.postgres and config.postgres.backend
  unless backend
    backend = "pgmoon"

  set_backend backend

escape_identifier = (ident) ->
  return ident[1] if is_raw ident
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

add_returning = (buff, first, cur, following, ...) ->
  return unless cur

  if first
    append_all buff, " RETURNING "

  append_all buff, escape_identifier cur

  if following
    append_all buff, ", "
    add_returning buff, false, following, ...

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

  if ...
    add_returning buff, true, ...

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
    return {} if clause == ""

    make_grammar! unless grammar

    parsed = if tuples = grammar\match clause
      { unpack t for t in *tuples }

    if not parsed or (not next(parsed) and not clause\match "^%s*$")
      return nil, "failed to parse clause: `#{clause}`"

    parsed

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
  :query, :raw, :is_raw, :list, :is_list, :NULL, :TRUE, :FALSE, :escape_literal,
  :escape_identifier, :encode_values, :encode_assigns, :encode_clause,
  :interpolate_query, :parse_clause, :format_date, :encode_case, :init_logger

  :set_backend

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate
}
