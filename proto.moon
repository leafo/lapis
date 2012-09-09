
require "lapis"

self = lapis.new!

@dispatch "/base",


class App extends @dispatcher"/base"
  ":id": (id) -> -- matches /base/someid343
    "what is going on"

  show: @route":id"


get "/", json_api (req) ->
  hello: "world"



div "hello world"

div ->
  if something
    text "yeah"
  text "what is going on"

div class: "blue", ->
  print "what"
