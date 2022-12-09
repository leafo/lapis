local application = require("lapis.application")
local Application
Application = application.Application
local app_cache = { }
setmetatable(app_cache, {
  __mode = "k"
})
local dispatcher
local serve
serve = function(app_cls)
  local app = app_cache[app_cls]
  if not (app) then
    local name = app_cls
    if type(name) == "string" then
      app_cls = require(name)
    end
    if app_cls.__base then
      app = app_cls()
    else
      app_cls:build_router()
      app = app_cls
    end
    app_cache[name] = app
  end
  if not (dispatcher) then
    dispatcher = require("lapis.nginx")
  end
  return dispatcher.dispatch(app)
end
return {
  serve = serve,
  Application = Application,
  app_cache = app_cache
}
