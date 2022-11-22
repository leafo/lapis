
-- signed sessions

json = require "cjson"
import encode_base64, decode_base64, encode_with_secret, decode_with_secret from require "lapis.util.encoding"

config = require"lapis.config".get!

import insert from table
import setmetatable, getmetatable, rawset, rawget from _G

encode_session = (tbl, secret=config.secret) ->
  if secret
    return encode_with_secret tbl, secret, "\n--"

  encode_base64 json.encode tbl

get_session = (req_or_cookie, secret=config.secret) ->
  cookie = switch type req_or_cookie
    when "string", "nil"
      req_or_cookie
    when "table" -- request object
      req_or_cookie.cookies[config.session_name]
    else
      error "Unknown object passed to session.get_session"

  return nil, "no cookie" unless cookie

  if secret
    success, out, err = pcall ->
      decode_with_secret cookie, secret, "\n%-%-"

    if out
      return out

    unless success
      return nil, "invalid session serialization"

    return nil, "session: #{err}"

  success, session = pcall ->
    json.decode (decode_base64 cookie)

  unless success
    return nil, "invalid session serialization"

  session

-- convert a lazy session into a plain table
flatten_session = (sess) ->
  mt = getmetatable sess
  s = {} -- the flattened session object

  -- triggers auto_table to load the current session if it hasn't yet
  sess[s]

  -- copy old session
  if index = mt.__index
    for k,v in pairs index
      s[k] = v

  -- copy new values
  for k,v in pairs sess
    s[k] = v

  -- copy an deleted values
  for name in *mt
    s[name] = nil if rawget(sess, name) == nil

  s

-- r.session should be a `lazy_session`
write_session = (r) ->
  current = r.session
  return nil, "missing session object" unless current

  mt = getmetatable current
  return nil, "session object not lazy session" unless mt

  -- abort unless session has been changed
  return nil, "session unchanged" unless next(current) != nil or mt[1]

  s = flatten_session current
  r.cookies[config.session_name] = mt.encode_session s
  true

lazy_session = do
  __newindex = (key, val) =>
    -- we mark what new fields have been written by adding them to the array
    -- slots of the metatable in order to detect and write removed fields
    insert getmetatable(@), key
    rawset @, key, val

  __index = (key) =>
    mt = getmetatable @
    s = mt.get_session(mt.req) or {}
    mt.__index = s
    s[key]

  (req, opts) ->
    setmetatable {}, {
      :__index, :__newindex, :req

      get_session: opts and opts.get_session or get_session
      encode_session: opts and opts.encode_session or encode_session
    }

{ :get_session, :write_session, :encode_session, :lazy_session, :flatten_session }
