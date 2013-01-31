local encode_base64, decode_base64, hmac_sha1
if ngx then
  do
    local _obj_0 = ngx
    encode_base64, decode_base64, hmac_sha1 = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.hmac_sha1
  end
else
  local mime = require("mime")
  local b64, unb64
  do
    local _obj_0 = mime
    b64, unb64 = _obj_0.encode_base64, _obj_0.decode_base64
  end
  local crypto = require("crypto")
  hmac_sha1 = function(secret, str)
    return crypto.hmac.digest("sha1", str, secret, true)
  end
end
return {
  encode_base64 = encode_base64,
  decode_base64 = decode_base64,
  hmac_sha1 = hmac_sha1
}
