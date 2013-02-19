
local encode_base64, decode_base64, hmac_sha1

if ngx
  {:encode_base64, :decode_base64, :hmac_sha1} = ngx
else
  mime = require "mime"
  { :b64, :unb64 } = mime
  encode_base64 = (...) -> (b64 ...)
  decode_base64 = (...) -> (unb64 ...)

  crypto = require "crypto"
  hmac_sha1 = (secret, str) ->
    crypto.hmac.digest "sha1", str, secret, true

encode_with_secret = (object, secret, sep=".") ->
  json = require "cjson"
  secret = secret or require"lapis.session".get_secret!

  msg = encode_base64 json.encode object
  signature = encode_base64 hmac_sha1 secret, msg
  msg .. sep .. signature


decode_with_secret = (msg_and_sig, secret) ->
  json = require "cjson"
  secret = secret or require"lapis.session".get_secret!

  msg, sig = msg_and_sig\match "^(.*)%.(.*)$"
  return nil, "invalid message" unless msg

  sig = decode_base64 sig

  unless sig == hmac_sha1(secret, msg)
    return nil, "invalid message secret"

  json.decode decode_base64 msg

if ... == "test"
  require "moon"
  msg = encode_with_secret { color: "red" }
  print msg

  moon.p decode_with_secret msg
  print decode_with_secret "hello"
  print decode_with_secret "hello.world"

{ :encode_base64, :decode_base64, :hmac_sha1 }
