
local encode_base64, decode_base64, hmac_sha1

config = require"lapis.config".get!

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

encode_with_secret = (object, secret=config.secret, sep=".") ->
  json = require "cjson"

  msg = encode_base64 json.encode object
  signature = encode_base64 hmac_sha1 secret, msg
  msg .. sep .. signature


decode_with_secret = (msg_and_sig, secret=config.secret) ->
  json = require "cjson"

  msg, sig = msg_and_sig\match "^(.*)%.(.*)$"
  return nil, "invalid message" unless msg

  sig = decode_base64 sig

  unless sig == hmac_sha1(secret, msg)
    return nil, "invalid message secret"

  json.decode decode_base64 msg

{ :encode_base64, :decode_base64, :hmac_sha1, :encode_with_secret, :decode_with_secret }
