
import EtluaWidget from require "lapis.etlua"

describe "lapis.etlua", ->
  it "should render a widget", ->
    w = EtluaWidget\load([[hello world]])!
    assert.same "hello world", w\render_to_string!

  it "should render a widget with environment", ->
    w_cls = EtluaWidget\load([[The object is <%= color %> and <%= height %>!]])

    w = w_cls {
      height: "10px"
    }

    w\include_helper {
      color: "blue"
    }

    assert.same "The object is blue and 10px!", w\render_to_string!

  it "should bind helpers correctly", ->
    w = EtluaWidget\load([[-<%= hello() %>-]])!

    w\include_helper {
      id: 10
      hello: => "id: #{@id}"
    }

    assert.same "-id: 10-", w\render_to_string!

  it "should render content for", ->
    w_cls = EtluaWidget\load([[before <% content_for("thing") %>, <% content_for("other_thing")%> after]])

    w = w_cls {
      thing: -> div class: "big", "Hello"
      other_thing: "<div class='small'>yeah</div>"
    }

    assert.same [[before <div class="big">Hello</div>, <div class='small'>yeah</div> after]], w\render_to_string!

  describe "with application", ->
    lapis = require "lapis"
    import assert_request from require "lapis.spec.request"

    layout = EtluaWidget\load [[<html data-etlua><% content_for("inner") %></html>]]

    it "should render with layout", ->
      class EtluaApp extends lapis.Application
        layout: layout
        "/": => "hello!"

      code, body = assert_request EtluaApp, "/"
      assert.same [[<html data-etlua>hello!</html>]], body

    it "should render with layout and view with assign", ->
      class EtluaApp extends lapis.Application
        layout: layout
        "/": =>
          @color = "blue"
          render: EtluaWidget\load [[color: <%= color %>]]

      code, body = assert_request EtluaApp, "/"
      assert.same [[<html data-etlua>color: blue</html>]], body

    it "request helpers should work", ->
      class EtluaApp extends lapis.Application
        layout: layout
        [page: "/the-page"]: =>

        "/": =>
          render: EtluaWidget\load [[url: <%= url_for("page") %>]]

      code, body = assert_request EtluaApp, "/"
      assert.same [[<html data-etlua>url: /the-page</html>]], body

  describe "with widgets", ->
    import Widget from require "lapis.html"

    it "should let a widget render etlua", ->
      fragment = EtluaWidget\load [[color: <%= color %>]]

      class SomeWidget extends Widget
        content: =>
          div class: "widget", ->
              text "color:"
              text @color

          div class: "etlua", ->
            widget fragment!
      
      w = SomeWidget!

      w\include_helper {
        color: "green"
      }

      assert.same [[<div class="widget">color:green</div><div class="etlua">color: green</div>]],
        w\render_to_string!

    it "should let etlua render widget", ->
      class SomeWidget extends Widget
        content: =>
          div class: "hello_world"

      tpl = EtluaWidget\load [[before<% widget(SomeWidget) %>after]]
      w = tpl { :SomeWidget }
      assert.same [[before<div class="hello_world"></div>after]],
        w\render_to_string!

    it "should let etlua call render helper", ->
      tpl = EtluaWidget\load [[before<% render("spec.templates.moon_test") %>after]]
      assert.same [[before<div class="greeting">hello world</div>after]],
        tpl\render_to_string!


