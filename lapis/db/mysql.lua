local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw
do
  local _obj_0 = require("lapis.db.base")
  FALSE, NULL, TRUE, build_helpers, format_date, is_raw, raw = _obj_0.FALSE, _obj_0.NULL, _obj_0.TRUE, _obj_0.build_helpers, _obj_0.format_date, _obj_0.is_raw, _obj_0.raw
end
local conn, logger
local backends, set_backend, escape_literal, escape_identifier, raw_query, init_logger, interpolate_query, encode_values, encode_assigns, encode_clause, query
backends = {
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
      if type(cur) == "number" then
        return {
          affected_rows = cur
        }
      end
      local result = {
        affected_rows = cur:numrows()
      }
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
escape_literal = function(val)
  local _exp_0 = type(val)
  if "number" == _exp_0 then
    return tostring(val)
  elseif "string" == _exp_0 then
    return "'" .. tostring(assert(conn):escape(val)) .. "'"
  elseif "boolean" == _exp_0 then
    return val and "TRUE" or "FALSE"
  elseif "table" == _exp_0 then
    if val == NULL then
      return "NULL"
    end
    if is_raw(val) then
      return val[2]
    end
    return error("unknown table passed to `escape_literal`")
  else
    return error("Don't know how to escape type " .. tostring(type(val)))
  end
end
escape_identifier = function(ident)
  if is_raw(ident) then
    return ident
  end
  ident = tostring(ident)
  return '`' .. (ident:gsub('`', '``')) .. '`'
end
raw_query = function(...)
  local config = require("lapis.config").get()
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
query = function(str, ...)
  if select("#", ...) > 0 then
    str = interpolate_query(str, ...)
  end
  return raw_query(str)
end
return {
  raw = raw,
  is_raw = is_raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  query = query,
  escape_literal = escape_literal,
  escape_identifier = escape_identifier,
  set_backend = set_backend,
  raw_query = raw_query,
  format_date = format_date,
  init_logger = init_logger
}
