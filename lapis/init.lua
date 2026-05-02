local application = require("lapis.application")
local Application
Application = application.Application
local app_cache = { }
setmetatable(app_cache, {
  __mode = "k"
})
local dispatcher
local load_app
load_app = function(app_module)
  app_module = app_module or require("lapis.config").get_app_module()
  local app_cls
  if type(app_module) == "string" then
    app_cls = require(app_module)
  else
    app_cls = app_module
  end
  if app_cls.__base then
    return app_cls()
  else
    app_cls:build_router()
    return app_cls
  end
end
local serve
serve = function(app_cls)
  local app = app_cache[app_cls]
  if not (app) then
    app = load_app(app_cls)
    app_cache[app_cls] = app
  end
  if not (dispatcher) then
    dispatcher = require("lapis.nginx")
  end
  return dispatcher.dispatch(app)
end
return {
  serve = serve,
  load_app = load_app,
  Application = Application,
  app_cache = app_cache
}
