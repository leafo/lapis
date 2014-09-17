local db = require("lapis.db")
local truncate_tables
truncate_tables = function(...)
  local tables
  do
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local t = _list_0[_index_0]
      if type(t) == "table" then
        _accum_0[_len_0] = t:table_name()
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
return {
  truncate_tables = truncate_tables
}
