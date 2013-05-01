local url = require("socket.url")
local json = require("cjson")
local concat, insert = table.concat, table.insert
local floor = math.floor
local unescape
do
  local u = url.unescape
  unescape = function(str)
    return (u(str))
  end
end
local escape
do
  local e = url.escape
  escape = function(str)
    return (e(str))
  end
end
local escape_pattern
do
  local punct = "[%^$()%.%[%]*+%-?%%]"
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
  local tuple = Ct(chunk / unescape * "=" * (chunk / unescape) + chunk)
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
local encode_query_string
encode_query_string = function(t, sep)
  if sep == nil then
    sep = "&"
  end
  local i = 0
  local buf = { }
  for k, v in pairs(t) do
    if type(k) == "number" and type(v) == "table" then
      do
        local _obj_0 = v
        k, v = _obj_0[1], _obj_0[2]
      end
    end
    buf[i + 1] = escape(k)
    buf[i + 2] = "="
    buf[i + 3] = escape(v)
    buf[i + 4] = sep
    i = i + 4
  end
  buf[i] = nil
  return concat(buf)
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
local json_encodable
json_encodable = function(obj, seen)
  if seen == nil then
    seen = { }
  end
  local _exp_0 = type(obj)
  if "table" == _exp_0 then
    if not (seen[obj]) then
      seen[obj] = true
      return (function()
        local _tbl_0 = { }
        for k, v in pairs(obj) do
          _tbl_0[k] = json_encodable(v)
        end
        return _tbl_0
      end)()
    end
  elseif "function" == _exp_0 or "userdata" == _exp_0 or "thread" == _exp_0 then
    return nil
  else
    return obj
  end
end
local to_json
to_json = function(obj)
  return json.encode(json_encodable(obj))
end
local build_url
build_url = function(parts)
  local out = parts.path or ""
  if parts.query then
    out = out .. ("?" .. parts.query)
  end
  if parts.fragment then
    out = out .. ("#" .. parts.fragment)
  end
  do
    local host = parts.host
    if host then
      host = "//" .. host
      if parts.port then
        host = host .. (":" .. parts.port)
      end
      if parts.scheme then
        host = parts.scheme .. ":" .. host
      end
      if parts.path and out:sub(1, 1) ~= "/" then
        out = "/" .. out
      end
      out = host .. out
    end
  end
  return out
end
local time_ago
do
  local date
  pcall(function()
    date = require("date")
  end)
  time_ago = function(time)
    local diff = date.diff(date(true), date(time))
    local times = { }
    local days = floor(diff:spandays())
    if days >= 365 then
      local years = floor(diff:spandays() / 365)
      times.years = years
      insert(times, {
        "years",
        years
      })
      diff:addyears(-years)
      days = days - (years * 365)
    end
    if days >= 1 then
      times.days = days
      insert(times, {
        "days",
        days
      })
      diff:adddays(-days)
    end
    local hours = floor(diff:spanhours())
    if hours >= 1 then
      times.hours = hours
      insert(times, {
        "hours",
        hours
      })
      diff:addhours(-hours)
    end
    local minutes = floor(diff:spanminutes())
    if minutes >= 1 then
      times.minutes = minutes
      insert(times, {
        "minutes",
        minutes
      })
      diff:addminutes(-minutes)
    end
    local seconds = floor(diff:spanseconds())
    if seconds >= 1 or not next(times) then
      times.seconds = seconds
      insert(times, {
        "seconds",
        seconds
      })
      diff:addseconds(-seconds)
    end
    return times
  end
end
local time_ago_in_words
do
  local singular = {
    years = "year",
    days = "day",
    hours = "hour",
    minutes = "minute",
    second = "second"
  }
  time_ago_in_words = function(time, parts)
    if parts == nil then
      parts = 1
    end
    local ago = type(time) == "table" and time or time_ago(time)
    local out = ""
    local i = 1
    while parts > 0 do
      parts = parts - 1
      local segment = ago[i]
      i = i + 1
      if not (segment) then
        break
      end
      local val = segment[2]
      local word = val == 1 and singular[segment[1]] or segment[1]
      if #out > 0 then
        out = out .. ", "
      end
      out = out .. (val .. " " .. word)
    end
    return out .. " ago"
  end
end
return {
  unescape = unescape,
  escape = escape,
  escape_pattern = escape_pattern,
  parse_query_string = parse_query_string,
  parse_content_disposition = parse_content_disposition,
  parse_cookie_string = parse_cookie_string,
  encode_query_string = encode_query_string,
  underscore = underscore,
  slugify = slugify,
  uniquify = uniquify,
  trim = trim,
  trim_all = trim_all,
  trim_filter = trim_filter,
  key_filter = key_filter,
  to_json = to_json,
  json_encodable = json_encodable,
  build_url = build_url,
  time_ago = time_ago,
  time_ago_in_words = time_ago_in_words,
  camelize = camelize
}
