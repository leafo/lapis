
module "lapis.layout", package.seeall
require "lapis.html"

export Default

class Default extends lapis.html.Widget
  content: =>
    html_5 ->
      head -> title "The Test Page"

      body ->
        @content_for "inner"
