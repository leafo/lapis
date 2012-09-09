
require "lapis.router"
require "lapis.application"
require "lapis.server"

module "lapis", package.seeall

import make_server from lapis.server

export Application = lapis.application.Application

export serve = (app_cls, port = 80) ->
  app = app_cls!
  -- return if true

  server = make_server port, app\dispatch

  -- res.headers["Content-type"] = "text/html"
  -- res.content = table.concat {
  --   "<html>"
  --   "req:"
  --   "<pre>"
  --   moon.dump req
  --   "</pre>"
  --   "res:"
  --   "<pre>"
  --   moon.dump res
  --   "</pre>"
  --   "hello world, the time is: ", os.date()
  --   "</html>"
  -- }

  -- res
  
  server.start!

