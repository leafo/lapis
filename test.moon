
require "moon"
require "lapis"

class View extends lapis.html.Widget
  msg: => "hello from a widget"
  content: =>
    html_5 ->
      pre @msg!


class Cool extends lapis.Application
  [home: "/"]: =>
    View!

  "/cool": =>
    @html -> pre "hello world!"

  "/hello/world/*": lapis.server.make_static_handler "static"

lapis.serve Cool, 6789

