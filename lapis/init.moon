
router = require "lapis.router"
application = require "lapis.application"
html = require "lapis.html"
server = require "lapis.server"

import Application from application

serve = (app_cls, port = 80) ->
  app = app_cls!

  if server.current! == "xavante"
    x = require "lapis.xavante"
    s = x.make_server port, app\dispatch
    s.start!
  else
    error "Don't know how to serve: #{server.current!}"

{
  :server, :serve, :html, :application
  :Application
}
