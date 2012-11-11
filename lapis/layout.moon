
html = require "lapis.html"

class Default extends html.Widget
  content: =>
    html_5 ->
      head -> title "The Test Page"

      body ->
        @content_for "inner"

{ :Default }
