
application = require "lapis.application"

import Application from application
leda =  require "lapis.leda"
nginx =  require "lapis.nginx"
app_cache = {}
setmetatable app_cache, __mode: "k"

serve = (app_cls) ->
  app = app_cache[app_cls]

  unless app
    name = app_cls
    if type(name) == "string"
      app_cls = require(name)

    app = if app_cls.__base -- is a class
      app_cls!
    else
      app_cls\build_router!
      app_cls

    app_cache[name] = app
    
    
  if __leda 
      -- dispatch in leda environment
      leda.dispatch app
  else
      -- dispatch in nginx environment
      nginx.dispatch app

{
  :serve, :application, :Application, :app_cache
}
