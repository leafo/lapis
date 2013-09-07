
-- signed sessions

json = require "cjson"
import encode_base64, decode_base64, hmac_sha1 from require "lapis.util.encoding"

config = require"lapis.config".get!

hmac = (str) ->
  encode_base64 hmac_sha1 config.secret, str

get_session = (r) ->
  cookie = r.cookies[config.session_name]
  return {} unless cookie

  if config.secret
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

    -- triggers auto_table to load the current session if it hasn't yet
    r.session.hello

    if index = getmetatable(r.session).__index
      for k,v in pairs index
        s[k] = v

    for k,v in pairs r.session
      s[k] = v

    s = encode_base64 json.encode s
    if config.secret
      s ..= "\n--#{hmac s}"

    r.cookies[config.session_name] = s

{ :get_session, :write_session }
