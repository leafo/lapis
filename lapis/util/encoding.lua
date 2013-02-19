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
    b64, unb64 = _obj_0.b64, _obj_0.unb64
  end
  encode_base64 = function(...)
    return (b64(...))
  end
  decode_base64 = function(...)
    return (unb64(...))
  end
  local crypto = require("crypto")
  hmac_sha1 = function(secret, str)
    return crypto.hmac.digest("sha1", str, secret, true)
  end
end
local encode_with_secret
encode_with_secret = function(object, secret, sep)
  if sep == nil then
    sep = "."
  end
  local json = require("cjson")
  secret = secret or require("lapis.session").get_secret()
  local msg = encode_base64(json.encode(object))
  local signature = encode_base64(hmac_sha1(secret, msg))
  return msg .. sep .. signature
end
local decode_with_secret
decode_with_secret = function(msg_and_sig, secret)
  local json = require("cjson")
  secret = secret or require("lapis.session").get_secret()
  local msg, sig = msg_and_sig:match("^(.*)%.(.*)$")
  if not (msg) then
    return nil, "invalid message"
  end
  sig = decode_base64(sig)
  if not (sig == hmac_sha1(secret, msg)) then
    return nil, "invalid message secret"
  end
  return json.decode(decode_base64(msg))
end
if ... == "test" then
  require("moon")
  local msg = encode_with_secret({
    color = "red"
  })
  print(msg)
  moon.p(decode_with_secret(msg))
  print(decode_with_secret("hello"))
  print(decode_with_secret("hello.world"))
end
return {
  encode_base64 = encode_base64,
  decode_base64 = decode_base64,
  hmac_sha1 = hmac_sha1,
  encode_with_secret = encode_with_secret,
  decode_with_secret = decode_with_secret
}
