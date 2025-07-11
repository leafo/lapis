
url = require "socket.url"
json = require "cjson"

import concat, insert from table
unpack = unpack or table.unpack
import floor from math

date = require "date"

local *

---URL decode a string
---@param str string
---@return string
-- todo: consider renaming to url_escape/url_unescape
unescape = do
  u = url.unescape
  (str) -> (u str)

---URL encode a string
---@param str string
---@return string
escape = do
  e = url.escape
  (str) -> (e str)

---Escape special pattern characters in a string for use in Lua patterns
---@param str string
---@return string
escape_pattern = do
  punct = "[%^$()%.%[%]*+%-?%%]"
  (str) -> (str\gsub punct, (p) -> "%"..p)

---Convert array of tuples to a table with key-value pairs
---@param tbl table[] Array of tuples where each tuple is {key, value}
---@return table
inject_tuples = (tbl) ->
  for tuple in *tbl
    tbl[tuple[1]] = tuple[2] or true

---Parse a URL query string into a table
---@param str string With or without leading ? or #
---@return table|nil
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

---Encode a table as a query string
---@param t table Table with key-value pairs or array of tuples
---@param sep? string Separator between parameters (default: "&")
---@return string
-- todo: handle nested tables
-- takes either { hello: "world"} or { {"hello", "world"} }
encode_query_string = (t, sep="&") ->
  _escape = ngx and ngx.escape_uri or escape

  i = 0
  buf = {}
  for k,v in pairs t
    if type(k) == "number" and type(v) == "table"
      {k,v} = v
      v = true if v == nil -- symmetrical with parse

    if v == false
      continue

    buf[i + 1] = _escape k
    if v == true
      buf[i + 2] = sep
      i += 2
    else
      buf[i + 2] = "="
      buf[i + 3] = _escape v
      buf[i + 4] = sep
      i += 4

  buf[i] = nil
  concat buf

---Parse HTTP Content-Disposition header
---@param str string
---@return table|nil
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

---Parse HTTP Cookie header string
---@param str string|nil
---@return table cookies Empty table if str is nil
parse_cookie_string = (str) ->
  return {} unless str
  {unescape(key), unescape(value) for key, value in str\gmatch("([^=%s]*)=([^;]*)")}

---Convert a string to a URL-friendly slug
---@param str string
---@return string slug Lowercase, hyphens for spaces/underscores
slugify = (str) ->
  (str\gsub("[%s_]+", "-")\gsub("[^%w%-]+", "")\gsub("-+", "-"))\lower!

---Convert a string to underscore_case
---@param str string
---@return string
-- TODO: make this not suck
underscore = (str) ->
  words = [word\lower! for word in str\gmatch "%L*%l+"]
  concat words, "_"

---Convert a string to CamelCase
---@param str string Typically underscore_case
---@return string
camelize = do
  patt = "[^#{escape_pattern"_"}]+"
  (str) ->
    concat [part\sub(1,1)\upper! .. part\sub(2) for part in str\gmatch patt]

---Remove duplicate items from a list
---@param list any[]
---@return any[] unique_list New list with duplicates removed
uniquify = (list) ->
  seen = {}
  return for item in *list
    continue if seen[item]
    seen[item] = true
    item

---Remove leading and trailing whitespace from a string
---@param str string|number Will be converted to string
---@return string
trim = (str) ->
  str = tostring str

  if #str > 200
    str\gsub("^%s+", "")\reverse()\gsub("^%s+", "")\reverse()
  else
    str\match "^%s*(.-)%s*$"

---Trim all string values in a table
---@param tbl table
---@return table trimmed Same table with string values trimmed
trim_all = (tbl) ->
  for k,v in pairs tbl
    if type(v) == "string"
      tbl[k] = trim v
  tbl

---Trim and filter empty string values from a table
---@param tbl table
---@param keys? string[] Key filter to apply first
---@param empty_val? any Value to replace empty strings with (default: nil)
---@return table filtered Same table with trimmed/filtered values
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

---Remove all keys from table except those specified
---@param tbl table
---@param ... string Keys to keep
---@return table filtered Same table with only specified keys
-- remove all keys except those passed in
key_filter = (tbl, ...) ->
  set = {val, true for val in *{...}}
  for k,v in pairs tbl
    tbl[k] = nil unless set[k]
  tbl

encodable_userdata = {
  [json.null]: true
}

if json.empty_array
  encodable_userdata[json.empty_array] = true

---Convert an object to a JSON-encodable format
---@param obj any
---@param seen? table Internal table to track circular references
---@return any
json_encodable = (obj, seen={}) ->
  switch type obj
    when "table"
      unless seen[obj]
        seen[obj] = true
        { k, json_encodable(v) for k,v in pairs(obj) when type(k) == "string" or type(k) == "number" }
    when "userdata"
      encodable_userdata[obj] and obj
    when "function", "thread"
      nil
    else
      obj

---Convert an object to JSON string
---@param obj any
---@return string
to_json = (obj) -> json.encode json_encodable obj

---Parse a JSON string to Lua object
---@param obj string
---@return any
from_json = (obj) -> json.decode obj

---Build a URL from component parts
---@param parts table URL components table
---@param parts.path? string URL path
---@param parts.query? string Query string
---@param parts.fragment? string URL fragment
---@param parts.host? string Host name
---@param parts.port? string|number Port number
---@param parts.scheme? string URL scheme (http, https, etc.)
---@return string
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
      if parts.scheme != ""
        host = parts.scheme .. ":" .. host

    if parts.path and out\sub(1,1) != "/"
      out = "/" .. out

    out = host .. out

  out

---Calculate the difference between two dates
---@param later userdata|string Later date object or string
---@param sooner userdata|string Earlier date object or string
---@return table time_diff Time units (years, days, hours, minutes, seconds)
---@return boolean success Always true
date_diff = (later, sooner) ->
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

---Calculate time elapsed since a given time
---@param time userdata|string|number Date object, string, or timestamp
---@return table time_diff Time units elapsed since the given time
---@return boolean success Always true
time_ago = (time) ->
  date_diff date(true), date(time)

---Convert time difference to human-readable words
---@param time table|userdata|string|number Time difference table or time to compare
---@param parts? number Time units to include (default: 1)
---@param suffix? string Suffix to append (default: "ago")
---@return string
time_ago_in_words = do
  singular = {
    years: "year"
    days: "day"
    hours: "hour"
    minutes: "minute"
    seconds: "second"
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

    if suffix and suffix != ""
      out .. " " .. suffix
    else
      out

---Convert a string to Title Case
---@param str string
---@return string
title_case = (str) ->
  (str\gsub "%S+", (chunk) ->
    chunk\gsub "^.", string.upper)

---Create an autoloading table that requires modules on demand
---@param ... string|table Module prefixes to search, optionally ending with existing table
---@return table autoloader Loads modules on first access
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

---Create a table that auto-generates its content using a function
---@param fn function
---@return table auto_table Generates content on first access
auto_table = (fn) ->
  setmetatable {}, __index: (name) =>
    result = fn!
    getmetatable(@).__index = result
    result[name]

---Get multiple fields from an object
---@param obj table|nil
---@param key string|nil
---@param ... string Additional keys to get
---@return any ...
get_fields = (obj, key, ...) ->
  return unless obj
  return unless key
  obj[key], get_fields obj, ...

-- NOTE: this is not designed to be comprehensive, but a quick helper for cases
-- for names of this are not explicitly specified
---Convert plural word to singular form (basic implementation)
---@param name string
---@return string
-- NOTE: this is not designed to be comprehensive, but a quick helper for cases
-- for names of this are not explicitly specified
singularize = do
  irregulars = {
    children: "child"
    vertices: "vertex"
    matrices: "matrix"
    indices: "index"
    statuses: "status"
    people: "person"
    leaves: "leaf"
    lives: "life"
  }

  -- NOTE: this does not support mixed case
  for k in *[k for k in pairs irregulars]
    irregulars[k\upper!] = irregulars[k]\upper!

  (name) ->
    out = name\gsub "(%w+)$", irregulars
    if out != name
      return out

    out = name\gsub("[iI][eE]([sS])$", {s: "y", S: "Y"})\gsub("([oO])[eE][sS]$", "%1")

    out = if out\sub(-4, -1) == "sses"
      out\gsub("([sS][sS])[eE][sS]$", "%1")
    else
      out\gsub("[sS]$", "")

    out


{ :unescape, :escape, :escape_pattern, :parse_query_string,
  :parse_content_disposition, :parse_cookie_string, :encode_query_string,
  :underscore, :slugify, :uniquify, :trim, :trim_all, :trim_filter,
  :key_filter, :to_json, :from_json, :json_encodable, :build_url, :time_ago,
  :time_ago_in_words, :camelize, :title_case, :autoload, :auto_table,
  :get_fields, :singularize, :date_diff }
