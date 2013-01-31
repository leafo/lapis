
local encode_base64, decode_base64, hmac_sha1

if ngx
  {:encode_base64, :decode_base64, :hmac_sha1} = ngx
else
  mime = require "mime"
  {encode_base64: b64, decode_base64: unb64} = mime

  crypto = require "crypto"
  hmac_sha1 = (secret, str) ->
    crypto.hmac.digest "sha1", str, secret, true

{ :encode_base64, :decode_base64, :hmac_sha1 }
