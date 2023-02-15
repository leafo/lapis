
import type, tostring, pairs, select from _G
import concat from table

unpack = unpack or table.unpack

import
  NULL
  build_helpers
  is_raw
  is_list
  from require "lapis.db.base"

logger = require "lapis.logging"

-- NOTE: active connection only stored in local with luasql, otherwise request
-- context is used to store connection
local active_connection

local connect, raw_query

BACKENDS = {
  luasql: ->
    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing mysql configuration"

    luasql = require("luasql.mysql").mysql!
    conn_opts = { mysql_config.database, mysql_config.user, mysql_config.password }
    if mysql_config.host
      table.insert conn_opts, mysql_config.host
      if mysql_config.port then table.insert conn_opts, mysql_config.port

    -- Note that connection is established up front. This is
    -- necessary since connection is used for escaping literal when
    -- using lua sql. This is distinct from ngx mode which lazily
    -- establishes connection on first query
    active_connection = assert luasql\connect unpack(conn_opts)

    (q) ->
      logger.query q
      cur = assert active_connection\execute q
      has_rows = type(cur) != "number"

      result = {
        affected_rows: has_rows and cur\numrows! or cur
        last_auto_id: active_connection\getlastautoid!
      }

      if has_rows
        colnames = cur\getcolnames!
        coltypes = cur\getcoltypes!
        assert #colnames == #coltypes
        name2type = {}
        for i = 1, #colnames do
          colname = colnames[i]
          coltype = coltypes[i]
          name2type[colname] = coltype
        while true
          if row = cur\fetch {}, "a"
            for colname, value in pairs(row)
              coltype = name2type[colname]
              if coltype == 'number(1)'
                value = if value == '1' then true else false
              elseif coltype\match 'number'
                value = tonumber(value)
              row[colname] = value
            table.insert result, row
          else
            break

      result

  resty_mysql: ->
    import after_dispatch, increment_perf from require "lapis.nginx.context"

    config = require("lapis.config").get!
    mysql_config = assert config.mysql, "missing mysql configuration for resty_mysql"
    host = mysql_config.host or "127.0.0.1"
    port = mysql_config.port or 3306
    path = mysql_config.path
    database = assert mysql_config.database, "`database` missing from config for resty_mysql"
    user = assert mysql_config.user, "`user` missing from config for resty_mysql"
    password = mysql_config.password
    ssl = mysql_config.ssl
    ssl_verify = mysql_config.ssl_verify
    timeout = mysql_config.timeout or 10000 -- 10 seconds
    max_idle_timeout = mysql_config.max_idle_timeout or 10000 -- 10 seconds
    pool_size = mysql_config.pool_size or 100

    mysql = require "resty.mysql"

    (q) ->
      logger.query q

      db = ngx and ngx.ctx.resty_mysql_db
      unless db
        db, err = assert mysql\new()
        db\set_timeout(timeout)
        options = {
          :database, :user, :password, :ssl, :ssl_verify
        }

        if path
          options.path = path
        else
          options.host = host
          options.port = port

        if mysql_config.resty_mysql
          for k,v in pairs mysql_config.resty_mysql
            options[k] = v

        assert db\connect options

        if ngx
          ngx.ctx.resty_mysql_db = db
          after_dispatch ->
            db\set_keepalive(max_idle_timeout, pool_size)

      start_time = if ngx and config.measure_performance
        ngx.update_time!
        ngx.now!

      res, err, errcode, sqlstate = assert db\query q

      local result
      if err == 'again'
        result = {res}
        while err == 'again'
          res, err, errcode, sqlstate = assert db\read_result!
          table.insert result, res
      else
        result = res

      if start_time
        ngx.update_time!
        increment_perf "db_time", ngx.now! - start_time
        increment_perf "db_count", 1

      result
}

set_raw_query = (fn) ->
  raw_query = fn

get_raw_query = ->
  raw_query

escape_literal = (val) ->
  switch type val
    when "number"
      return tostring val
    when "string"
      if active_connection
        return "'#{active_connection\escape val}'"
      else if ngx
        return ngx.quote_sql_str(val)
      else
        connect!
        return escape_literal val
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

escape_identifier = (ident) ->
  return ident[1] if is_raw ident
  ident = tostring ident
  '`' ..  (ident\gsub '`', '``') .. '`'

connect = ->
  config = require("lapis.config").get!
  backend_name = config.mysql and config.mysql.backend

  use_nginx = ngx and ngx.ctx and ngx.socket

  unless backend_name
    backend_name = if use_nginx
      "resty_mysql"
    else
      "luasql"

  backend = BACKENDS[backend_name]
  unless backend
    error "Failed to find MySQL backend: #{backend_name}"

  raw_query = backend!

raw_query = (...) ->
  connect!
  raw_query ...

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
  buff = {
    "INSERT INTO "
    escape_identifier(tbl)
    " "
  }
  encode_values values, buff

  raw_query concat buff

_update = (table, values, cond, ...) ->
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

setmetatable {
  __type: "mysql"

  :connect

  :encode_values
  :encode_assigns
  :encode_clause
  :interpolate_query

  :query
  :escape_literal
  :escape_identifier

  :set_raw_query
  :get_raw_query

  select: _select
  insert: _insert
  update: _update
  delete: _delete
  truncate: _truncate

  :BACKENDS
}, __index: require "lapis.db.base"

