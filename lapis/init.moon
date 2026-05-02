
application = require "lapis.application"

import Application from application

app_cache = {}
setmetatable app_cache, __mode: "k"

local dispatcher

---Resolve an app reference into a ready-to-serve app instance.
---When `app_module` is nil, the module name is read from config via `get_app_module`.
---@param app_module? string|table Module name to require, an Application class, or an instance
---@return table app A built app instance ready to dispatch
load_app = (app_module) ->
  app_module or= require("lapis.config").get_app_module!

  app_cls = if type(app_module) == "string"
    require app_module
  else
    app_module

  if app_cls.__base -- is a class
    app_cls!
  else
    app_cls\build_router!
    app_cls

serve = (app_cls) ->
  app = app_cache[app_cls]

  unless app
    app = load_app app_cls
    app_cache[app_cls] = app

  unless dispatcher
    dispatcher = require "lapis.nginx"

  dispatcher.dispatch app

{
  :serve, :load_app, :Application, :app_cache
}
