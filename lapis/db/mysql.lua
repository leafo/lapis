local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local concat
concat = table.concat
local FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw
do
  local _obj_0 = require("lapis.db.base")
  FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw = _obj_0.FALSE, _obj_0.NULL, _obj_0.TRUE, _obj_0.build_helpers, _obj_0.format_date, _obj_0.is_raw, _obj_0.raw
end
local conn, logger
local backends, set_backend, escape_err, escape_literal, escape_identifier, raw_query, init_logger, interpolate_query, encode_values, encode_assigns, encode_clause, append_all, add_cond, query, _select, _insert, _update, _delete, _truncate
backends = {
  raw = function(fn)
    do
      raw_query = fn
      return raw_query
    end
  end,
  luasql = function()
    local config = require("lapis.config").get()
    local mysql_config = assert(config.mysql, "missing mysql configuration")
    local luasql = require("luasql.mysql").mysql()
    conn = assert(luasql:connect(mysql_config.database, mysql_config.user))
    raw_query = function(q)
      if logger then
        logger.query(q)
      end
      local cur = assert(conn:execute(q))
      local has_rows = type(cur) ~= "number"
      local result = {
        affected_rows = has_rows and cur:numrows() or cur,
        last_auto_id = conn:getlastautoid()
      }
      if has_rows then
        while true do
          do
            local row = cur:fetch({ }, "a")
            if row then
              table.insert(result, row)
            else
              break
            end
          end
        end
      end
      return result
    end
  end
}
set_backend = function(name, ...)
  if name == nil then
    name = "default"
  end
  return assert(backends[name])(...)
end
escape_err = "a connection is required to escape a string literal"
escape_literal = function(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring(assert(conn, escape_err):escape(val)) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  elseif "table" == _exp_0 then
    if val == NULL then
      return "NULL"
    end
    if is_raw(val) then
      return val[2]
    end
    error("unknown table passed to `escape_literal`")
  end
  return error("don't know how to escape value: " .. tostring(val))
end
escape_identifier = function(ident)
  if is_raw(ident) then
    return ident[2]
  end
  ident = tostring(ident)
  return '`' .. (ident:gsub('`', '``')) .. '`'
end
raw_query = function(...)
  set_backend("luasql")
  return raw_query(...)
end
init_logger = function()
  local config = require("lapis.config").get()
  if ngx or os.getenv("LAPIS_SHOW_QUERIES") or config.show_queries then
    logger = require("lapis.logging")
  end
end
interpolate_query, encode_values, encode_assigns, encode_clause = build_helpers(escape_literal, escape_identifier)
append_all = function(t, ...)
  for i = 1, select("#", ...) do
    t[#t + 1] = select(i, ...)
  end
end
add_cond = function(buffer, cond, ...)
  append_all(buffer, " WHERE ")
  local _exp_0 = type(cond)
  if "table" == _exp_0 then
    return encode_clause(cond, buffer)
  elseif "string" == _exp_0 then
    return append_all(buffer, interpolate_query(cond, ...))
  end
end
query = function(str, ...)
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  return raw_query(str)
end
_select = function(str, ...)
  return query("SELECT " .. str, ...)
end
_insert = function(tbl, values, ...)
  if values._timestamp then
    values._timestamp = nil
    local time = format_date()
    values.created_at = values.created_at or time
    values.updated_at = values.updated_at or time
  end
  local buff = {
    "INSERT INTO ",
    escape_identifier(tbl),
    " "
  }
  encode_values(values, buff)
  return raw_query(concat(buff))
end
_update = function(table, values, cond, ...)
  if values._timestamp then
    values._timestamp = nil
    values.updated_at = values.updated_at or format_date()
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
_truncate = function(table)
  return raw_query("TRUNCATE " .. escape_identifier(table))
end
return {
  raw = raw,
  is_raw = is_raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  encode_values = encode_values,
  encode_assigns = encode_assigns,
  encode_clause = encode_clause,
  interpolate_query = interpolate_query,
  query = query,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  set_backend = set_backend,
  raw_query = raw_query,
  format_date = format_date,
  init_logger = init_logger,
  select = _select,
  insert = _insert,
  update = _update,
  delete = _delete,
  truncate = _truncate
}
