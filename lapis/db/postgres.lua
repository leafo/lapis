local concat
concat = table.concat
local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local unpack = unpack or table.unpack
local POOL_PREFIX = "pgmoon_"
local configure
local FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw, is_list, list, is_clause, clause, is_encodable
do
  local _obj_0 = require("lapis.db.base")
  FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw, is_list, list, is_clause, clause, is_encodable = _obj_0.FALSE, _obj_0.NULL, _obj_0.TRUE, _obj_0.build_helpers, _obj_0.format_date, _obj_0.is_raw, _obj_0.raw, _obj_0.is_list, _obj_0.list, _obj_0.is_clause, _obj_0.clause, _obj_0.is_encodable
end
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
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
  return is_encodable(item) or is_array(item) or false
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
local PG_DB_T = {
  __index = {
    __type = "postgres",
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
    is_encodable = _is_encodable,
    parse_clause = require("lapis.db.postgres.parse_clause")
  }
}
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
configure = function(pool_name, config)
  local db
  if type(pool_name) == "table" and type(config) == "nil" then
    config = pool_name
    pool_name = nil
  end
  assert(type(config) == "table", "configure: config must be a table")
  local ctx_name
  if pool_name then
    ctx_name = tostring(POOL_PREFIX) .. tostring(pool_name)
    do
      local _tbl_0 = { }
      for k, v in pairs(config) do
        _tbl_0[k] = v
      end
      config = _tbl_0
    end
    config.pool_name = config.pool_name or ctx_name
  end
  local is_default_pool = pool_name == "default"
  local increment_perf
  increment_perf = require("lapis.nginx.context").increment_perf
  local global_config = require("lapis.config").get()
  local measure_performance = not not global_config.measure_performance
  local gettime
  if measure_performance then
    gettime = require("socket").gettime
  end
  local pgmoon_conn, use_nginx, disconnect
  local connect
  connect = function()
    use_nginx = ngx and ngx.ctx and ngx.socket
    if use_nginx and ctx_name then
      if ngx.ctx[ctx_name] then
        return nil, "already connected"
      end
    else
      if pgmoon_conn then
        return nil, "already connected"
      end
    end
    local Postgres
    Postgres = require("pgmoon").Postgres
    local pgmoon = Postgres(config)
    if config.timeout then
      local pg_timeout = assert(tonumber(config.timeout), "timeout must be a number (ms)")
      pgmoon:settimeout(pg_timeout)
    end
    local success, connect_err = pgmoon:connect()
    do
      local logger = db.logger
      if logger then
        if logger.db_connection then
          logger.db_connection(db, pgmoon, success, connect_err)
        end
      end
    end
    if not (success) then
      error("postgres (" .. tostring(pool_name) .. ") failed to connect: " .. tostring(connect_err))
    end
    local disconnected = false
    disconnect = function()
      if disconnected then
        return nil, "already disconnected"
      end
      disconnected = true
      if use_nginx then
        pgmoon:keepalive()
      else
        pgmoon:disconnect()
      end
      if use_nginx and ctx_name then
        ngx.ctx[ctx_name] = nil
      else
        pgmoon_conn = nil
      end
      return true
    end
    if use_nginx then
      local after_dispatch
      after_dispatch = require("lapis.nginx.context").after_dispatch
      if ctx_name then
        ngx.ctx[ctx_name] = pgmoon
      else
        pgmoon_conn = pgmoon
      end
      after_dispatch(disconnect)
    else
      pgmoon_conn = pgmoon
    end
    return pgmoon
  end
  local connection_raw_query
  connection_raw_query = function(str)
    local pgmoon
    if use_nginx and ctx_name then
      pgmoon = ngx.ctx[ctx_name]
    else
      pgmoon = pgmoon_conn
    end
    if not (pgmoon) then
      pgmoon = connect()
    end
    if not (pgmoon) then
      error("pgmoon: connect passed nil result, this should not be possible")
    end
    local start_time
    if measure_performance then
      start_time = gettime()
    end
    local res, err = pgmoon:query(str)
    local query_time
    if start_time then
      do
        local dt = gettime() - start_time
        increment_perf("db_time", dt)
        increment_perf("db_count", 1)
        query_time = dt
      end
    end
    do
      local logger = db.logger
      if logger then
        if logger.query then
          if is_default_pool and ctx_name then
            logger.query(str, query_time)
          else
            logger.query(tostring(pool_name) .. ": " .. tostring(str), query_time)
          end
        end
      end
    end
    if not res and err then
      error(tostring(str) .. "\n" .. tostring(err))
    end
    return res
  end
  local connection_query
  connection_query = function(str, ...)
    if select("#", ...) > 0 then
      str = interpolate_query(str, ...)
    end
    return connection_raw_query(str)
  end
  local connection_select
  connection_select = function(str, ...)
    return connection_query("SELECT " .. str, ...)
  end
  local connection_insert
  connection_insert = function(tbl, values, opts, ...)
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
    return connection_raw_query(concat(buff))
  end
  local connection_update
  connection_update = function(table, values, cond, ...)
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
    return connection_raw_query(concat(buff))
  end
  local connection_delete
  connection_delete = function(table, cond, ...)
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
    return connection_raw_query(concat(buff))
  end
  local connection_truncate
  connection_truncate = function(...)
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
    return connection_raw_query("TRUNCATE " .. tables .. " RESTART IDENTITY")
  end
  db = setmetatable({
    __pool_name = pool_name,
    logger = require("lapis.logging"),
    connect = connect,
    disconnect = function()
      if disconnect then
        return disconnect()
      end
    end,
    query = connection_query,
    set_raw_query = function(fn)
      connection_raw_query = fn
    end,
    get_raw_query = function()
      return connection_raw_query
    end,
    select = connection_select,
    insert = connection_insert,
    update = connection_update,
    delete = connection_delete,
    truncate = connection_truncate
  }, PG_DB_T)
  return db
end
local default_connection
local get_default_connection
get_default_connection = function()
  if not (default_connection) then
    local config = require("lapis.config").get()
    local pg_config = assert(config.postgres, "missing postgres configuration")
    default_connection = configure("default", pg_config)
  end
  return default_connection
end
return setmetatable({
  configure = configure,
  set_default_connection = function(db)
    default_connection = db
  end,
  connect = function()
    return get_default_connection().connect()
  end,
  disconnect = function()
    return get_default_connection().disconnect()
  end,
  query = function(str, ...)
    return get_default_connection().query(str, ...)
  end,
  set_raw_query = function(fn)
    return get_default_connection().set_raw_query(fn)
  end,
  get_raw_query = function()
    return get_default_connection().get_raw_query()
  end,
  select = function(str, ...)
    return get_default_connection().select(str, ...)
  end,
  insert = function(tbl, values, opts, ...)
    return get_default_connection().insert(tbl, values, opts, ...)
  end,
  update = function(table, values, cond, ...)
    return get_default_connection().update(table, values, cond, ...)
  end,
  delete = function(table, cond, ...)
    return get_default_connection().delete(table, cond, ...)
  end,
  truncate = function(...)
    return get_default_connection().truncate(...)
  end
}, PG_DB_T)
