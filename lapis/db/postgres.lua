local concat
concat = table.concat
local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local unpack = unpack or table.unpack
local raw_query, raw_disconnect
local FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw, is_list, list, is_clause, clause, is_encodable
do
  local _obj_0 = require("lapis.db.base")
  FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw, is_list, list, is_clause, clause, is_encodable = _obj_0.FALSE, _obj_0.NULL, _obj_0.TRUE, _obj_0.build_helpers, _obj_0.format_date, _obj_0.is_raw, _obj_0.raw, _obj_0.is_list, _obj_0.list, _obj_0.is_clause, _obj_0.clause, _obj_0.is_encodable
end
local logger = require("lapis.logging")
local array
array = function(t)
  local PostgresArray
  PostgresArray = require("pgmoon.arrays").PostgresArray
  return PostgresArray(t)
end
local is_array
is_array = function(v)
  local PostgresArray
  PostgresArray = require("pgmoon.arrays").PostgresArray
  return getmetatable(v) == PostgresArray.__base
end
local _is_encodable
_is_encodable = function(item)
  if is_encodable(item) then
    return true
  end
  if is_array(item) then
    return true
  end
  return false
end
local gettime
local BACKENDS = {
  pgmoon = function()
    local after_dispatch, increment_perf, set_perf
    do
      local _obj_0 = require("lapis.nginx.context")
      after_dispatch, increment_perf, set_perf = _obj_0.after_dispatch, _obj_0.increment_perf, _obj_0.set_perf
    end
    local config = require("lapis.config").get()
    local pg_config = assert(config.postgres, "missing postgres configuration")
    local pgmoon_conn
    local measure_performance = not not config.measure_performance
    if measure_performance then
      gettime = require("socket").gettime
    end
    local _query
    _query = function(str)
      local use_nginx = ngx and ngx.ctx and ngx.socket
      local pgmoon
      if use_nginx then
        pgmoon = ngx.ctx.pgmoon
      else
        pgmoon = pgmoon_conn
      end
      if not (pgmoon) then
        local Postgres
        Postgres = require("pgmoon").Postgres
        pgmoon = Postgres(pg_config)
        if pg_config.timeout then
          local pg_timeout = assert(tonumber(pg_config.timeout), "timeout must be a number (ms)")
          pgmoon:settimeout(pg_timeout)
        end
        local success, connect_err = pgmoon:connect()
        if not (success) then
          error("postgres failed to connect: " .. tostring(connect_err))
        end
        if measure_performance then
          local _exp_0 = pgmoon.sock_type
          if "nginx" == _exp_0 then
            set_perf("pgmoon_conn", "nginx." .. tostring(pgmoon.sock:getreusedtimes() > 0 and "reuse" or "new"))
          else
            set_perf("pgmoon_conn", tostring(pgmoon.sock_type) .. ".new")
          end
        end
        if use_nginx then
          ngx.ctx.pgmoon = pgmoon
          after_dispatch(function()
            return pgmoon:keepalive()
          end)
        else
          pgmoon_conn = pgmoon
        end
      end
      local start_time
      if measure_performance then
        start_time = gettime()
      end
      local res, err = pgmoon:query(str)
      if start_time then
        local dt = gettime() - start_time
        increment_perf("db_time", dt)
        increment_perf("db_count", 1)
        logger.query(str, dt)
      else
        logger.query(str)
      end
      if not res and err then
        error(tostring(str) .. "\n" .. tostring(err))
      end
      return res
    end
    local _disconnect
    _disconnect = function()
      if not (pgmoon_conn) then
        return 
      end
      pgmoon_conn:disconnect()
      pgmoon_conn = nil
      return true
    end
    return _query, _disconnect
  end
}
local set_raw_query
set_raw_query = function(fn)
  raw_query = fn
end
local get_raw_query
get_raw_query = function()
  return raw_query
end
local escape_identifier
escape_identifier = function(ident)
  if is_raw(ident) then
    return ident[1]
  end
  if is_list(ident) then
    local escaped_items
    do
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = ident[1]
      for _index_0 = 1, #_list_0 do
        local item = _list_0[_index_0]
        _accum_0[_len_0] = escape_identifier(item)
        _len_0 = _len_0 + 1
      end
      escaped_items = _accum_0
    end
    assert(escaped_items[1], "can't flatten empty list")
    return "(" .. tostring(concat(escaped_items, ", ")) .. ")"
  end
  ident = tostring(ident)
  return '"' .. (ident:gsub('"', '""')) .. '"'
end
local escape_literal
escape_literal = function(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring((val:gsub("'", "''"))) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  elseif "table" == _exp_0 then
    if val == NULL then
      return "NULL"
    end
    if is_list(val) then
      local escaped_items
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = val[1]
        for _index_0 = 1, #_list_0 do
          local item = _list_0[_index_0]
          _accum_0[_len_0] = escape_literal(item)
          _len_0 = _len_0 + 1
        end
        escaped_items = _accum_0
      end
      assert(escaped_items[1], "can't flatten empty list")
      return "(" .. tostring(concat(escaped_items, ", ")) .. ")"
    end
    if is_array(val) then
      local encode_array
      encode_array = require("pgmoon.arrays").encode_array
      return encode_array(val, escape_literal)
    end
    if is_raw(val) then
      return val[1]
    end
    error("unknown table passed to `escape_literal`")
  end
  return error("don't know how to escape value: " .. tostring(val))
end
local interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers(escape_literal, escape_identifier)
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local connect
connect = function()
  local config = require("lapis.config").get()
  local backend_name = config.postgres and config.postgres.backend
  if not (backend_name) then
    backend_name = "pgmoon"
  end
  local backend = BACKENDS[backend_name]
  if not (backend) then
    error("Failed to find PostgreSQL backend: " .. tostring(backend_name))
  end
  raw_query, raw_disconnect = backend()
end
local disconnect
disconnect = function()
  assert(raw_disconnect, "no active connection")
  return raw_disconnect()
end
raw_query = function(...)
  connect()
  return raw_query(...)
end
local query
query = function(str, ...)
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  return raw_query(str)
end
local _select
_select = function(str, ...)
  return query("SELECT " .. str, ...)
end
local add_returning
add_returning = function(buff, first, cur, following, ...)
  if not (cur) then
    return 
  end
  if first then
    append_all(buff, " RETURNING ")
  end
  append_all(buff, escape_identifier(cur))
  if following then
    append_all(buff, ", ")
    return add_returning(buff, false, following, ...)
  end
end
local _insert
_insert = function(tbl, values, opts, ...)
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  local opts_type = type(opts)
  if opts_type == "string" or opts_type == "table" and is_raw(opts) then
    add_returning(buff, true, opts, ...)
  elseif opts_type == "table" then
    if opts.on_conflict then
      if opts.on_conflict == "do_nothing" then
        append_all(buff, " ON CONFLICT DO NOTHING")
      else
        error("db.insert: unsupported value for on_conflict option: " .. tostring(tostring(opts.on_conflict)))
      end
    end
    do
      local r = opts.returning
      if r then
        if r == "*" then
          add_returning(buff, true, raw("*"))
        else
          assert(type(r) == "table" and not is_raw(r), "db.insert: returning option must be a table array")
          add_returning(buff, true, unpack(r))
        end
      end
    end
  end
  return raw_query(concat(buff))
end
local add_cond
add_cond = function(buffer, cond, ...)
  append_all(buffer, " WHERE ")
  local _exp_0 = type(cond)
  if "table" == _exp_0 then
    return encode_clause(cond, buffer)
  elseif "string" == _exp_0 then
    return append_all(buffer, interpolate_query(cond, ...))
  end
end
local _update
_update = function(table, values, cond, ...)
  local buff = {
    "UPDATE ",
    escape_identifier(table),
    " SET "
  }
  encode_assigns(values, buff)
  if cond then
    add_cond(buff, cond, ...)
  end
  if type(cond) == "table" then
    add_returning(buff, true, ...)
  end
  return raw_query(concat(buff))
end
local _delete
_delete = function(table, cond, ...)
  local buff = {
    "DELETE FROM ",
    escape_identifier(table)
  }
  if cond then
    add_cond(buff, cond, ...)
  end
  if type(cond) == "table" then
    add_returning(buff, true, ...)
  end
  return raw_query(concat(buff))
end
local _truncate
_truncate = function(...)
  local tables = concat((function(...)
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      _accum_0[_len_0] = escape_identifier(t)
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(...), ", ")
  return raw_query("TRUNCATE " .. tables .. " RESTART IDENTITY")
end
local encode_case
encode_case = function(exp, t, on_else)
  local buff = {
    "CASE ",
    exp
  }
  for k, v in pairs(t) do
    append_all(buff, "\nWHEN ", escape_literal(k), " THEN ", escape_literal(v))
  end
  if on_else ~= nil then
    append_all(buff, "\nELSE ", escape_literal(on_else))
  end
  append_all(buff, "\nEND")
  return concat(buff)
end
return {
  __type = "postgres",
  connect = connect,
  disconnect = disconnect,
  query = query,
  raw = raw,
  is_raw = is_raw,
  list = list,
  is_list = is_list,
  array = array,
  is_array = is_array,
  clause = clause,
  is_clause = is_clause,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  encode_clause = encode_clause,
  interpolate_query = interpolate_query,
  format_date = format_date,
  encode_case = encode_case,
  set_raw_query = set_raw_query,
  get_raw_query = get_raw_query,
  parse_clause = require("lapis.db.postgres.parse_clause"),
  select = _select,
  insert = _insert,
  update = _update,
  delete = _delete,
  truncate = _truncate,
  is_encodable = _is_encodable,
  BACKENDS = BACKENDS
}
