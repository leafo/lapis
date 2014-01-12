
application = require "lapis.application"

import Application from application
import dispatch from require "lapis.nginx"

app_cache = {}

serve = (app_cls) ->
  app = app_cache[app_cls]

  unless app
    app = if type(app_cls) == "string"
      require(app_cls)!
    elseif app_cls.__base -- is a class
      app_cls!
    else
      app_cls\build_router!
      app_cls

    app_cache[app_cls] = app

  dispatch app

{
  :serve, :application, :Application, :app_cache
}
