
require "moon"

import html_writer, Widget from require "lapis.html"

buffer = {}
w = html_writer ->
  b "what is going on?"

  div ->
    pre class: "cool", -> span "hello world"

  text capture -> div "this is captured"

  raw "<div>raw test</div>"
  text "<div>raw test</div>"

  html_5 ->
    div "what is going on there?"


-- w buffer

class TestWidget extends Widget
  content: =>
    div class: "hello", -> @hi!
    div id: "from_content_for", ->
      @content_for "layout"

  hi: => text "Hello!", @msg!

  msg: => 123

class WidgetInherit extends TestWidget
  hi: =>
    text "Here is your stupid message:", @msg!

WidgetInherit(layout: -> text "what is going on?") buffer

print "result:"
print table.concat buffer

