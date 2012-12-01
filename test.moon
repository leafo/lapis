
require "moon"
lapis = require "lapis"

class View extends lapis.html.Widget
  msg: => "hello from a widget"
  content: =>
    html_5 ->
      pre @msg!

class Cool extends lapis.Application
  [home: "/"]: =>
    @title = "Welcome to the test page!"
    View!

  "/cool/:name/:id": =>
    @html -> pre "hello world! ", @params.name, " - ", @params.id

  "/hello/world/*": lapis.server.make_static_handler "static"

lapis.serve Cool, 6789

