local json = require("cjson")
local encode_base64, decode_base64, encode_with_secret, decode_with_secret
do
  local _obj_0 = require("lapis.util.encoding")
  encode_base64, decode_base64, encode_with_secret, decode_with_secret = _obj_0.encode_base64, _obj_0.decode_base64, _obj_0.encode_with_secret, _obj_0.decode_with_secret
end
local config = require("lapis.config").get()
local insert
insert = table.insert
local setmetatable, getmetatable, rawset, rawget
do
  local _obj_0 = _G
  setmetatable, getmetatable, rawset, rawget = _obj_0.setmetatable, _obj_0.getmetatable, _obj_0.rawset, _obj_0.rawget
end
local encode_session
encode_session = function(tbl, secret)
  if secret == nil then
    secret = config.secret
  end
  if secret then
    return encode_with_secret(tbl, secret, "\n--")
  end
  return encode_base64(json.encode(tbl))
end
local get_session
get_session = function(req_or_cookie, secret)
  if secret == nil then
    secret = config.secret
  end
  local cookie
  local _exp_0 = type(req_or_cookie)
  if "string" == _exp_0 or "nil" == _exp_0 then
    cookie = req_or_cookie
  elseif "table" == _exp_0 then
    cookie = req_or_cookie.cookies[config.session_name]
  else
    cookie = error("Unknown object passed to session.get_session")
  end
  if not (cookie) then
    return nil, "no cookie"
  end
  if secret then
    local success, out, err = pcall(function()
      return decode_with_secret(cookie, secret, "\n%-%-")
    end)
    if out then
      return out
    end
    if not (success) then
      return nil, "invalid session serialization"
    end
    return nil, "session: " .. tostring(err)
  end
  local success, session = pcall(function()
    return json.decode((decode_base64(cookie)))
  end)
  if not (success) then
    return nil, "invalid session serialization"
  end
  return session
end
local flatten_session
flatten_session = function(sess)
  local mt = getmetatable(sess)
  local s = { }
  local _ = sess[s]
  do
    local index = mt.__index
    if index then
      for k, v in pairs(index) do
        s[k] = v
      end
    end
  end
  for k, v in pairs(sess) do
    s[k] = v
  end
  for _index_0 = 1, #mt do
    local name = mt[_index_0]
    if rawget(sess, name) == nil then
      s[name] = nil
    end
  end
  return s
end
local write_session
write_session = function(r)
  local current = r.session
  if not (current) then
    return nil, "missing session object"
  end
  local mt = getmetatable(current)
  if not (mt) then
    return nil, "session object not lazy session"
  end
  if not (next(current) ~= nil or mt[1]) then
    return nil, "session unchanged"
  end
  local s = flatten_session(current)
  r.cookies[config.session_name] = mt.encode_session(s)
  return true
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
    local s = mt.get_session(mt.req) or { }
    mt.__index = s
    return s[key]
  end
  lazy_session = function(req, opts)
    return setmetatable({ }, {
      __index = __index,
      __newindex = __newindex,
      req = req,
      get_session = opts and opts.get_session or get_session,
      encode_session = opts and opts.encode_session or encode_session
    })
  end
end
return {
  get_session = get_session,
  write_session = write_session,
  encode_session = encode_session,
  lazy_session = lazy_session,
  flatten_session = flatten_session
}
