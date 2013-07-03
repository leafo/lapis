local json = require("cjson")
local encode_base64, decode_base64, hmac_sha1
do
  local _obj_0 = require("lapis.util.encoding")
  encode_base64, decode_base64, hmac_sha1 = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.hmac_sha1
end
local config = require("lapis.config").get()
local hmac
hmac = function(str)
  return encode_base64(hmac_sha1(config.secret, str))
end
local get_session
get_session = function(r)
  local cookie = r.cookies[config.session_name]
  if not (cookie) then
    return { }
  end
  if config.secret then
    local real_cookie, sig = cookie:match("^(.*)\n%-%-(.*)$")
    if not (real_cookie and sig == hmac(real_cookie)) then
      return { }
    end
    cookie = real_cookie
  end
  local _, session = pcall(function()
    return json.decode((decode_base64(cookie)))
  end)
  return session or { }
end
local write_session
write_session = function(r)
  if nil ~= next(r.session) then
    local s = { }
    do
      local index = getmetatable(r.session).__index
      if index then
        for k, v in pairs(index) do
          s[k] = v
        end
      end
    end
    for k, v in pairs(r.session) do
      s[k] = v
    end
    s = encode_base64(json.encode(s))
    if config.secret then
      s = s .. "\n--" .. tostring(hmac(s))
    end
    r.cookies[config.session_name] = s
  end
end
return {
  get_session = get_session,
  write_session = write_session
}
