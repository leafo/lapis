
import render_html, Widget from require "lapis.html"

render_widget = (w) ->
  buffer = {}
  w buffer
  table.concat buffer

describe "lapis.html", ->
  it "should render html", ->
    output = render_html ->
      b "what is going on?"

      div ->
        pre class: "cool", -> span "hello world"

      text capture -> div "this is captured"

      link rel: "icon", type: "image/png", href: "dad"

      raw "<div>raw test</div>"
      text "<div>raw test</div>"

      html_5 ->
        div "what is going on there?"

    assert.same [[<b>what is going on?</b><div><pre class="cool"><span>hello world</span></pre></div>&lt;div&gt;this is captured&lt;/div&gt;<link rel="icon"href="dad"type="image/png"/><div>raw test</div>&lt;div&gt;raw test&lt;/div&gt;<!DOCTYPE HTML><html lang="en"><div>what is going on there?</div></html>]], output

  it "should render more html", ->
    output = render_html ->
      element "leaf", {"hello"}, "world"
      element "leaf", "one", "two", "three"
      element "leaf", {hello: "world", "a"}, { no: "show", "b", "c" }

      leaf {"hello"}, "world"
      leaf "one", "two", "three"
      leaf {hello: "world", "a"}, { no: "show", "b", "c" }

    assert.same [[<leaf>helloworld</leaf><leaf>onetwothree</leaf><leaf hello="world">abc</leaf><leaf>helloworld</leaf><leaf>onetwothree</leaf><leaf hello="world">abc</leaf>]], output

  it "should capture", ->
    local capture_out
    output = render_html ->
      text "hello"
      capture_out = capture ->
        div "This is the capture"
      text "world"

    assert.same "helloworld", output
    assert.same "<div>This is the capture</div>", capture_out

  it "should render the widget", ->
    class TestWidget extends Widget
      content: =>
        div class: "hello", @message
        @content_for "inner"

    input = render_widget TestWidget message: "Hello World!", inner: -> b "Stay Safe"
    assert.same input, [[<div class="hello">Hello World!</div><b>Stay Safe</b>]]

  it "should render widget with inheritance", ->
    class BaseWidget extends Widget
      value: 100
      another_value: => 200

      content: =>
        div class: "base_widget", ->
          @inner!

      inner: => error "implement me"

    class TestWidget extends BaseWidget
      inner: =>
        text "Widget speaking, value: #{@value}, another_value: #{@another_value!}"

    input = render_widget TestWidget!
    assert.same input, [[<div class="base_widget">Widget speaking, value: 100, another_value: 200</div>]]


  it "should include widget helper", ->
    class Test extends Widget
      content: =>
        div "What's up! #{@hello!}"

    w = Test!
    w\include_helper {
      id: 10
      hello: => "id: #{@id}"
    }

    input = render_widget w
    assert.same input, [[<div>What&#039;s up! id: 10</div>]]

  it "helper should pass to sub widget", ->
    class Fancy extends Widget
      content: =>
        text @cool_message!
        text @thing

    class Test extends Widget
      content: =>
        first ->
          widget Fancy @

        second ->
          widget Fancy!

    w = Test thing: "THING"
    w\include_helper {
      cool_message: =>
        "so-cool"
    }
    assert.same [[<first>so-coolTHING</first><second>so-cool</second>]],
      render_widget w

  it "helpers should resolve correctly ", ->
    class Base extends Widget
      one: 1
      two: 2
      three: 3

    class Sub extends Base
      two: 20
      three: 30
      four: 40

      content: =>
        text @one
        text @two
        text @three
        text @four
        text @five

    w = Sub!
    w\include_helper {
      one: 100
      two: 200
      four: 400
      five: 500
    }

    buff = {}
    w\render buff

    assert.same {"1", "20", "30", "40", "500"}, buff


  it "should include methods from mixin", ->
    class TestMixin
      thing: ->
        div class: "the_thing", ->
          text "hello world"

    class SomeWidget extends Widget
      @include TestMixin

      content: =>
        div class: "outer", ->
          @thing!

    assert.same [[<div class="outer"><div class="the_thing">hello world</div></div>]],
      render_widget SomeWidget!

