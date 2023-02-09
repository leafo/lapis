
import render_html, Widget, is_mixins_class from require "lapis.html"

import sorted_pairs from require "spec.helpers"

render_widget = (w) ->
  buffer = {}
  w buffer
  table.concat buffer

describe "lapis.html", ->
  sorted_pairs!

  it "should render html", ->
    output = render_html ->
      b "what is going on?"

      div ->
        pre class: "cool", -> span "hello world"

      text capture -> div "this is captured"

      link rel: "icon" -- , type: "image/png", href: "dad"-- can't have multiple because of hash ordering

      raw "<div>raw test</div>"
      text "<div>raw test</div>"

      html_5 ->
        div "what is going on there?"

    assert.same [[<b>what is going on?</b><div><pre class="cool"><span>hello world</span></pre></div>&lt;div&gt;this is captured&lt;/div&gt;<link rel="icon"/><div>raw test</div>&lt;div&gt;raw test&lt;/div&gt;<!DOCTYPE HTML><html lang="en"><div>what is going on there?</div></html>]], output

  it "should render html class table syntax", ->
    output = render_html ->
      div class: {"hello", "world", cool: true, notcool: false}
      div class: {}
      div class: {ok: "fool"}
      div class: {cool: nil}

    assert.same '<div class="hello world cool"></div><div></div><div class="ok"></div><div></div>', output

  it "should render more html", ->
    output = render_html ->
      element "leaf", {"hello"}, "world"
      element "leaf", "one", "two", "three"
      element "leaf", {hello: "world", "a"}, { no: "show", "b", "c" }

      leaf {"hello"}, "world"
      leaf "one", "two", "three"
      leaf {hello: "world", "a"}, { no: "show", "b", "c" }

    assert.same [[<leaf>helloworld</leaf><leaf>onetwothree</leaf><leaf hello="world">abc</leaf><leaf>helloworld</leaf><leaf>onetwothree</leaf><leaf hello="world">abc</leaf>]], output

  -- attributes are unordered so we don't check output (for now)
  it "should render multiple attributes", ->
    render_html ->
      link rel: "icon", type: "image/png", href: "dad"
      pre id: "hello", class: "things", style: [[border: image("http://leafo.net")]]


  it "should boolean attributes", ->
    output = render_html ->
      span required: true
      div required: false

    assert.same [[<span required></span><div></div>]], output

  it "should capture", ->
    -- we have to do it this way because in plain Lua 5.1, upvalues can't be
    -- joined, we only have a copy of the value.
    capture_result = {}

    output = render_html ->
      text "hello"
      capture_result.value = capture ->
        div "This is the capture"
      text "world"

    assert.same "helloworld", output
    assert.same "<div>This is the capture</div>", capture_result.value

  it "should capture into joined upvalue", ->
    -- skip on lua 5.1
    if _VERSION == "Lua 5.1" and not _G.jit
      pending "joined upvalues not available in Lua 5.1, skipping test"
      return

    capture_result = {}

    output = render_html ->
      text "hello"
      capture_result.value = capture ->
        div "This is the capture"
      text "world"

    assert.same "helloworld", output
    assert.same "<div>This is the capture</div>", capture_result.value


  describe "classnames", ->
    import classnames from require "lapis.html"

    it "flattens classes", ->
      assert.same "one two last haveit yes", classnames {
        "one"
        "two"
        yes: true
        { skipped: false, haveit: true, "", "last"}
      }

    it "passes string through", ->
      assert.same "hi", classnames "hi"
      assert.same "", classnames ""
      assert.same " um  ", classnames " um  "

  describe "Widget", ->
    it "should render the widget", ->
      class TestWidget extends Widget
        content: =>
          div class: "hello", @message
          raw @inner

      input = render_widget TestWidget message: "Hello World!", inner: -> b "Stay Safe"
      assert.same input, [[<div class="hello">Hello World!</div><b>Stay Safe</b>]]

    it "creates widget from the lapis.lua module", ->
      TestWidget = require("lapis.lua").class "TestWidget", {
        some_method: =>
          span "good work"

        content: =>
          div "Hello world"
          @some_method!
      }, Widget

      assert.same [[<div>Hello world</div><span>good work</span>]], TestWidget!\render_to_string!

    it "renders widget with inheritance", ->
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

    it "renders widget with inheritance and super", ->
      class BaseWidget extends Widget
        value: 100
        another_value: => 200

        content: =>
          div class: "base_widget", ->
            @inner!

        inner: => div "Hello #{@value} #{@another_value!}"

      class TestWidget extends BaseWidget
        inner: =>
          pre ->
            -- we can't use super directly since the rendering scope is unable to set the function environment
            -- this is the current 'recommended' approach to calling super
            @_buffer\call super.inner, @

      input = render_widget TestWidget!
      assert.same input, [[<div class="base_widget"><pre><div>Hello 100 200</div></pre></div>]]

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

    it "sets content_for on request helper", ->
      Request = require "lapis.request"
      class TheWidget extends Widget
        content: =>
          @content_for "title", -> div "hello world"
          @content_for "another", "yeah"

      widget = TheWidget!
      helper = setmetatable { }, __index: Request.__base
      widget\include_helper helper
      out = render_widget widget

      assert.same { _content_for_another: "yeah", _content_for_title: "<div>hello world</div>" }, helper

    it "fails to set content_for if there is no request helper", ->
      class TheWidget extends Widget
        content: =>
          @content_for "title", -> div "hello world"
          @content_for "another", "yeah"

      assert.has_error(
        -> render_widget TheWidget!
        "content_for called on a widget without a Request in the helper chain. content_for is only available in a request lifecycle"
      )

    it "renders content_for", ->
      Request = require "lapis.request"

      class TheLayout extends Widget
        content: =>
          assert @has_content_for("title"), "should have title content_for"
          assert @has_content_for("inner"), "should have inner content_for"
          assert @has_content_for("footer"), "should have footer content_for"
          assert not @has_content_for("hello"), "should not have hello content for"

          div class: "title", ->
            @content_for "title"

          @content_for "inner"
          @content_for "footer"

      class TheWidget extends Widget
        content: =>
          @content_for "title", -> div "hello world"
          @content_for "footer", "The's footer"
          div "what the heck?"


      request = setmetatable {
        _content_for_inner: {}
      }, __index: Request.__base

      view = TheWidget!
      view\include_helper request
      view request._content_for_inner

      layout = TheLayout!
      layout\include_helper request

      assert.same [[<div class="title"><div>hello world</div></div><div>what the heck?</div>The&#039;s footer]], render_widget layout

    it "appends multiple content for", ->
      Request = require "lapis.request"

      class TheLayout extends Widget
        content: =>
          -- layout should also be able to write to content for
          @content_for "deep", "Sure"
          @content_for "item", "999"

          element "content-for", ->
            @content_for "things"

          @content_for "deep"
          @content_for "item"

      class Child extends Widget
        content: =>
          @content_for "deep", "Very Deep!"
          text "Yup"

      class TheWidget extends Widget
        content: =>
          @content_for "things", -> div "hello world"
          @content_for "things", "dual world"
          widget Child!

      request = setmetatable {
        _content_for_inner: {}
      }, __index: Request.__base

      view = TheWidget!
      view\include_helper request
      view request._content_for_inner

      layout = TheLayout!
      layout\include_helper request

      assert.same {
        _content_for_deep: "Very Deep!",
        _content_for_inner: { "Yup" }
        _content_for_things: {
          "<div>hello world</div>"
          "dual world"
        }
      }, request

      assert.same [[<content-for><div>hello world</div>dual world</content-for>Very Deep!Sure999]], render_widget layout

    it "should instantiate widget class when passed to widget helper", ->
      class SomeWidget extends Widget
        content: =>
          @color = "blue"
          -- assert.Not.same @, SomeWidget
          text "hello!"

      render_html ->
        widget SomeWidget

      assert.same nil, SomeWidget.color

    it "should render widget inside of capture", ->
      capture_result = {}

      class InnerInner extends Widget
        content: =>
          out = capture ->
            span "yeah"
          raw out

      class Inner extends Widget
        content: =>
          dt "hello"
          widget InnerInner
          dt "world"

      class Outer extends Widget
        content: =>
          capture_result.value = capture ->
            div "before"
            widget Inner!
            div "after"

      assert.same [[]], render_widget Outer!
      assert.same [[<div>before</div><dt>hello</dt><span>yeah</span><dt>world</dt><div>after</div>]], capture_result.value

    describe "Widget:extend", ->
      it "creates basic widget", ->
        anonymous = Widget\extend {
          content: =>
            div "Hello #{@thing}"
        }

        named = Widget\extend "MyThing", {
          content: =>
            div "Wow #{@zang} from #{@@__name}"
        }

        assert.same "<div>Hello world</div>", anonymous(thing: "world")\render_to_string!
        assert.same "<div>Wow zong from MyThing</div>", named(zang: "zong")\render_to_string!

      it "creates widget from function", ->
        anonymous = Widget\extend =>
          div "Hello #{@thing}"

        named = Widget\extend "MyThing", =>
          div "Wow #{@zang} from #{@@__name}"

        assert.same "<div>Hello world</div>", anonymous(thing: "world")\render_to_string!
        assert.same "<div>Wow zong from MyThing</div>", named(zang: "zong")\render_to_string!

    describe "widget.render_to_file", ->
      class Inner extends Widget
        content: =>
          dt class: "cool", "hello"
          p ->
            strong "The world  #{@t}"
            @m!

          dt "world"

        m: =>
          raw "is &amp; here"

      it "renders to string by filename", ->
        time = os.time!

        Inner({
          t: time
        })\render_to_file "widget_out.html"

        written = assert(io.open("widget_out.html"))\read "*a"

        assert.same [[<dt class="cool">hello</dt><p><strong>The world  ]] .. time .. [[</strong>is &amp; here</p><dt>world</dt>]], written


      it "writes to file interface", ->
        written = {}
        fake_file = {
          write: (content) =>
            table.insert written, content
        }

        time = os.time!

        Inner({
          t: time
        })\render_to_file fake_file

        assert.same [[<dt class="cool">hello</dt><p><strong>The world  ]] .. time .. [[</strong>is &amp; here</p><dt>world</dt>]], table.concat(written)

    describe "@include", ->
      after_each ->
        package.loaded["widgets.mymixin"] = nil

      it "copies method from mixin", ->
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

        assert.false is_mixins_class SomeWidget
        assert.true is_mixins_class SomeWidget.__parent
        assert.false is_mixins_class SomeWidget.__parent.__parent

        assert.false is_mixins_class SomeWidget!
        assert.false is_mixins_class SomeWidget.__parent! -- should it be impossible to instantiate a mixins class??

      it "includes mixin from Lua created class", ->
        class SomeMixin
          some_method: =>
            span "good work"

        TestWidget = require("lapis.lua").class "TestWidget", {
          content: =>
            div "Hello world"
            @some_method!
        }, Widget, (cls) ->
          cls\include SomeMixin

        assert.same [[<div>Hello world</div><span>good work</span>]], TestWidget!\render_to_string!

        assert.false is_mixins_class TestWidget
        assert.true is_mixins_class TestWidget.__parent

      it "includes by module name", ->
        package.loaded["widgets.mymixin"] = class MyMixin
          render_list: =>
            div "I am a list"

        class SomeWidget extends Widget
          @include "widgets.mymixin"

          content: =>
            div class: "outer", ->
              @render_list!

        assert.same [[<div class="outer"><div>I am a list</div></div>]],
          render_widget SomeWidget!

      it "supports including class with inheritance", ->
        class Alpha
          thing: =>
            li class: "the_thing", "hello"

          thong: =>
            li class: "the_thong", "world"

        class Beta extends Alpha
          thong: =>
            li class: "fake_thong", "whoa"

          render_list: =>
            ul ->
              @thing!
              @thong!

        class SomeWidget extends Widget
          @include Beta

          content: =>
            div class: "outer", ->
              @render_list!

        assert.same [[<div class="outer"><ul><li class="the_thing">hello</li><li class="fake_thong">whoa</li></ul></div>]],
          render_widget SomeWidget!

      it "handles method collision", ->
        class TestMixin
          thing: ->
            div class: "the_thing", ->
              text "hello world"

          hose: ->
            text "test hose"

        class OtherMixin
          hose: ->
            text "other hose"

        class SomeWidget extends Widget
          @include TestMixin
          @include OtherMixin

          thing: ->
            code class: "coder", "here's the code"

          content: =>
            div class: "outer", ->
              @thing!
              @hose!

        assert.same [[<div class="outer"><code class="coder">here&#039;s the code</code>other hose</div>]],
          render_widget SomeWidget!

      it "calls super method", ->
        class TestMixin
          height: => 10

        class SomeWidget extends Widget
          @include TestMixin

          height: =>
            super! + 12

          content: =>
            span "data-height": @height!

        assert.same [[<span data-height="22"></span>]],
          render_widget SomeWidget!

      it "does not re-mixin Widget", ->
        class MistakeMixin extends Widget
          height: => 10

        assert.has_error(
          ->
            class SomeWidget extends Widget
              @include MistakeMixin
          "Your widget tried to include a class that extends from Widget. An included class should be a plain class and not another widget"
        )

      it "does not allow include on Widget", ->
        class MistakeMixin
          height: => 10

        assert.has_error(
          -> Widget\include MistakeMixin
          "You attempted to call call Widget:include on the read-only Widget base class. You must create a sub-class to use include"
        )

