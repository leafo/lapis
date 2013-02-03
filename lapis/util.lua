local url = require("socket.url")
local concat = table.concat
local Path
do
  local _table_0 = require("lapis.util.path")
  Path = _table_0.Path
end
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
  local token = C((R("az", "AZ", "09") + S("._-")) ^ 1)
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
local parse_cookie_string
parse_cookie_string = function(str)
  if not (str) then
    return { }
  end
  return (function()
    local _tbl_0 = { }
    for key, value in str:gmatch("([^=%s]*)=([^;]*)") do
      _tbl_0[key] = unescape(value)
    end
    return _tbl_0
  end)()
end
local slugify
slugify = function(str)
  return (str:gsub("%s+", "-"):gsub("[^%w%-_]+", "")):lower()
end
local underscore
underscore = function(str)
  local words = (function()
    local _accum_0 = { }
    local _len_0 = 1
    for word in str:gmatch("%L*%l+") do
      _accum_0[_len_0] = word:lower()
      _len_0 = _len_0 + 1
    end
    return _accum_0
  end)()
  return concat(words, "_")
end
local camelize
do
  local patt = "[^" .. tostring(escape_pattern("_")) .. "]+"
  camelize = function(str)
    return concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for part in str:gmatch(patt) do
        _accum_0[_len_0] = part:sub(1, 1):upper() .. part:sub(2)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)())
  end
end
local uniquify
uniquify = function(list)
  local seen = { }
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    local _list_0 = list
    for _index_0 = 1, #_list_0 do
      local _continue_0 = false
      repeat
        local item = _list_0[_index_0]
        if seen[item] then
          _continue_0 = true
          break
        end
        seen[item] = true
        local _value_0 = item
        _accum_0[_len_0] = _value_0
        _len_0 = _len_0 + 1
        _continue_0 = true
      until true
      if not _continue_0 then
        break
      end
    end
    return _accum_0
  end)()
end
local trim
trim = function(str)
  return tostring(str):match("^%s*(.-)%s*$")
end
local trim_all
trim_all = function(tbl)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = trim(v)
    end
  end
  return tbl
end
local trim_filter
trim_filter = function(tbl)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      local trimmed = trim(v)
      if trimmed == "" then
        tbl[k] = nil
      else
        tbl[k] = trimmed
      end
    end
  end
  return tbl
end
local key_filter
key_filter = function(tbl, ...)
  local set = (function(...)
    local _tbl_0 = { }
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local val = _list_0[_index_0]
      _tbl_0[val] = true
    end
    return _tbl_0
  end)(...)
  for k, v in pairs(tbl) do
    if not (set[k]) then
      tbl[k] = nil
    end
  end
  return tbl
end
if ... == "test" then
  require("moon")
  moon.p(parse_query_string("hello=wo%22rld"))
  print(underscore("ManifestRocks"))
  print(camelize(underscore("ManifestRocks")))
  print(camelize("hello"))
  print(camelize("world_wide_i_web"))
end
return {
  unescape = unescape,
  escape_pattern = escape_pattern,
  parse_query_string = parse_query_string,
  parse_content_disposition = parse_content_disposition,
  parse_cookie_string = parse_cookie_string,
  underscore = underscore,
  slugify = slugify,
  Path = Path,
  uniquify = uniquify,
  trim = trim,
  trim_all = trim_all,
  trim_filter = trim_filter,
  key_filter = key_filter
}
