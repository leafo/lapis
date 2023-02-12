local concat
concat = table.concat
local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local unpack = unpack or table.unpack
local base_db = require("lapis.db.base")
local logger = require("lapis.logging")
local NULL, is_list, is_raw, raw
NULL, is_list, is_raw, raw = base_db.NULL, base_db.is_list, base_db.is_raw, base_db.raw
local measure_performance = false
local gettime
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local active_connection
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
    if is_raw(val) then
      return val[1]
    end
    error("unknown table passed to `escape_literal`")
  end
  return error("don't know how to escape value: " .. tostring(val))
end
local interpolate_query, encode_values, encode_assigns, encode_clause = base_db.build_helpers(escape_literal, escape_identifier)
local connect
connect = function()
  if active_connection then
    active_connection:close()
    active_connection = nil
  end
  local sqlite3 = require("lsqlite3")
  local config = require("lapis.config").get()
  local db_name = config.sqlite and config.sqlite.database or "lapis.sqlite"
  local open_flags = config.sqlite and config.sqlite.open_flags
  measure_performance = config.measure_performance
  if measure_performance then
    gettime = require("socket").gettime
  end
  active_connection = assert(sqlite3.open(db_name, open_flags))
end
local query
query = function(str, ...)
  if not (active_connection) then
    connect()
  end
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  local start_time
  if measure_performance then
    start_time = gettime()
  else
    logger.query(str)
  end
  local result
  do
    local _accum_0 = { }
    local _len_0 = 1
    for row in active_connection:nrows(str) do
      _accum_0[_len_0] = row
      _len_0 = _len_0 + 1
    end
    result = _accum_0
  end
  if start_time then
    local dt = gettime() - start_time
    logger.query(str, dt)
  end
  return result
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
local insert
insert = function(tbl, values, opts, ...)
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  if next(values) then
    encode_values(values, buff)
  else
    append_all(buff, "DEFAULT VALUES")
  end
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
  local res = query(concat(buff))
  res.affected_rows = active_connection:changes()
  return res
end
local _select
_select = function(str, ...)
  return query("SELECT " .. str, ...)
end
local update
update = function(table, values, cond, ...)
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
  local res = query(concat(buff))
  res.affected_rows = active_connection:changes()
  return res
end
local delete
delete = function(table, cond, ...)
  local buff = {
    "DELETE FROM ",
    escape_identifier(table)
  }
  if not (cond and next(cond)) then
    error("Blocking call to db.delete with no conditions. Use db.truncate")
  end
  if cond then
    add_cond(buff, cond, ...)
  end
  if type(cond) == "table" then
    add_returning(buff, true, ...)
  end
  local res = query(concat(buff))
  res.affected_rows = active_connection:changes()
  return res
end
local truncate
truncate = function(...)
  local changes = 0
  local _list_0 = {
    ...
  }
  for _index_0 = 1, #_list_0 do
    local table = _list_0[_index_0]
    query("DELETE FROM " .. tostring(escape_identifier(table)))
    changes = changes + active_connection:changes()
  end
  return {
    affected_rows = changes
  }
end
return setmetatable({
  __type = "sqlite",
  query = query,
  insert = insert,
  select = _select,
  update = update,
  delete = delete,
  truncate = truncate,
  connect = connect,
  escape_identifier = escape_identifier,
  escape_literal = escape_literal,
  interpolate_query = interpolate_query,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  encode_clause = encode_clause
}, {
  __index = require("lapis.db.base")
})
