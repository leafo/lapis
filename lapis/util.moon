
url = require "socket.url"

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

if ... == "test"
  require "moon"
  moon.p parse_query_string "hello=wo%22rld"


{ :unescape, :escape_pattern, :parse_query_string, :parse_content_disposition,
  :parse_cookie_string }
