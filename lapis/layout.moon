
module "lapis.layout", package.seeall
require "lapis.html"

export Default

class Default extends lapis.html.Widget
  content: =>
