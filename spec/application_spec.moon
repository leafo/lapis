
lapis = require "lapis"

import mock_action, mock_request, assert_request from require "lapis.spec.request"

mock_app = (...) ->
  mock_action lapis.Application, ...

describe "application", ->
  action1 = ->
  action2 = ->

  class SomeApp extends lapis.Application
    [hello: "/cool-dad"]: action1
    [world: "/another-dad"]: action2

  it "should find the action", ->
    assert.same action1, (SomeApp\find_action "hello")
    assert.same action2, (SomeApp\find_action "world")
    assert.same nil, (SomeApp\find_action "nothing")

describe "request:build_url", ->
  it "should build url", ->
    assert.same "http://localhost", mock_app "/hello", {}, =>
      @build_url!

  it "should build url with path", ->
    assert.same "http://localhost/hello_dog", mock_app "/hello", {}, =>
      @build_url "hello_dog"

  it "should build url with host and port", ->
    assert.same "http://leaf:2000/hello",
      mock_app "/hello", { host: "leaf", port: 2000 }, =>
        @build_url @req.parsed_url.path

  it "should build url with overridden query", ->
    assert.same "http://localhost/please?yes=no",
      mock_app "/hello", {}, =>
        @build_url "please?okay=world", { query: "yes=no" }

  it "should build url with overridden port and host", ->
    assert.same "http://yes:4545/cat?sure=dad",
      mock_app "/hello", { host: "leaf", port: 2000 }, =>
        @build_url "cat?sure=dad", host: "yes", port: 4545

  it "should return arg if already build url", ->
    assert.same "http://leafo.net",
      mock_app "/hello", { host: "leaf", port: 2000 }, =>
        @build_url "http://leafo.net"

describe "application inheritance", ->
  local result

  before_each ->
    result = nil

  class BaseApp extends lapis.Application
    "/yeah": => result = "base yeah"
    [test_route: "/hello/:var"]: => result = "base test"

  class ChildApp extends BaseApp
    "/yeah": => result = "child yeah"
    "/thing": => result = "child thing"

  it "should find route in base app", ->
    status, buffer, headers = mock_request ChildApp, "/hello/world", {}
    assert.same 200, status
    assert.same "base test", result

  it "should generate url from route in base", ->
    url = mock_action ChildApp, =>
      @url_for "test_route", var: "foobar"

    assert.same url, "/hello/foobar"

  it "should override route in base class", ->
    status, buffer, headers = mock_request ChildApp, "/yeah", {}
    assert.same 200, status
    assert.same "child yeah", result


describe "application composition", ->
  local result

  before_each ->
    result = nil

  it "should include another app", ->
    class SubApp extends lapis.Application
      "/hello": => result = "hello"

    class App extends lapis.Application
      @include SubApp

      "/world": => result = "world"

    status, buffer, headers = mock_request App, "/hello", {}
    assert.same 200, status
    assert.same "hello", result

    status, buffer, headers = mock_request App, "/world", {}
    assert.same 200, status
    assert.same "world", result

  it "should include another app", ->
    class SubApp extends lapis.Application
      "/hello": => result = "hello"

    class App extends lapis.Application
      @include SubApp

      "/world": => result = "world"

    status, buffer, headers = mock_request App, "/hello", {}
    assert.same 200, status
    assert.same "hello", result

    status, buffer, headers = mock_request App, "/world", {}
    assert.same 200, status
    assert.same "world", result

  it "should merge url table", ->
    class SubApp extends lapis.Application
      [hello: "/hello"]: => result = "hello"

    class App extends lapis.Application
      @include SubApp
      [world: "/world"]: => result = "world"

    app = App!
    req = App.Request App!, {}, {}
    assert.same "/hello", req\url_for "hello"
    assert.same "/world", req\url_for "world"

  it "should set sub app prefix path", ->
    class SubApp extends lapis.Application
      [hello: "/hello"]: => result = "hello"

    class App extends lapis.Application
      @include SubApp, path: "/sub"
      [world: "/world"]: => result = "world"

    app = App!
    req = App.Request App!, {}, {}
    assert.same "/sub/hello", req\url_for "hello"
    assert.same "/world", req\url_for "world"

  it "should set sub app url name prefix", ->
    class SubApp extends lapis.Application
      [hello: "/hello"]: => result = "hello"

    class App extends lapis.Application
      @include SubApp, name: "sub_"
      [world: "/world"]: => result = "world"

    app = App!
    req = App.Request App!, {}, {}
    assert.has_error -> req\url_for "hello"

    assert.same "/hello", req\url_for "sub_hello"
    assert.same "/world", req\url_for "world"

  it "should set include options from target app", ->
    class SubApp extends lapis.Application
      @path: "/sub"
      @name: "sub_"

      [hello: "/hello"]: => result = "hello"

    class App extends lapis.Application
      @include SubApp
      [world: "/world"]: => result = "world"

    app = App!
    req = App.Request App!, {}, {}
    assert.same "/sub/hello", req\url_for "sub_hello"
    assert.same "/world", req\url_for "world"

describe "application default route", ->
  it "should hit default route", ->
    local res

    class App extends lapis.Application
      "/": =>
      default_route: =>
        res = "bingo!"

    status, body = mock_request App, "/hello", {}
    assert.same 200, status
    assert.same "bingo!", res

describe "application inline html", ->
  class HtmlApp extends lapis.Application
    layout: false

    "/": =>
      @html -> div "hello world"

  it "should render html", ->
    status, body = assert_request HtmlApp, "/"
    assert.same "<div>hello world</div>", body

describe "application error capturing", ->
  import capture_errors, capture_errors_json, assert_error,
    yield_error from require "lapis.application"

  it "should capture error", ->
    result = "no"
    errors = nil

    class ErrorApp extends lapis.Application
      "/error_route": capture_errors {
        on_error: =>
          errors = @errors

        =>
          yield_error "something bad happened!"
          result = "yes"
      }

    assert_request ErrorApp, "/error_route"

    assert.same "no", result
    assert.same {"something bad happened!"}, errors


  it "should capture error as json", ->
    result = "no"

    class ErrorApp extends lapis.Application
      "/error_route": capture_errors_json =>
        yield_error "something bad happened!"
        result = "yes"

    status, body, headers = assert_request ErrorApp, "/error_route"

    assert.same "no", result
    assert.same [[{"errors":["something bad happened!"]}]], body
    assert.same "application/json", headers["Content-Type"]

describe "instance app", ->
  it "should match a route", ->
    local res
    app = lapis.Application!
    app\match "/", => res = "root"
    app\match "/user/:id", => res = @params.id

    app\build_router!

    assert_request app, "/"
    assert.same "root", res

    assert_request app, "/user/124"
    assert.same "124", res

  it "should should respond to verb", ->
    local res
    app = lapis.Application!
    app\match "/one", ->
    app\get "/hello", => res = "get"
    app\post "/hello", => res = "post"
    app\match "two", ->

    app\build_router!

    assert_request app, "/hello"
    assert.same "get", res

    assert_request app, "/hello", post: {}
    assert.same "post", res

  it "should hit default route", ->
    local res

    app = lapis.Application!
    app\match "/", -> res = "/"
    app.default_route = -> res = "default_route"
    app\build_router!

    assert_request app, "/hello"
    assert.same "default_route", res

  it "should strip trailing / to find route", ->
    local res

    app = lapis.Application!
    app\match "/hello", -> res = "/hello"
    app\match "/world/", -> res = "/world/"
    app\build_router!

    -- exact match, no default action
    assert_request app, "/world/"
    assert.same "/world/", res

    status, _, headers = assert_request app, "/hello/"
    assert.same 301, status
    assert.same "http://localhost/hello", headers.location

  it "should include another app", ->
    do return -- TODO
    local res

    sub_app = lapis.Application!
    sub_app\get "/hello", => res = "hello"

    app = lapis.Application!
    app\get "/cool", => res = "cool"
    app\include sub_app

  it "should preserve order of route #preserve", ->
    app = lapis.Application!

    routes = for i=1,20
      with r = "/route#{i}"
        app\get r, =>

    app\build_router!

    assert.same routes, [tuple[1] for tuple in *app.router.routes]


