
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

---Generate HMAC-SHA256 hash
---@param secret string Secret key for HMAC
---@param str string String to hash
---@return string hash Base64 encoded HMAC-SHA256 hash
hmac_sha256 = (secret, str) ->
  hmac = openssl_hmac.new secret, "sha256"
  hmac\final str

default_hmac = switch config.hmac_digest
  when "sha256"
    hmac_sha256
  else
    hmac_sha1

---@package
---Set the default HMAC function
set_hmac = (fn) -> default_hmac = fn

---Encode object with secret signature
---@param object any Object to encode as JSON
---@param secret? string Secret key for signature (default: config.secret)
---@param sep? string Separator between message and signature (default: ".")
---@return string encoded Base64 encoded JSON with HMAC signature
encode_with_secret = (object, secret=config.secret, sep=".") ->
  json = require "cjson"

  msg = encode_base64 json.encode object
  signature = encode_base64 default_hmac secret, msg
  msg .. sep .. signature

---Decode object with secret signature verification
---@param msg_and_sig string Base64 encoded message with signature
---@param secret? string Secret key for verification (default: config.secret)
---@param sep? string Separator pattern between message and signature (default: "%.")
---@return any|nil object Decoded object on success, nil on failure
---@return string|nil error Error message if decoding fails
decode_with_secret = (msg_and_sig, secret=config.secret, sep="%.") ->
  json = require "cjson"

  msg, sig = msg_and_sig\match "^(.*)#{sep}(.*)$"
  return nil, "invalid format" unless msg

  sig = decode_base64 sig

  unless sig == default_hmac(secret, msg)
    return nil, "invalid signature"

  json.decode decode_base64 msg

{ :encode_base64, :decode_base64, :hmac_sha1, :hmac_sha256, :encode_with_secret, :decode_with_secret, :set_hmac }
