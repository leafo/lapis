
-- csrf protection

json = require "cjson"
import encode_base64, decode_base64, hmac_sha1 from require "lapis.util.encoding"

generate_token = (req, key, expires=os.time! + 60*60*8) ->
  secret = require"lapis.session".get_secret!
  msg = encode_base64 json.encode { :key, :expires }
  signature = encode_base64 hmac_sha1 secret, msg
  msg .. "." .. signature

validate_token = (req, key) ->
  secret = require"lapis.session".get_secret!
  token = req.params.csrf_token
  return nil, "missing csrf token" unless token

  msg, sig = token\match "^(.*)%.(.*)$"
  sig = ngx.decode_base64 sig

  unless sig == ngx.hmac_sha1(secret, msg)
    return nil, "invalid csrf token"

  msg = json.decode ngx.decode_base64 msg

  return nil, "invalid csrf token" unless msg.key == key
  return nil, "csrf token expired" unless not msg.expires or msg.expires > os.time!
  true

assert_token = (...) ->
  import assert_error from require "lapis.application"
  assert_error validate_token ...

{ :generate_token, :validate_token, :assert_token }

