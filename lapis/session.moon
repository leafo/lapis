
-- signed sessions

json = require "cjson"
crypto = require "crypto"
mime = require "mime"

secret = "please-change-me"
session_name = "lapis_session"

set_secret = (s) -> secret = s
set_session_name = (s) -> session_name = s

get_secret = -> secret

hmac = (str) ->
  crypto.hmac.digest "sha1", str, secret

get_session = (r) ->
  cookie = r.cookies[session_name]
  return {} unless cookie

  if secret
    real_cookie, sig = cookie\match "^(.*)\n%-%-(.*)$"
    unless real_cookie and sig == hmac real_cookie
      return {}
    cookie = real_cookie

  _, session = pcall ->
    json.decode (mime.unb64 cookie)

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

    s = mime.b64 json.encode s
    if secret
      s ..= "\n--#{hmac s}"

    r.cookies[session_name] = s

if ... == "test"
  require "moon"

  s = setmetatable { hello: "world" }, {
    __index: { car: "engine" }
  }

  r = { cookies: {}, session: s }

  -- missing key
  set_secret nil
  write_session(r)
  print "The session"
  moon.p r
  set_secret "secret"

  print "Should be empty"
  moon.p get_session r

  -- matched key
  set_secret "secret"
  write_session(r)
  print "Should be full"
  moon.p get_session r

  -- malformed
  r.cookies.lapis_session = "uhhhh"
  print "Should be empty"
  moon.p get_session r


{ :get_session, :write_session, :set_secret, :set_session_name, :get_secret }
