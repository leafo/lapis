local json = require("cjson")
local encode_base64, decode_base64, hmac_sha1
do
  local _obj_0 = require("lapis.util.encoding")
  encode_base64, decode_base64, hmac_sha1 = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.hmac_sha1
end
local config = require("lapis.config").get()
local generate_token
generate_token = function(req, key, expires)
  if expires == nil then
    expires = os.time() + 60 * 60 * 8
  end
  local msg = encode_base64(json.encode({
    key = key,
    expires = expires
  }))
  local signature = encode_base64(hmac_sha1(config.secret, msg))
  return msg .. "." .. signature
end
local validate_token
validate_token = function(req, key)
  local token = req.params.csrf_token
  if not (token) then
    return nil, "missing csrf token"
  end
  local msg, sig = token:match("^(.*)%.(.*)$")
  if not (msg) then
    return nil, "malformed csrf token"
  end
  sig = ngx.decode_base64(sig)
  if not (sig == ngx.hmac_sha1(config.secret, msg)) then
    return nil, "invalid csrf token (bad sig)"
  end
  msg = json.decode(ngx.decode_base64(msg))
  if not (msg.key == key) then
    return nil, "invalid csrf token (bad key)"
  end
  if not (not msg.expires or msg.expires > os.time()) then
    return nil, "csrf token expired"
  end
  return true
end
local assert_token
assert_token = function(...)
  local assert_error
  assert_error = require("lapis.application").assert_error
  return assert_error(validate_token(...))
end
return {
  generate_token = generate_token,
  validate_token = validate_token,
  assert_token = assert_token
}
