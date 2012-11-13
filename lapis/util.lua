local escape_pattern
do
  local punct = "[%^$()%.%[%]*+%-?]"
  escape_pattern = function(str)
    return (str:gsub(punct, function(p)
      return "%" .. p
    end))
  end
end
local parse_query_string
do
  local C, P, S, Ct
  do
    local _table_0 = require("lpeg")
    C, P, S, Ct = _table_0.C, _table_0.P, _table_0.S, _table_0.Ct
  end
  parse_query_string = function(str)
    local chunk = C((P(1) - S("=&")) ^ 1)
    local tuple = Ct(chunk * "=" * chunk + chunk)
    local query = S("?#") ^ -1 * Ct(tuple * (P("&") * tuple) ^ 0)
    do
      local _with_0 = query:match(str)
      local out = _with_0
      if out then
        local _list_0 = out
        for _index_0 = 1, #_list_0 do
          tuple = _list_0[_index_0]
          out[tuple[1]] = tuple[2] or true
        end
      end
      return _with_0
    end
  end
end
return {
  escape_pattern = escape_pattern,
  parse_query_string = parse_query_string
}
