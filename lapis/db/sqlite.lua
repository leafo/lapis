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
local NULL, is_list, is_raw
NULL, is_list, is_raw = base_db.NULL, base_db.is_list, base_db.is_raw
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
  local lsqlite3 = require("lsqlite3")
  local config = require("lapis.config").get()
  local db_name = config.sqlite and config.sqlite.database or "lapis.sqlite"
  active_connection = assert(sqlite3.open(db_name))
end
local query
query = function(str, ...)
  if not (active_connection) then
    connect()
  end
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  if logger then
    logger.query(str)
  end
  local _accum_0 = { }
  local _len_0 = 1
  for row in active_connection:nrows(str) do
    _accum_0[_len_0] = row
    _len_0 = _len_0 + 1
  end
  return _accum_0
end
local insert
insert = function(tbl, values, opts, ...)
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  return query(concat(buff))
end
return setmetatable({
  query = query,
  insert = insert,
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
