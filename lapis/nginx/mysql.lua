local conn
local backends, set_backend, escape_literal, raw_query
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
raw_query = function(...)
  local config = require("lapis.config").get()
  set_backend("luasql")
  return raw_query(...)
end
return {
  escape_literal = escape_literal,
  raw_query = raw_query
}
