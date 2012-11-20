local json = require("cjson")
local crypto = require("crypto")
local mime = require("mime")
local secret = "please-change-me"
local session_name = "lapis_session"
local set_secret
set_secret = function(s)
  secret = s
end
local set_session_name
set_session_name = function(s)
  session_name = s
end
local hmac
hmac = function(str)
  return crypto.hmac.digest("sha1", str, secret)
end
local get_session
get_session = function(r)
  local cookie = r.cookies[session_name]
  if not (cookie) then
    return { }
  end
  if secret then
    local real_cookie, sig = cookie:match("^(.*)\n%-%-(.*)$")
    if not (real_cookie and sig == hmac(real_cookie)) then
      return { }
    end
    cookie = real_cookie
  end
  local _, session = pcall(function()
    return json.decode((mime.unb64(cookie)))
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
    s = mime.b64(json.encode(s))
    if secret then
      s = s .. "\n--" .. tostring(hmac(s))
    end
    r.cookies[session_name] = s
  end
end
if ... == "test" then
  require("moon")
  local s = setmetatable({
    hello = "world"
  }, {
    __index = {
      car = "engine"
    }
  })
  local r = {
    cookies = { },
    session = s
  }
  set_secret(nil)
  write_session(r)
  print("The session")
  moon.p(r)
  set_secret("secret")
  print("Should be empty")
  moon.p(get_session(r))
  set_secret("secret")
  write_session(r)
  print("Should be full")
  moon.p(get_session(r))
  r.cookies.lapis_session = "uhhhh"
  print("Should be empty")
  moon.p(get_session(r))
end
return {
  get_session = get_session,
  write_session = write_session,
  set_secret = set_secret,
  set_session_name = set_session_name
}
