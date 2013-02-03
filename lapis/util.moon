
url = require "socket.url"

import concat from table
import Path from require "lapis.util.path"

unescape = do
  u = require"socket.url".unescape
  (str) -> (u str)

escape_pattern = do
  punct = "[%^$()%.%[%]*+%-?]"
  (str) -> (str\gsub punct, (p) -> "%"..p)

inject_tuples = (tbl) ->
  for tuple in *tbl
    tbl[tuple[1]] = tuple[2] or true

parse_query_string = do
  import C, P, S, Ct from require "lpeg"

  chunk = C (P(1) - S("=&"))^1
  tuple = Ct(chunk * "=" * (chunk / unescape) + chunk)
  query = S"?#"^-1 * Ct tuple * (P"&" * tuple)^0

  (str) ->
    with out = query\match str
      inject_tuples out if out

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

if ... == "test"
  require "moon"
  moon.p parse_query_string "hello=wo%22rld"

  print underscore "ManifestRocks"
  print camelize underscore "ManifestRocks"
  print camelize "hello"
  print camelize "world_wide_i_web"

{ :unescape, :escape_pattern, :parse_query_string, :parse_content_disposition,
  :parse_cookie_string, :underscore, :slugify, :Path, :uniquify, :trim,
  :trim_all, :trim_filter, :key_filter }
