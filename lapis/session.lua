local json = require("cjson")
local encode_base64, decode_base64, hmac_sha1
do
  local _obj_0 = require("lapis.util.encoding")
  encode_base64, decode_base64, hmac_sha1 = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.hmac_sha1
end
local config = require("lapis.config").get()
local insert
insert = table.insert
local setmetatable, getmetatable, rawset, rawget
do
  local _obj_0 = _G
  setmetatable, getmetatable, rawset, rawget = _obj_0.setmetatable, _obj_0.getmetatable, _obj_0.rawset, _obj_0.rawget
end
local hmac
hmac = function(str)
  return encode_base64(hmac_sha1(config.secret, str))
end
local encode_session
encode_session = function(tbl)
  local s = encode_base64(json.encode(tbl))
  if config.secret then
    s = s .. "\n--" .. tostring(hmac(s))
  end
  return s
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
  local current = r.session
  local current_mt = getmetatable(current)
  if next(current) ~= nil or current_mt[1] then
    local s = { }
    local _ = current[s]
    do
      local index = current_mt.__index
      if index then
        for k, v in pairs(index) do
          s[k] = v
        end
      end
    end
    for k, v in pairs(current) do
      s[k] = v
    end
    for _index_0 = 1, #current_mt do
      local name = current_mt[_index_0]
      if rawget(current, name) == nil then
        s[name] = nil
      end
    end
    r.cookies[config.session_name] = encode_session(s)
  end
end
local lazy_session
do
  local __newindex
  __newindex = function(self, key, val)
    insert(getmetatable(self), key)
    return rawset(self, key, val)
  end
  local __index
  __index = function(self, key)
    local mt = getmetatable(self)
    local s = get_session(mt.req)
    mt.__index = s
    return s[key]
  end
  lazy_session = function(req)
    return setmetatable({ }, {
      __index = __index,
      __newindex = __newindex,
      req = req
    })
  end
end
return {
  get_session = get_session,
  write_session = write_session,
  encode_session = encode_session,
  lazy_session = lazy_session
}
