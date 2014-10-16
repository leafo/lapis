
url = require "socket.url"
json = require "cjson"

import concat, insert from table
import floor from math

local *

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

  char = (P(1) - S("=&"))

  chunk = C char^1
  chunk_0 = C char^0

  tuple = Ct(chunk / unescape * "=" * (chunk_0 / unescape) + chunk)
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
  {unescape(key), unescape(value) for key, value in str\gmatch("([^=%s]*)=([^;]*)")}

slugify = (str) ->
  (str\gsub("[%s_]+", "-")\gsub("[^%w%-]+", "")\gsub("-+", "-"))\lower!

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
-- optionally apply a key filter with second arg
-- set the value to replace empty strings with empty_val
trim_filter = (tbl, keys, empty_val) ->
  key_filter tbl, unpack keys if keys

  for k,v in pairs tbl
    if type(v) == "string"
      trimmed = trim v
      tbl[k] = if trimmed == "" then empty_val else trimmed

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
from_json = (obj) -> json.decode obj

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
    sooner = date time
    later = date true
    flip = false

    if later < sooner
      sooner, later = later, sooner

    diff = date.diff later, sooner

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

    times, true

time_ago_in_words = do
  singular = {
    years: "year"
    days: "day"
    hours: "hour"
    minutes: "minute"
    second: "second"
  }

  (time, parts=1, suffix="ago") ->
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

    out .. " " .. suffix

title_case = do
  upper = string.upper
  (str) ->
    (str\gsub "%S+", (chunk) ->
      chunk\gsub "^.", string.upper)


autoload = do
  try_require = (mod_name) ->
    local mod
    success, err = pcall ->
      mod = require mod_name

    if not success and not err\match "module '#{mod_name}' not found:"
      error err

    mod

  (...) ->
    prefixes = {...}
    last = prefixes[#prefixes]
    t = if type(last) == "table"
      prefixes[#prefixes] = nil
      last
    else
      {}

    assert next(prefixes), "missing prefixes for autoload"

    setmetatable t, __index: (mod_name) =>
      local mod

      for prefix in *prefixes
        mod = try_require prefix .. "." .. mod_name

        unless mod
          mod = try_require prefix .. "." .. underscore mod_name

        break if mod

      @[mod_name] = mod
      mod

auto_table = (fn) ->
  setmetatable {}, __index: (name) =>
    result = fn!
    getmetatable(@).__index = result
    result[name]


mixin_class = do
  empty_func = string.dump ->

  is_filled_function = (fn) ->
    fn and string.dump(fn) != empty_func

  combine_before = (existing, new) ->
    (...) ->
      new ...
      existing ...

  -- target: a class, to_mix: another class
  (target, to_mix, combine_methods=combine_before) ->
    base = target.__base

    -- copy members
    for member_name, member_val in pairs to_mix.__base
      continue if member_name\match "^__"

      if existing = base[member_name]
        if type(existing) == "function" and type(member_val) == "function"
          base[member_name] = combine_methods existing, member_val
          continue

      base[member_name] = member_val

    -- constructor
    new_ctor = to_mix.__init
    if is_filled_function new_ctor
      old_ctor = target.__init

      if is_filled_function old_ctor
        -- combine constructors
        target.__init = (...) ->
          old_ctor ...
          new_ctor ...
      else
        -- replace
        target.__init = new_ctor

-- helper for mixin_class that gets parent scope's self as target
mixin = do
  get_local = (search_name, level=1) ->
    level += 1
    i = 1
    while true
      name, val = debug.getlocal level, i
      break unless name
      if name == search_name
        return val
      i += 1

  (...) ->
    target = get_local "self", 2
    for to_mix in *{...}
      mixin_class target, to_mix


{ :unescape, :escape, :escape_pattern, :parse_query_string,
  :parse_content_disposition, :parse_cookie_string, :encode_query_string,
  :underscore, :slugify, :uniquify, :trim, :trim_all, :trim_filter,
  :key_filter, :to_json, :from_json, :json_encodable, :build_url, :time_ago,
  :time_ago_in_words, :camelize, :title_case, :autoload, :auto_table,
  :mixin_class, :mixin }
