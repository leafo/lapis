-- csrf protection

json = require "cjson"
import encode_base64, encode_with_secret, decode_with_secret from require "lapis.util.encoding"
openssl_rand = require "openssl.rand"

config = require"lapis.config".get!
cookie_name = "#{config.session_name}_token"

generate_token = (req, data) ->
  key = req.cookies[cookie_name]

  unless key
    key = encode_base64 openssl_rand.bytes(32)
    req.cookies[cookie_name] = key

  token = {
    k: key
    d: data
  }

  encode_with_secret token

validate_token = (req, callback) ->
  token = req.params.csrf_token
  return nil, "missing csrf token" unless token

  expected_key = req.cookies[cookie_name]
  return nil, "csrf: missing token cookie" unless expected_key

  obj, err = decode_with_secret token
  unless obj
    return nil, "csrf: #{err}"

  if obj.k != expected_key
    return nil, "csrf: token mismatch"

  if callback
    pass, err = callback obj.d
    unless pass
      return nil, "csrf: #{err or "failed check"}"

  true

assert_token = (...) ->
  import assert_error from require "lapis.application"
  assert_error validate_token ...

{ :generate_token, :validate_token, :assert_token }

