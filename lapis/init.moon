
application = require "lapis.application"
html = require "lapis.html"
server = require "lapis.server"

import Application from application

serve = (app_cls, port = 80) ->
  app = app_cls!

  switch server.current!
    when "xavante"
      x = require "lapis.xavante"
      s = x.make_server port, x.wrap_dispatch app\dispatch
      s.start!
    when "nginx"
      n = require "lapis.nginx"
      n.dispatch app
    else
      error "Don't know how to serve: #{server.current!}"

{
  :server, :serve, :html, :application
  :Application
}
