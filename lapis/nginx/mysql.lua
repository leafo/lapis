local type, tostring, pairs, select
do
  local _obj_0 = _G
  type, tostring, pairs, select = _obj_0.type, _obj_0.tostring, _obj_0.pairs, _obj_0.select
end
local NULL, TRUE, FALSE, raw, is_raw, format_date
do
  local _obj_0 = require("lapis.db.base")
  NULL, TRUE, FALSE, raw, is_raw, format_date = _obj_0.NULL, _obj_0.TRUE, _obj_0.FALSE, _obj_0.raw, _obj_0.is_raw, _obj_0.format_date
end
local conn
local backends, set_backend, escape_literal, escape_identifier, raw_query
backends = {
  luasql = function()
    local config = require("lapis.config").get()
    local mysql_config = assert(config.mysql, "missing mysql configuration")
    local luasql = require("luasql.mysql").mysql()
    conn = assert(luasql:connect(mysql_config.database, mysql_config.user))
    escape_literal = function(q)
      return conn:escape(q)
    end
    raw_query = function(q)
      local cur = assert(conn:execute(q))
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
  return assert(conn):escape(val)
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
return {
  raw = raw,
  is_raw = is_raw,
  NULL = NULL,
  TRUE = TRUE,
  FALSE = FALSE,
  escape_literal = escape_literal,
  set_backend = set_backend,
  raw_query = raw_query,
  format_date = format_date
}
