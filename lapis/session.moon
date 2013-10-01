
-- signed sessions

json = require "cjson"
import encode_base64, decode_base64, hmac_sha1 from require "lapis.util.encoding"

config = require"lapis.config".get!

import insert from table
import setmetatable, getmetatable, rawset, rawget from _G

hmac = (str) ->
  encode_base64 hmac_sha1 config.secret, str

encode_session = (tbl) ->
  s = encode_base64 json.encode tbl
  if config.secret
    s ..= "\n--#{hmac s}"
  s

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

-- r.session should be a `lazy_session`
write_session = (r) ->
  current = r.session
  current_mt = getmetatable current

  -- see if the session has changed
  if next(current) != nil or current_mt[1]
    s = {}

    -- triggers auto_table to load the current session if it hasn't yet
    current[s]

    -- copy old session
    if index = current_mt.__index
      for k,v in pairs index
        s[k] = v

    -- copy new values
    for k,v in pairs current
      s[k] = v

    -- copy an deleted values
    for name in *current_mt
      s[name] = nil if rawget(current, name) == nil

    r.cookies[config.session_name] = encode_session(s)

lazy_session = do

  __newindex = (key, val) =>
    insert getmetatable(@), key
    rawset @, key, val

  __index = (key) =>
    mt = getmetatable @
    s = get_session mt.req
    mt.__index = s
    s[key]

  (req) ->
    setmetatable {}, {
      :__index, :__newindex, :req
    }

{ :get_session, :write_session, :encode_session, :lazy_session }
