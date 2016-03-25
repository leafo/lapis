
lapis = require "lapis"

import
  mock_request
  mock_action
  assert_request
  stub_request
  from require "lapis.spec.request"

describe "lapis.spec.request", ->
  describe "mock_request", ->
    class App extends lapis.Application
      "/hello": =>

    it "should mock a request", ->
      assert.same 200, (mock_request App, "/hello")
      assert.has_error ->
        mock_request App, "/world"

    it "should mock a request with double headers", ->
      mock_request App, "/hello", {
        method: "POST"
        headers: {
          ["Content-type"]: {
            "hello"
            "world"
          }
        }
      }

  describe "mock_action action", ->
    it "should mock action", ->
      assert.same "hello", mock_action lapis.Application, "/hello", {}, ->
        "hello"

  describe "stub_request", ->
    class SomeApp extends lapis.Application
      [cool_page: "/cool/:name"]: =>

    it "should stub a request object", ->
      req = stub_request SomeApp, "/"
      assert.same "/cool/world", req\url_for "cool_page", name: "world"

describe "lapis.request", ->
  describe "session", ->
    class SessionApp extends lapis.Application
      layout: false

      "/set_session/:value": =>
        @session.hello = @params.value

      "/get_session": =>
        @session.hello

    it "should set and read session", ->
      _, _, h = assert_request SessionApp, "/set_session/greetings"
      status, res = assert_request SessionApp, "/get_session", prev: h
      assert.same "greetings", res


  describe "json request", ->
    import json_params from require "lapis.application"

    it "should parse json object body", ->
      local res
      class SomeApp extends lapis.Application
        "/": json_params =>
          res = @params.thing

      assert_request SomeApp, "/", {
        headers: {
          "content-type": "application/json"
        }
        body: '{"thing": 1234}'
      }

      assert.same 1234, res

    it "should parse json array body", ->
      local res
      class SomeApp extends lapis.Application
        "/": json_params =>
          res = @params

      assert_request SomeApp, "/", {
        headers: {
          "content-type": "application/json"
        }
        body: '[1,"hello", {}]'
      }

      assert.same {1, "hello", {}}, res

    it "should not fail on invalid json", ->
      class SomeApp extends lapis.Application
        "/": json_params =>

      assert_request SomeApp, "/", {
        headers: {
          "content-type": "application/json"
        }
        body: 'helloworldland'
      }

  describe "write", ->
    write = (fn, ...) ->
      class A extends lapis.Application
        layout: false
        "/": fn

      mock_request A, "/", ...

    it "writes nothing, sets default content type", ->
      status, body, h = write ->

      assert.same 200, status
      assert.same "", body
      assert.same "text/html", h["Content-Type"]

    it "writes status code", ->
      status, body, h = write -> status: 420
      assert.same 420, status

    it "writes content type", ->
      _, _, h = write -> content_type: "text/javascript"
      assert.same "text/javascript", h["Content-Type"]

    it "writes headers", ->
      _, _, h = write -> {
        headers: {
          "X-Lapis-Cool": "zone"
          "Cache-control": "nope"
        }
      }

      assert.same "zone", h["X-Lapis-Cool"]
      assert.same "nope", h["Cache-Control"]

    it "does redirect", ->
      status, _, h = write -> { redirect_to: "/hi" }

      assert.same 302, status
      assert.same "http://localhost/hi", h["Location"]

    it "does permanent redirect", ->
      status, _, h = write -> { redirect_to: "/loaf", status: 301 }

      assert.same 301, status
      assert.same "http://localhost/loaf", h["Location"]

    it "writes string to buffer", ->
      status, body, h = write -> "hello"
      assert.same "hello", body

    it "writes many things to buffer, with options", ->
      status, body, h = write -> "hello", "world", status: 404
      assert.same 404, status
      assert.same "helloworld", body

    it "writes json", ->
      status, body, h = write -> json: { items: {1,2,3,4} }
      assert.same [[{"items":[1,2,3,4]}]], body
      assert.same "application/json", h["Content-Type"]

  describe "cookies", ->
    class CookieApp extends lapis.Application
      layout: false
      "/": => @cookies.world = 34

      "/many": =>
        @cookies.world = 454545
        @cookies.cow = "one cool ;cookie"

    class CookieApp2 extends lapis.Application
      layout: false
      cookie_attributes: => "Path=/; Secure; Domain=.leafo.net;"
      "/": => @cookies.world = 34

    it "should write a cookie", ->
      _, _, h = mock_request CookieApp, "/"
      assert.same "world=34; Path=/; HttpOnly", h["Set-Cookie"]

    it "should write multiple cookies", ->
      _, _, h = mock_request CookieApp, "/many"

      assert.same {
        'cow=one%20cool%20%3bcookie; Path=/; HttpOnly'
        'world=454545; Path=/; HttpOnly'
      }, h["Set-Cookie"]

    it "should write a cookie with cookie attributes", ->
      _, _, h = mock_request CookieApp2, "/"
      assert.same "world=34; Path=/; Secure; Domain=.leafo.net;", h["Set-Cookie"]

    it "should set cookie attributes with lua app", ->
      app = lapis.Application!
      app.cookie_attributes = =>
        "Path=/; Secure; Domain=.leafo.net;"

      app\get "/", =>
        @cookies.world = 34

      _, _, h = mock_request app, "/"
      assert.same "world=34; Path=/; Secure; Domain=.leafo.net;", h["Set-Cookie"]

  describe "layouts", ->
    after_each = ->
      package.loaded["views.another_layout"] = nil

    it "renders without layout", ->
      class LayoutApp extends lapis.Application
        layout: "cool_layout"
        "/": => "hello", layout: false

      status, res = mock_request LayoutApp, "/"
      assert.same "hello", res

    it "renders with layout by name", ->
      import Widget from require "lapis.html"
      package.loaded["views.another_layout"] = class extends Widget
        content: =>
          text "*"
          @content_for "inner"
          text "^"

      class LayoutApp extends lapis.Application
        layout: "cool_layout"
        "/": => "hello", layout: "another_layout"

      status, res = mock_request LayoutApp, "/"
      assert.same "*hello^", res

    it "renders layout with class", ->
      import Widget from require "lapis.html"

      class Layout extends Widget
        content: =>
          text "("
          @content_for "inner"
          text ")"

      class LayoutApp extends lapis.Application
        layout: "cool_layout"
        "/": =>
          "hello", layout: Layout

      status, res = mock_request LayoutApp, "/"
      assert.same "(hello)", res

-- these seem like an application spec and not a request one
describe "before filter", ->
  it "should run before filter", ->
    local val

    class BasicBeforeFilter extends lapis.Application
      @before_filter =>
        @hello = "world"

      "/": =>
        val = @hello

    assert_request BasicBeforeFilter, "/"
    assert.same "world", val

  it "should run before filter with inheritance", ->
    class BasicBeforeFilter extends lapis.Application
      @before_filter => @hello = "world"

    val = mock_action BasicBeforeFilter, =>
      @hello

    assert.same "world", val

  it "should run before filter scoped to app with @include", ->
    local base_val, parent_val

    class BaseApp extends lapis.Application
      @before_filter => @hello = "world"
      "/base_app": => base_val = @hello or "nope"

    class ParentApp extends lapis.Application
      @include BaseApp
      "/child_app": => parent_val = @hello or "nope"

    assert_request ParentApp, "/base_app"
    assert_request ParentApp, "/child_app"

    assert.same "world", base_val
    assert.same "nope", parent_val

  it "should cancel action if before filter writes", ->
    action_run = 0

    class SomeApp extends lapis.Application
      layout: false

      @before_filter =>
        if @params.value == "stop"
          @write "stopped!"

      "/hello/:value": => action_run += 1

    assert_request SomeApp, "/hello/howdy"
    assert.same action_run, 1

    _, res = assert_request SomeApp, "/hello/stop"
    assert.same action_run, 1
    assert.same "stopped!", res

  it "should create before filter for lua app", ->
    app = lapis.Application!

    local val

    app\before_filter =>
      @val = "yeah"

    app\get "/", =>
      val = @val

    assert_request app, "/"
    assert.same "yeah", val

