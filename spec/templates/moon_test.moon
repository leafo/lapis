
import Widget from require "lapis.html"

class MoonTest extends Widget
  content: =>
    div class: "greeting", ->
      text "hello world"
