
local encode_base64, decode_base64, hmac_sha1

config = require"lapis.config".get!
openssl_hmac = require "openssl.hmac"

if ngx
  {:encode_base64, :decode_base64, :hmac_sha1} = ngx
else
  mime = require "mime"
  { :b64, :unb64 } = mime
  encode_base64 = (...) -> (b64 ...)
  decode_base64 = (...) -> (unb64 ...)

  hmac_sha1 = (secret, str) ->
    hmac = openssl_hmac.new secret, "sha1"
    hmac\final str

hmac_sha256 = (secret, str) ->
  hmac = openssl_hmac.new secret, "sha256"
  hmac\final str

default_hmac = switch config.hmac_digest
  when "sha256"
    hmac_sha256
  else
    hmac_sha1

set_hmac = (fn) -> default_hmac = fn

encode_with_secret = (object, secret=config.secret, sep=".") ->
  json = require "cjson"

  msg = encode_base64 json.encode object
  signature = encode_base64 default_hmac secret, msg
  msg .. sep .. signature

decode_with_secret = (msg_and_sig, secret=config.secret, sep="%.") ->
  json = require "cjson"

  msg, sig = msg_and_sig\match "^(.*)#{sep}(.*)$"
  return nil, "invalid format" unless msg

  sig = decode_base64 sig

  unless sig == default_hmac(secret, msg)
    return nil, "invalid signature"

  json.decode decode_base64 msg

{ :encode_base64, :decode_base64, :hmac_sha1, :hmac_sha256, :encode_with_secret, :decode_with_secret, :set_hmac }
