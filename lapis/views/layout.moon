html = require "lapis.html"
class Default extends html.Widget
  content: =>
    html_5 ->
      head -> title @title or "Lapis Page"
      body -> @content_for "inner"

