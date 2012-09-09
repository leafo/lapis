
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

  hi: => text "Hello!", @msg!

  msg: => 123


TestWidget! buffer

print "result:"
print table.concat buffer

