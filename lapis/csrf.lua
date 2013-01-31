local json = require("cjson")
local encode_base64, decode_base64, hmac_sha1
do
  local _table_0 = require("lapis.util.encoding")
  encode_base64, decode_base64, hmac_sha1 = _table_0.encode_base64, _table_0.decode_base64, _table_0.hmac_sha1
end
local generate_token
generate_token = function(req, key, expires)
  if expires == nil then
    expires = os.time() + 60 * 60
  end
  local secret = require("lapis.session").get_secret()
  local msg = encode_base64(json.encode({
    key = key,
    expires = expires
  }))
  local signature = encode_base64(hmac_sha1(secret, msg))
  return msg .. "." .. signature
end
local validate_token
validate_token = function(req, key)
  local secret = require("lapis.session").get_secret()
  local token = req.params.csrf_token
  if not (token) then
    return nil, "missing csrf token"
  end
  local msg, sig = token:match("^(.*)%.(.*)$")
  sig = ngx.decode_base64(sig)
  if not (sig == ngx.hmac_sha1(secret, msg)) then
    return nil, "invalid csrf token"
  end
  msg = json.decode(ngx.decode_base64(msg))
  if not (msg.key == key) then
    return nil, "invalid csrf token"
  end
  if not (not msg.expires or msg.expires > os.time()) then
    return nil, "csrf token expired"
  end
  return true
end
local assert_token
assert_token = function(...)
  local assert_error
  do
    local _table_0 = require("lapis.application")
    assert_error = _table_0.assert_error
  end
  return assert_error(validate_token(...))
end
return {
  generate_token = generate_token,
  validate_token = validate_token,
  assert_token = assert_token
}
