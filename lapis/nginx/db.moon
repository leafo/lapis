
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

local raw_query, dialect

proxy_location = "/query"

local logger

import type, tostring, pairs, select from _G

import NULL, TRUE, FALSE, raw, is_raw, format_date, build_helpers from require "lapis.db.base"

dialects = {
  postgres: {
    drop_index_if_exists: true
    explicit_time_zone: true
    identifier_quote: '"'
    index_where: true
    rename_column: true
    restart_identity: " RESTART IDENTITY"
    returning: true
    row_if_entity_exists: "0 from pg_class where relname = ? limit 1"
  }
  mysql: {
    identifier_quote: "`" -- ANSI_QUOTES is disabled by default
    restart_identity: ""
    row_if_entity_exists: "0 from information_schema.tables where table_schema = database() limit 1"
  }
}

backends = {
  default: (_proxy=proxy_location) ->
    parser = require "rds.parser"
    dialect = dialects.postgres
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

  raw: (fn, fn_dialect=dialects.postgres) ->
    dialect = fn_dialect
    with raw_query
      raw_query = fn

  pgmoon: ->
    import after_dispatch, increment_perf from require "lapis.nginx.context"
    config = require("lapis.config").get!
    pg_config = assert config.postgres, "missing postgres configuration"
    local pgmoon_conn

    dialect = dialects.postgres
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

  resty_mysql: ->
    import after_dispatch from require "lapis.nginx.context"
    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing postgres configuration"

    dialect = dialects.mysql
    raw_query = (str) ->
      mysql = ngx and ngx.ctx.mysql
      unless mysql
        mysql = assert (require "resty.mysql")\new!
        mysql\set_timeout mysql_config.read_timeout_ms or 1000
        assert mysql\connect mysql_config

        if ngx
          ngx.ctx.mysql = mysql
          after_dispatch ->
            mysql\set_keepalive mysql_config.idle_timeout_ms or 10000,
                                mysql_config.max_connections or   100

      logger.query "[mysql] #{str}" if logger
      assert mysql\query str
}

set_backend = (name="default", ...) ->
  assert(backends[name]) ...

init_logger = ->
  if ngx or os.getenv "LAPIS_SHOW_QUERIES"
    logger = require "lapis.logging"

init_db = ->
  default_backend = config.mysql and (config.mysql.backend or "resty_mysql")
  default_backend = default_backend or (config.postgres and config.postgres.backend)
  default_backend = default_backend or "default"
  set_backend default_backend

escape_identifier = (ident) ->
  if type(ident) == "table" and ident[1] == "raw"
    return ident[2]

  ident = tostring ident
  identifier_quote = dialect.identifier_quote
  identifier_quote ..  (ident\gsub identifier_quote, identifier_quote .. identifier_quote) .. identifier_quote

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

get_dialect = ->
  if not dialect
    init_logger!
    init_db! -- sets raw query to default backend
  dialect

raw_query = (...) ->
  get_dialect!
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
    error "RETURNING not implemented for mysql" unless dialect.returning
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
  raw_query "TRUNCATE " .. tables .. dialect.restart_identity

parse_clause = do
  local grammar
  make_grammar = ->
    keywords = {"where", "group", "having", "order", "limit", "offset"}
    for v in *keywords
      keywords[v] = true

    import P, R, C, S, Cmt, Ct, Cg from require "lpeg"

    alpha = R("az", "AZ", "__")
    alpha_num = alpha + R("09")
    white = S" \t\r\n"^0
    word = alpha_num^1

    single_string = P"'" * (P"''" + (P(1) - P"'"))^0 * P"'"
    double_string = P'"' * (P'""' + (P(1) - P'"'))^0 * P'"'
    strings = single_string + double_string

    keyword = Cmt word, (src, pos, cap) ->
      if keywords[cap\lower!]
        true, cap

    keyword = keyword * white

    clause = Ct (keyword * C (strings + (word + P(1) - keyword))^1) / (name, val) ->
      if name == "group" or name == "order"
        val = val\match "^%s*by%s*(.*)$"

      name, val

    grammar = white * Ct clause^0

  (clause) ->
    make_grammar! unless grammar
    if out = grammar\match clause
      { unpack t for t in *out }

{
  :query, :raw, :is_raw, :NULL, :TRUE, :FALSE, :escape_literal,
  :escape_identifier, :encode_values, :encode_assigns, :encode_clause,
  :interpolate_query, :parse_clause, :format_date,

  :set_backend, :get_dialect

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate
}
