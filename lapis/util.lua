local url = require("socket.url")
local json = require("cjson")
local concat, insert
do
  local _obj_0 = table
  concat, insert = _obj_0.concat, _obj_0.insert
end
local unpack = unpack or table.unpack
local floor
floor = math.floor
local date = require("date")
local unescape, escape, escape_pattern, inject_tuples, parse_query_string, encode_query_string, parse_content_disposition, parse_cookie_string, slugify, underscore, camelize, uniquify, trim, trim_all, trim_filter, key_filter, encodable_userdata, json_encodable, to_json, from_json, build_url, date_diff, time_ago, time_ago_in_words, title_case, autoload, auto_table, get_fields, singularize
do
  local u = url.unescape
  unescape = function(str)
    return (u(str))
  end
end
do
  local e = url.escape
  escape = function(str)
    return (e(str))
  end
end
do
  local punct = "[%^$()%.%[%]*+%-?%%]"
  escape_pattern = function(str)
    return (str:gsub(punct, function(p)
      return "%" .. p
    end))
  end
end
inject_tuples = function(tbl)
  for _index_0 = 1, #tbl do
    local tuple = tbl[_index_0]
    tbl[tuple[1]] = tuple[2] or true
  end
end
do
  local C, P, S, Ct
  do
    local _obj_0 = require("lpeg")
    C, P, S, Ct = _obj_0.C, _obj_0.P, _obj_0.S, _obj_0.Ct
  end
  local char = (P(1) - S("=&"))
  local chunk = C(char ^ 1)
  local chunk_0 = C(char ^ 0)
  local tuple = Ct(chunk / unescape * "=" * (chunk_0 / unescape) + chunk)
  local query = S("?#") ^ -1 * Ct(tuple * (P("&") * tuple) ^ 0)
  parse_query_string = function(str)
    do
      local out = query:match(str)
      if out then
        inject_tuples(out)
      end
      return out
    end
  end
end
encode_query_string = function(t, sep)
  if sep == nil then
    sep = "&"
  end
  local _escape = ngx and ngx.escape_uri or escape
  local i = 0
  local buf = { }
  for k, v in pairs(t) do
    local _continue_0 = false
    repeat
      if type(k) == "number" and type(v) == "table" then
        k, v = v[1], v[2]
        if v == nil then
          v = true
        end
      end
      if v == false then
        _continue_0 = true
        break
      end
      buf[i + 1] = _escape(k)
      if v == true then
        buf[i + 2] = sep
        i = i + 2
      else
        buf[i + 2] = "="
        buf[i + 3] = _escape(v)
        buf[i + 4] = sep
        i = i + 4
      end
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
  buf[i] = nil
  return concat(buf)
end
do
  local C, R, P, S, Ct, Cg
  do
    local _obj_0 = require("lpeg")
    C, R, P, S, Ct, Cg = _obj_0.C, _obj_0.R, _obj_0.P, _obj_0.S, _obj_0.Ct, _obj_0.Cg
  end
  local white = S(" \t") ^ 0
  local token = C((R("az", "AZ", "09") + S("._-")) ^ 1)
  local value = (token + P('"') * C((1 - S('"')) ^ 0) * P('"')) / unescape
  local param = Ct(white * token * white * P("=") * white * value)
  local patt = Ct(Cg(token, "type") * (white * P(";") * param) ^ 0)
  parse_content_disposition = function(str)
    do
      local out = patt:match(str)
      if out then
        inject_tuples(out)
      end
      return out
    end
  end
end
parse_cookie_string = function(str)
  if not (str) then
    return { }
  end
  local _tbl_0 = { }
  for key, value in str:gmatch("([^=%s]*)=([^;]*)") do
    _tbl_0[unescape(key)] = unescape(value)
  end
  return _tbl_0
end
slugify = function(str)
  return (str:gsub("[%s_]+", "-"):gsub("[^%w%-]+", ""):gsub("-+", "-")):lower()
end
underscore = function(str)
  local words
  do
    local _accum_0 = { }
    local _len_0 = 1
    for word in str:gmatch("%L*%l+") do
      _accum_0[_len_0] = word:lower()
      _len_0 = _len_0 + 1
    end
    words = _accum_0
  end
  return concat(words, "_")
end
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
uniquify = function(list)
  local seen = { }
  return (function()
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #list do
      local _continue_0 = false
      repeat
        local item = list[_index_0]
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
trim = function(str)
  str = tostring(str)
  if #str > 200 then
    return str:gsub("^%s+", ""):reverse():gsub("^%s+", ""):reverse()
  else
    return str:match("^%s*(.-)%s*$")
  end
end
trim_all = function(tbl)
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      tbl[k] = trim(v)
    end
  end
  return tbl
end
trim_filter = function(tbl, keys, empty_val)
  if keys then
    key_filter(tbl, unpack(keys))
  end
  for k, v in pairs(tbl) do
    if type(v) == "string" then
      local trimmed = trim(v)
      if trimmed == "" then
        tbl[k] = empty_val
      else
        tbl[k] = trimmed
      end
    end
  end
  return tbl
end
key_filter = function(tbl, ...)
  local set
  do
    local _tbl_0 = { }
    local _list_0 = {
      ...
    }
    for _index_0 = 1, #_list_0 do
      local val = _list_0[_index_0]
      _tbl_0[val] = true
    end
    set = _tbl_0
  end
  for k, v in pairs(tbl) do
    if not (set[k]) then
      tbl[k] = nil
    end
  end
  return tbl
end
encodable_userdata = {
  [json.null] = true
}
if json.empty_array then
  encodable_userdata[json.empty_array] = true
end
json_encodable = function(obj, seen)
  if seen == nil then
    seen = { }
  end
  local _exp_0 = type(obj)
  if "table" == _exp_0 then
    if not (seen[obj]) then
      seen[obj] = true
      local _tbl_0 = { }
      for k, v in pairs(obj) do
        if type(k) == "string" or type(k) == "number" then
          _tbl_0[k] = json_encodable(v)
        end
      end
      return _tbl_0
    end
  elseif "userdata" == _exp_0 then
    return encodable_userdata[obj] and obj
  elseif "function" == _exp_0 or "thread" == _exp_0 then
    return nil
  else
    return obj
  end
end
to_json = function(obj)
  return json.encode(json_encodable(obj))
end
from_json = function(obj)
  return json.decode(obj)
end
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
        if parts.scheme ~= "" then
          host = parts.scheme .. ":" .. host
        end
      end
      if parts.path and out:sub(1, 1) ~= "/" then
        out = "/" .. out
      end
      out = host .. out
    end
  end
  return out
end
date_diff = function(later, sooner)
  if later < sooner then
    sooner, later = later, sooner
  end
  local diff = date.diff(later, sooner)
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
  return times, true
end
time_ago = function(time)
  return date_diff(date(true), date(time))
end
do
  local singular = {
    years = "year",
    days = "day",
    hours = "hour",
    minutes = "minute",
    seconds = "second"
  }
  time_ago_in_words = function(time, parts, suffix)
    if parts == nil then
      parts = 1
    end
    if suffix == nil then
      suffix = "ago"
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
    if suffix and suffix ~= "" then
      return out .. " " .. suffix
    else
      return out
    end
  end
end
title_case = function(str)
  return (str:gsub("%S+", function(chunk)
    return chunk:gsub("^.", string.upper)
  end))
end
do
  local try_require
  try_require = function(mod_name)
    local mod
    local success, err = pcall(function()
      mod = require(mod_name)
    end)
    if not success and not err:match("module '" .. tostring(mod_name) .. "' not found:") then
      error(err)
    end
    return mod
  end
  autoload = function(...)
    local prefixes = {
      ...
    }
    local last = prefixes[#prefixes]
    local t
    if type(last) == "table" then
      prefixes[#prefixes] = nil
      t = last
    else
      t = { }
    end
    assert(next(prefixes), "missing prefixes for autoload")
    return setmetatable(t, {
      __index = function(self, mod_name)
        local mod
        for _index_0 = 1, #prefixes do
          local prefix = prefixes[_index_0]
          mod = try_require(prefix .. "." .. mod_name)
          if not (mod) then
            mod = try_require(prefix .. "." .. underscore(mod_name))
          end
          if mod then
            break
          end
        end
        self[mod_name] = mod
        return mod
      end
    })
  end
end
auto_table = function(fn)
  return setmetatable({ }, {
    __index = function(self, name)
      local result = fn()
      getmetatable(self).__index = result
      return result[name]
    end
  })
end
get_fields = function(obj, key, ...)
  if not (obj) then
    return 
  end
  if not (key) then
    return 
  end
  return obj[key], get_fields(obj, ...)
end
singularize = function(name)
  local out = name:gsub("ies$", "y"):gsub("oes$", "o")
  if out:sub(-4, -1) == "sses" then
    out = out:gsub("sses$", "ss")
  else
    out = out:gsub("s$", "")
  end
  return out
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
  from_json = from_json,
  json_encodable = json_encodable,
  build_url = build_url,
  time_ago = time_ago,
  time_ago_in_words = time_ago_in_words,
  camelize = camelize,
  title_case = title_case,
  autoload = autoload,
  auto_table = auto_table,
  get_fields = get_fields,
  singularize = singularize,
  date_diff = date_diff
}
