local application = require("lapis.application")
local html = require("lapis.html")
local server = require("lapis.server")
local Application
Application = application.Application
local serve
serve = function(app_cls, port)
  if port == nil then
    port = 80
  end
  local app = app_cls()
  local _exp_0 = server.current()
  if "xavante" == _exp_0 then
    local x = require("lapis.xavante")
    local s = x.make_server(port, x.wrap_dispatch((function()
      local _base_0 = app
      local _fn_0 = _base_0.dispatch
      return function(...)
        return _fn_0(_base_0, ...)
      end
    end)()))
    return s.start()
  elseif "nginx" == _exp_0 then
    local n = require("lapis.nginx")
    return n.dispatch(app)
  else
    return error("Don't know how to serve: " .. tostring(server.current()))
  end
end
return {
  server = server,
  serve = serve,
  html = html,
  application = application,
  Application = Application
}
