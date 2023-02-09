
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

  it "renders an element", ->
    w = EtluaWidget\load([[before<% element("div", {color = "blue"}, function() span("good work") end) %>after]])!
    assert.same [[before<div color="blue"><span>good work</span></div>after]], w\render_to_string!

  it "allows access to self", ->
    w = EtluaWidget\load([[element: <%= self.element %>]])
    assert.same [[element: Hello]], w({
      element: "Hello"
    })\render_to_string!

  it "should bind helpers correctly", ->
    w = EtluaWidget\load([[-<%= hello() %>-]])!

    w\include_helper {
      id: 10
      hello: => "id: #{@id}"
    }

    assert.same "-id: 10-", w\render_to_string!

  it "renders content for", ->
    Request = require "lapis.request"

    w_cls = EtluaWidget\load([[before <% content_for("thing") %>, <% content_for("other_thing")%> after]])

    request = setmetatable {
      _content_for_thing: -> div class: "big", "Hello"
      _content_for_other_thing: "<div class='small'>yeah</div>"
    }, __index: Request.__base

    w = w_cls!
    w\include_helper request

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

    it "should work with request helpers", ->
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
      w = tpl!
      assert.same [[before<div class="greeting">hello world</div>after]],
        tpl\render_to_string!


    it "should pass arguments to sub widget", ->
      outer = assert EtluaWidget\load [[hello <% widget(Inner {color = "blue" }) %>]]
      inner = assert EtluaWidget\load [[the color is <%= color %>.]]

      w = outer { Inner: inner, color: "green" }
      out = w\render_to_string!
      assert.same [[hello the color is blue.]], out


    describe "with loadkit", ->
      before_each ->
        require "lapis.features.etlua"

      after_each ->
        loadkit = require "loadkit"
        loadkit.unregister "etlua"
        package.loaded["lapis.features.etlua"] = nil

      it "should render template from loadkit", ->
        tpl = EtluaWidget\load [[before<% render("spec.templates.etlua_test2") %>after<%= color %>]]
        w = tpl color: "green"

        out = w\render_to_string!
        assert.same [[beforeThis is the color: nil.
aftergreen]], out

      it "should pass arguments to widget with render", ->
        tpl = EtluaWidget\load [[before<% render("spec.templates.etlua_test2", { color = "blue"}) %>after]]
        w = tpl color: "green" -- should be overwritten

        out = w\render_to_string!
        assert.same [[beforeThis is the color: blue.
after]], out

      describe "with app", ->
        local app, tpl

        lapis = require "lapis"
        import assert_request from require "lapis.spec.request"

        before_each ->
          app = lapis.Application!
          app\enable "etlua"

          app\get "index", "/", =>
            @color = "maroon"
            render: tpl, layout: false

        it "should work with render", ->
          tpl = EtluaWidget\load [[hello<% render("spec.templates.etlua_test2") %>world]]

          status, body = assert_request app, "/"
          assert.same [[helloThis is the color: maroon.
world]], body

        it "should work with app helper in sub-template", ->
          tpl = EtluaWidget\load [[hello<% render("spec.templates.etlua_app_helper") %>world]]

          status, body = assert_request app, "/"
          assert.same [[helloIndex url: /
world]], body


