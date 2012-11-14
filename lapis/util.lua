local url = require("socket.url")
local unescape
do
  local u = require("socket.url").unescape
  unescape = function(str)
    return (u(str))
  end
end
local escape_pattern
do
  local punct = "[%^$()%.%[%]*+%-?]"
  escape_pattern = function(str)
    return (str:gsub(punct, function(p)
      return "%" .. p
    end))
  end
end
local inject_tuples
inject_tuples = function(tbl)
  local _list_0 = tbl
  for _index_0 = 1, #_list_0 do
    local tuple = _list_0[_index_0]
    tbl[tuple[1]] = tuple[2] or true
  end
end
local parse_query_string
do
  local C, P, S, Ct
  do
    local _table_0 = require("lpeg")
    C, P, S, Ct = _table_0.C, _table_0.P, _table_0.S, _table_0.Ct
  end
  local chunk = C((P(1) - S("=&")) ^ 1)
  local tuple = Ct(chunk * "=" * (chunk / unescape) + chunk)
  local query = S("?#") ^ -1 * Ct(tuple * (P("&") * tuple) ^ 0)
  parse_query_string = function(str)
    do
      local _with_0 = query:match(str)
      local out = _with_0
      if out then
        inject_tuples(out)
      end
      return _with_0
    end
  end
end
local parse_content_disposition
do
  local C, R, P, S, Ct, Cg
  do
    local _table_0 = require("lpeg")
    C, R, P, S, Ct, Cg = _table_0.C, _table_0.R, _table_0.P, _table_0.S, _table_0.Ct, _table_0.Cg
  end
  local white = S(" \t") ^ 0
  local token = C(R("az", "AZ", "__", "--", "09") ^ 1)
  local value = (token + P('"') * C((1 - S('"')) ^ 0) * P('"')) / unescape
  local param = Ct(white * token * white * P("=") * white * value)
  local patt = Ct(Cg(token, "type") * (white * P(";") * param) ^ 0)
  parse_content_disposition = function(str)
    do
      local _with_0 = patt:match(str)
      local out = _with_0
      if out then
        inject_tuples(out)
      end
      return _with_0
    end
  end
end
if ... == "test" then
  require("moon")
  moon.p(parse_query_string("hello=wo%22rld"))
end
return {
  unescape = unescape,
  escape_pattern = escape_pattern,
  parse_query_string = parse_query_string,
  parse_content_disposition = parse_content_disposition
}
