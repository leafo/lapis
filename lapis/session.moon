
-- signed sessions

json = require "cjson"
import encode_base64, decode_base64, hmac_sha1 from require "lapis.util.encoding"

secret = "please-change-me"
session_name = "lapis_session"

set_secret = (s) -> secret = s
set_session_name = (s) -> session_name = s

get_secret = -> secret

hmac = (str) ->
  encode_base64 hmac_sha1 secret, str

get_session = (r) ->
  cookie = r.cookies[session_name]
  return {} unless cookie

  if secret
    real_cookie, sig = cookie\match "^(.*)\n%-%-(.*)$"
    unless real_cookie and sig == hmac real_cookie
      return {}
    cookie = real_cookie

  _, session = pcall ->
    json.decode (decode_base64 cookie)

  session or {}

write_session = (r) ->
  -- see if the session has changed
  if nil != next r.session
    s = {}
    if index = getmetatable(r.session).__index
      for k,v in pairs index
        s[k] = v

    for k,v in pairs r.session
      s[k] = v

    s = encode_base64 json.encode s
    if secret
      s ..= "\n--#{hmac s}"

    r.cookies[session_name] = s


{ :get_session, :write_session, :set_secret, :set_session_name, :get_secret }
