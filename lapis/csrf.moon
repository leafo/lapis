
-- csrf protection

json = require "cjson"
import encode_base64, decode_base64, hmac_sha1 from require "lapis.util.encoding"

config = require"lapis.config".get!

generate_token = (req, key, expires=os.time! + 60*60*8) ->
  msg = encode_base64 json.encode { :key, :expires }
  signature = encode_base64 hmac_sha1 config.secret, msg
  msg .. "." .. signature

validate_token = (req, key) ->
  token = req.params.csrf_token
  return nil, "missing csrf token" unless token

  msg, sig = token\match "^(.*)%.(.*)$"
  return nil, "malformed csrf token" unless msg

  sig = decode_base64 sig

  unless sig == hmac_sha1(config.secret, msg)
    return nil, "invalid csrf token (bad sig)"

  msg = json.decode decode_base64 msg

  return nil, "invalid csrf token (bad key)" unless msg.key == key
  return nil, "csrf token expired" unless not msg.expires or msg.expires > os.time!
  true

assert_token = (...) ->
  import assert_error from require "lapis.application"
  assert_error validate_token ...

{ :generate_token, :validate_token, :assert_token }

