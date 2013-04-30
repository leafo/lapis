
url = require "socket.url"
json = require "cjson"

import concat, insert from table
import floor from math

-- todo: consider renaming to url_escape/url_unescape
unescape = do
  u = url.unescape
  (str) -> (u str)

escape = do
  e = url.escape
  (str) -> (e str)

escape_pattern = do
  punct = "[%^$()%.%[%]*+%-?%%]"
  (str) -> (str\gsub punct, (p) -> "%"..p)

inject_tuples = (tbl) ->
  for tuple in *tbl
    tbl[tuple[1]] = tuple[2] or true

parse_query_string = do
  import C, P, S, Ct from require "lpeg"

  chunk = C (P(1) - S("=&"))^1
  tuple = Ct(chunk / unescape * "=" * (chunk / unescape) + chunk)
  query = S"?#"^-1 * Ct tuple * (P"&" * tuple)^0

  (str) ->
    with out = query\match str
      inject_tuples out if out

-- todo: handle nested tables
-- takes either { hello: "world"} or { {"hello", "world"} }
encode_query_string = (t, sep="&") ->
  i = 0
  buf = {}
  for k,v in pairs t
    if type(k) == "number" and type(v) == "table"
      {k,v} = v

    buf[i + 1] = escape k
    buf[i + 2] = "="
    buf[i + 3] = escape v
    buf[i + 4] = sep
    i += 4

  buf[i] = nil
  concat buf

parse_content_disposition = do
  import C, R, P, S, Ct, Cg from require "lpeg"

  white = S" \t"^0
  token = C (R("az", "AZ", "09") + S"._-")^1
  value = (token + P'"' * C((1 - S('"'))^0) * P'"') / unescape

  param = Ct white * token * white * P"=" * white * value

  patt = Ct Cg(token, "type") * (white * P";" * param)^0

  (str) ->
    with out = patt\match str
      inject_tuples out if out

parse_cookie_string = (str) ->
  return {} unless str
  {key, unescape(value) for key, value in str\gmatch("([^=%s]*)=([^;]*)")}

slugify = (str) ->
  (str\gsub("%s+", "-")\gsub("[^%w%-_]+", ""))\lower!

-- TODO: make this not suck
underscore = (str) ->
  words = [word\lower! for word in str\gmatch "%L*%l+"]
  concat words, "_"

camelize = do
  patt = "[^#{escape_pattern"_"}]+"
  (str) ->
    concat [part\sub(1,1)\upper! .. part\sub(2) for part in str\gmatch patt]

uniquify = (list) ->
  seen = {}
  return for item in *list
    continue if seen[item]
    seen[item] = true
    item

trim = (str) -> tostring(str)\match "^%s*(.-)%s*$"

trim_all = (tbl) ->
  for k,v in pairs tbl
    if type(v) == "string"
      tbl[k] = trim v
  tbl

-- remove empty string (all whitespace) values from table
trim_filter = (tbl) ->
  for k,v in pairs tbl
    if type(v) == "string"
      trimmed = trim v
      tbl[k] = if trimmed == "" then nil else trimmed
  tbl

-- remove all keys except those passed in
key_filter = (tbl, ...) ->
  set = {val, true for val in *{...}}
  for k,v in pairs tbl
    tbl[k] = nil unless set[k]
  tbl

json_encodable = (obj, seen={}) ->
  switch type obj
    when "table"
      unless seen[obj]
        seen[obj] = true
        { k, json_encodable(v) for k,v in pairs obj }
    when "function", "userdata", "thread"
      nil
    else
      obj

to_json = (obj) -> json.encode json_encodable obj

-- {
--     [path] = "/test"
--     [scheme] = "http"
--     [host] = "localhost.com"
--     [port] = "8080"
--     [fragment] = "yes"
--     [query] = "hello=world"
-- }
build_url = (parts) ->
  out = parts.path or ""
  out ..= "?" .. parts.query if parts.query
  out ..= "#" .. parts.fragment if parts.fragment

  if host = parts.host
    host = "//" .. host
    if parts.port
      host ..= ":" .. parts.port

    if parts.scheme
      host = parts.scheme .. ":" .. host

    if parts.path and out\sub(1,1) != "/"
      out = "/" .. out

    out = host .. out

  out

time_ago = do
  -- TODO: make this a dependency
  local date
  pcall -> date = require "date"

  (time) ->
    diff = date.diff date(true), date(time)

    times = {}

    days = floor diff\spandays()

    if days >= 365
      years = floor diff\spandays() / 365
      times.years = years
      insert times, {"years", years}

      diff\addyears -years
      days -= years * 365

    if days >= 1
      times.days = days
      insert times, {"days", days}

      diff\adddays -days

    hours = floor diff\spanhours()
    if hours >= 1
      times.hours = hours
      insert times, {"hours", hours}

      diff\addhours -hours

    minutes = floor diff\spanminutes()
    if minutes >= 1
      times.minutes = minutes
      insert times, {"minutes", minutes}

      diff\addminutes -minutes

    seconds = floor diff\spanseconds()
    if seconds >= 1 or not next(times)
      times.seconds = seconds
      insert times, {"seconds", seconds}

      diff\addseconds -seconds

    times

time_ago_in_words = do
  singular = {
    years: "year"
    days: "day"
    hours: "hour"
    minutes: "minute"
    second: "second"
  }

  (time, parts=1) ->
    ago = type(time) == "table" and time or time_ago time

    out = ""
    i = 1
    while parts > 0
      parts -= 1
      segment = ago[i]
      i += 1
      break unless segment

      val = segment[2]
      word = val == 1 and singular[segment[1]] or segment[1]
      out ..= ", " if #out > 0
      out ..= val .. " " .. word

    out .. " ago"


{ :unescape, :escape, :escape_pattern, :parse_query_string,
  :parse_content_disposition, :parse_cookie_string, :encode_query_string,
  :underscore, :slugify, :uniquify, :trim, :trim_all, :trim_filter,
  :key_filter, :to_json, :json_encodable, :build_url, :time_ago,
  :time_ago_in_words, :camelize }
