local parser = require("rds.parser")
local concat = table.concat
local logger = nil
local proxy_location = "/query"
local set_proxy_location
set_proxy_location = function(loc)
  proxy_location = loc
end
local set_logger
set_logger = function(l)
  logger = l
end
local NULL = { }
local raw
raw = function(val)
  return {
    "raw",
    tostring(val)
  }
end
local TRUE = raw("TRUE")
local FALSE = raw("FALSE")
local format_date
format_date = function(time)
  return os.date("!%Y-%m-%d %H:%M:%S", time)
end
local append_all
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
local escape_identifier
escape_identifier = function(ident)
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
    if val[1] == "raw" and val[2] then
      return val[2]
    end
  end
  return error("don't know how to escape value: " .. tostring(val))
end
local interpolate_query
interpolate_query = function(query, ...)
  local values = {
    ...
  }
  local i = 0
  return (query:gsub("%?", function()
    i = i + 1
    return escape_literal(values[i])
  end))
end
local encode_values
encode_values = function(t, buffer)
  local have_buffer = buffer
  buffer = buffer or { }
  local tuples = (function()
    local _accum_0 = { }
    local _len_0 = 1
    for k, v in pairs(t) do
      _accum_0[_len_0] = {
        k,
        v
      }
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
  local cols = concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = tuples
    for _index_0 = 1, #_list_0 do
      local pair = _list_0[_index_0]
      _accum_0[_len_0] = escape_identifier(pair[1])
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), ", ")
  local vals = concat((function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = tuples
    for _index_0 = 1, #_list_0 do
      local pair = _list_0[_index_0]
      _accum_0[_len_0] = escape_literal(pair[2])
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)(), ", ")
  append_all(buffer, "(", cols, ") VALUES (", vals, ")")
  if not (have_buffer) then
    return concat(buffer)
  end
end
local encode_assigns
encode_assigns = function(t, buffer, join)
  if join == nil then
    join = ", "
  end
  local have_buffer = buffer
  buffer = buffer or { }
  for k, v in pairs(t) do
    append_all(buffer, escape_identifier(k), " = ", escape_literal(v), join)
  end
  buffer[#buffer] = nil
  if not (have_buffer) then
    return concat(buffer)
  end
end
local raw_query
raw_query = function(str)
  if logger then
    logger.query(str)
  end
  local res, m = ngx.location.capture(proxy_location, {
    body = str
  })
  return parser.parse(res.body)
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
  local res, err = query("SELECT " .. str, ...)
  if res then
    return res.resultset
  else
    return nil, err
  end
end
local _insert
_insert = function(tbl, values, ...)
  if values._timestamp then
    values._timestamp = nil
    local time = format_date()
    values.created_at = time
    values.updated_at = time
  end
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  local returning = {
    ...
  }
  if next(returning) then
    append_all(buff, " RETURNING ")
    for i, r in ipairs(returning) do
      append_all(buff, escape_identifier(r))
      if i ~= #returning then
        append_all(buff, ", ")
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
    return encode_assigns(cond, buffer, " AND ")
  elseif "string" == _exp_0 then
    return append_all(buffer, interpolate_query(cond, ...))
  end
end
local _update
_update = function(table, values, cond, ...)
  if values._timestamp then
    values._timestamp = nil
    values.updated_at = format_date()
  end
  local buff = {
    "UPDATE ",
    escape_identifier(table),
    " SET "
  }
  encode_assigns(values, buff)
  if cond then
    add_cond(buff, cond, ...)
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
  return raw_query(concat(buff))
end
if ... == "test" then
  raw_query = function(str)
    return print("QUERY:", str)
  end
  print(escape_identifier('dad'))
  print(escape_identifier('select'))
  print(escape_identifier('love"fish'))
  local _ = print
  print(escape_literal(3434))
  print(escape_literal("cat's soft fur"))
  _ = print
  print(interpolate_query("select * from cool where hello = ?", "world"))
  print(interpolate_query("update x set x = ?", raw("y + 1")))
  _ = print
  local v = {
    hello = "world",
    age = 34
  }
  print(encode_values(v))
  print(encode_assigns(v))
  _ = print
  _select("* from things where id = ?", "cool days")
  _insert("cats", {
    age = 123,
    name = "catter"
  })
  _update("cats", {
    age = raw("age - 10")
  }, "name = ?", "catter")
  _update("cats", {
    age = raw("age - 10")
  }, {
    name = NULL
  })
  _update("cats", {
    color = "red"
  }, {
    weight = 1200,
    length = 392
  })
  _delete("cats")
  _delete("cats", "name = ?", "rump")
  _delete("cats", {
    name = "rump"
  })
  _delete("cats", {
    name = "rump",
    dad = "duck"
  })
  _insert("cats", {
    age = 123,
    name = "catter"
  }, "age")
  _insert("cats", {
    age = 123,
    name = "catter"
  }, "age", "name")
  _insert("cats", {
    hungry = true
  })
end
return {
  query = query,
  raw = raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  interpolate_query = interpolate_query,
  set_proxy_location = set_proxy_location,
  set_logger = set_logger,
  select = _select,
  insert = _insert,
  update = _update,
  delete = _delete
}
