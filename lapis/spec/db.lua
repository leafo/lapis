local assert_env
assert_env = require("lapis.environment").assert_env
local unpack = unpack or table.unpack
local truncate_tables
truncate_tables = function(...)
  local db = require("lapis.db")
  assert_env("test", {
    ["for"] = "truncate_tables"
  })
  local tables
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      local _exp_0 = type(t)
      if "table" == _exp_0 then
        _accum_0[_len_0] = t:table_name()
      elseif "nil" == _exp_0 then
        _accum_0[_len_0] = error("nil passed to truncate tables, perhaps a bad reference?")
      else
        _accum_0[_len_0] = t
      end
      _len_0 = _len_0 + 1
    end
    tables = _accum_0
  end
  for _index_0 = 1, #tables do
    local table = tables[_index_0]
    db.delete(table)
  end
end
local drop_tables
drop_tables = function(...)
  local db = require("lapis.db")
  assert_env("test", {
    ["for"] = "drop_tables"
  })
  local names
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      _accum_0[_len_0] = db.escape_identifier((function()
        if type(t) == "table" then
          return t:table_name()
        else
          return t
        end
      end)())
      _len_0 = _len_0 + 1
    end
    names = _accum_0
  end
  if not (next(names)) then
    return 
  end
  return db.query("drop table if exists " .. table.concat(names, ", "))
end
return {
  truncate_tables = truncate_tables,
  drop_tables = drop_tables
}
