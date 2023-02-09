
lapis = require "lapis"

import mock_action, mock_request, assert_request from require "lapis.spec.request"

mock_app = (...) ->
  mock_action lapis.Application, ...

describe "lapis.application", ->
  before_each ->
    -- unload any dynamically loaded modules for views & actions
    for k,v in pairs package.loaded
      if k\match("^actions%.") or k\match("^vies%.")
        package.loaded[k] = nil

  describe "mutation check", ->
    it "prevents adding routes", ->
      assert.has_error(
        -> lapis.Application\match("hello", ->)
        "lapis.Application is not able to be modified with routes. You must either subclass or instantiate it"
      )

    it "prevents adding features", ->
      assert.has_error(
        -> lapis.Application\enable "exceptions"
        "You tried to enable a feature on the read-only class lapis.Application. You must sub-class it before enabling features"
      )

  describe "find_action", ->
    action1 = ->
    action2 = ->

    it "finds action", ->
      class SomeApp extends lapis.Application
        [hello: "/cool-dad"]: action1
        [world: "/another-dad"]: action2

      assert.same action1, (SomeApp\find_action "hello")
      assert.same action2, (SomeApp\find_action "world")
      assert.same nil, (SomeApp\find_action "nothing")

    it "finds require'd action", ->
      package.loaded["actions.hello"] = action1
      package.loaded["actions.admin.cool"] = action2

      class SomeApp extends lapis.Application
        [hello: "/cool-dad"]: true
        [world: "/uncool-dad"]: "admin.cool"

      assert.same action1, (SomeApp\find_action "hello")
      assert.same action2, (SomeApp\find_action "world")


  describe "dispatch", ->
    describe "lazy loaded actions", ->
      import mock_request from require "lapis.spec.request"

      class BaseApp extends lapis.Application
        [test_route: "/hello/:var"]: true
        [another: "/good-stuff"]: "hello_world"
        [regular: "/hmm"]: ->
        "/yo": true

      before_each ->
        package.loaded["actions.test_route"] = spy.new ->
        package.loaded["actions.hello_world"] = spy.new ->

      it "dispatches action by route name", ->
        mock_request BaseApp, "/hello/5"
        assert.spy(package.loaded["actions.test_route"]).was.called!
        assert.spy(package.loaded["actions.hello_world"]).was_not.called!

      it "dispatches action by string name", ->
        mock_request BaseApp, "/good-stuff"

        assert.spy(package.loaded["actions.test_route"]).was_not.called!
        assert.spy(package.loaded["actions.hello_world"]).was.called!

      it "doesn't call other actions for unrelated route", ->
        mock_request BaseApp, "/hmm"

        assert.spy(package.loaded["actions.test_route"]).was_not.called!
        assert.spy(package.loaded["actions.hello_world"]).was_not.called!

        mock_request BaseApp, "/hmm"

      it "failes to load `true` action with no route name", ->
        assert.has_error ->
          mock_request BaseApp, "/yo"

  describe "inheritance", ->
    local result

    before_each ->
      result = nil

    class BaseApp extends lapis.Application
      "/yeah": => result = "base yeah"
      [test_route: "/hello/:var"]: => result = "base test"

    class ChildApp extends BaseApp
      "/yeah": => result = "child yeah"
      "/thing": => result = "child thing"

    it "finds route in base app", ->
      status, buffer, headers = mock_request ChildApp, "/hello/world", {}
      assert.same 200, status
      assert.same "base test", result

    it "generates url from route in base", ->
      url = mock_action ChildApp, =>
        @url_for "test_route", var: "foobar"

      assert.same url, "/hello/foobar"

    it "overrides route in base class", ->
      status, buffer, headers = mock_request ChildApp, "/yeah", {}
      assert.same 200, status
      assert.same "child yeah", result

    it "overrides route by route name", ->
      class Root extends lapis.Application
        layout: false
        [test_route: "/hello/:var"]: => "original"

      class ChildApp extends Root
        [test_route: "/zone"]: => "override"

      status, res = mock_request ChildApp, "/zone", {}
      assert.same {200, "override"}, {status, res}

      -- route does not exist, overwritten
      assert.has_error ->
        mock_request ChildApp, "/hello/world", {}

      assert.same "/zone", ChildApp!.router\url_for "test_route", var: "whoa"

    it "re-used path replaces route name", ->
      class Root extends lapis.Application
        layout: false
        [first: "/hello/:cool"]: => "first"

      class ChildApp extends Root
        [second: "/hello/:cool"]: => "second"

      status, res = mock_request ChildApp, "/hello/yeah", {}
      assert.same {200, "second"}, {status, res}

      app = ChildApp!
      assert.same "/hello/whoa", app.router\url_for "second", cool: "whoa"
      assert.has_error(
        -> app.router\url_for "first"
        "lapis.router: There is no route named: first"
      )

  describe "include", ->
    local result

    before_each ->
      result = nil

    it "app class includes app class", ->
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

    it "app class includes app class with named routes", ->
      class SubApp extends lapis.Application
        [hello: "/hello"]: => result = "hello"

      class App extends lapis.Application
        @include SubApp
        [world: "/world"]: => result = "world"

      app = App!
      req = App.Request App!, {}, {}
      assert.same "/hello", req\url_for "hello"
      assert.same "/world", req\url_for "world"

    it "sets sub-app prefix path", ->
      class SubApp extends lapis.Application
        [hello: "/hello"]: => result = "hello"

      class App extends lapis.Application
        @include SubApp, path: "/sub"
        [world: "/world"]: => result = "world"

      app = App!
      req = App.Request App!, {}, {}
      assert.same "/sub/hello", req\url_for "hello"
      assert.same "/world", req\url_for "world"

    it "sets sub-app url name prefix", ->
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

    it "sets include options from target app", ->
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

    it "included application supports require'd action", ->
      s = {} -- use table address for unique identifier for action result

      package.loaded["actions.hello"] = -> "action1 #{s}"
      package.loaded["actions.admin.cool"] = -> "action2 #{s}"

      class SubApp extends lapis.Application
        [hello: "/cool-dad"]: true
        [world: "/uncool-dad"]: "admin.cool"

      class SomeApp extends lapis.Application
        layout: false
        @include SubApp

        "/some-dad": => "hi"

      status, buffer, headers = mock_request SomeApp, "/cool-dad", {}

      assert.same {
        status: 200
        buffer: "action1 #{tostring s}"
      }, { :status, :buffer }

      status, buffer, headers = mock_request SomeApp, "/uncool-dad", {}

      assert.same {
        status: 200
        buffer: "action2 #{tostring s}"
      }, { :status, :buffer }

    it "included application supports require'd action and include name", ->
      s = {}

      package.loaded["actions.subapp.hello"] = -> "subapp action1 #{s}"
      package.loaded["actions.subapp.admin.cool"] = -> "subapp action2 #{s}"

      class SubApp extends lapis.Application
        name: "subapp."

        [hello: "/cool-dad"]: true
        [world: "/uncool-dad"]: "admin.cool"

      class SomeApp extends lapis.Application
        layout: false
        @include SubApp

        "/some-dad": => "hi"

      status, buffer, headers = mock_request SomeApp, "/cool-dad", {}

      assert.same {
        status: 200
        buffer: "subapp action1 #{tostring s}"
      }, { :status, :buffer }

      status, buffer, headers = mock_request SomeApp, "/uncool-dad", {}

      assert.same {
        status: 200
        buffer: "subapp action2 #{tostring s}"
      }, { :status, :buffer }


    it "included application supports require'd action with before filter", ->
      s = {}
      package.loaded["actions.one"] = => "action1 #{s} #{@something}"
      package.loaded["actions.admin.two"] = => "action2 #{s} #{@something}"

      class SubApp extends lapis.Application
        @before_filter (r) =>
          @something = "Before filter has run!"

        [one: "/cool-dad"]: true
        [two: "/uncool-dad"]: "admin.two"

      class SomeApp extends lapis.Application
        layout: false
        @include SubApp

        "/some-dad": => "hi"

      status, buffer, headers = mock_request SomeApp, "/cool-dad", {}

      assert.same {
        status: 200
        buffer: "action1 #{s} Before filter has run!"
      }, { :status, :buffer }

      status, buffer, headers = mock_request SomeApp, "/uncool-dad", {}

      assert.same {
        status: 200
        buffer: "action2 #{s} Before filter has run!"
      }, { :status, :buffer }

      status, buffer, headers = mock_request SomeApp, "/some-dad", {}

      assert.same {
        status: 200
        buffer: "hi"
      }, { :status, :buffer }

    describe "instance #ddd", ->
      it "includes instance into instance", ->
        app1 = lapis.Application!
        app1\match "/hello", => "hello"

        app2 = lapis.Application!
        app2.layout = false
        app2\match "/world", => "world"
        app2\include app1

        assert.same "hello", (select 2, mock_request app2, "/hello")
        assert.same "world", (select 2, mock_request app2, "/world")

      it "includes class into instance", ->
        class Things extends lapis.Application
          [hello: "/hello"]: => "hello!"

        app = lapis.Application!
        app.layout = false
        app\match "/world", => "world!"

        app\include Things

        assert.same "hello!", (select 2, mock_request app, "/hello")
        assert.same "world!", (select 2, mock_request app, "/world")

        app2 = lapis.Application!
        app2.layout = false
        app2\match "/world", => "world!"

        app2\include Things!

        assert.same "hello!", (select 2, mock_request app2, "/hello")
        assert.same "world!", (select 2, mock_request app2, "/world")

      it "includes an instance into a class", ->
        class Things extends lapis.Application
          [hello: "/hello"]: => "hello!!"

        things = Things!
        things\match "/world", => "world!!"

        class Whoa extends lapis.Application
          layout: false
          @include things
          [whoa: "/whoa"]: => "whoa!!"

        assert.same "hello!!", (select 2, mock_request Whoa, "/hello")
        assert.same "world!!", (select 2, mock_request Whoa, "/world")
        assert.same "whoa!!", (select 2, mock_request Whoa, "/whoa")

  describe "default route", ->
    it "hits default route", ->
      local res

      class App extends lapis.Application
        "/": =>
        default_route: =>
          res = "bingo!"

      status, body = mock_request App, "/hello", {}
      assert.same 200, status
      assert.same "bingo!", res

  describe "default layout", ->
    it "uses widget as layout", ->
      import Widget from require "lapis.html"
      class TestApp extends lapis.Application
        layout: class Layout extends Widget
          content: =>
            h1 "hello world"
            @content_for "inner"
            div class: "footer"

        "/": => "yeah"

      status, body = assert_request TestApp, "/"
      assert.same [[<h1>hello world</h1>yeah<div class="footer"></div>]], body

    it "uses module name as layout", ->
      import Widget from require "lapis.html"
      class Layout extends Widget
        content: =>
          div class: "content", ->
            @content_for "inner"

      package.loaded["views.test_layout"] = Layout
      class TestApp extends lapis.Application
        layout: "test_layout"
        "/": => "yeah"

      status, body = assert_request TestApp, "/"
      assert.same [[<div class="content">yeah</div>]], body

  describe "error capturing", ->
    import capture_errors, capture_errors_json, assert_error,
      yield_error from require "lapis.application"

    it "capture_errors", ->
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


    it "capture_errors_json", ->
      result = "no"

      class ErrorApp extends lapis.Application
        "/error_route": capture_errors_json =>
          yield_error "something bad happened!"
          result = "yes"

      status, body, headers = assert_request ErrorApp, "/error_route"

      assert.same "no", result
      assert.same [[{"errors":["something bad happened!"]}]], body
      assert.same "application/json", headers["Content-Type"]

  describe "respond to", ->
    import respond_to from require "lapis.application"

    it "responds to basic verbs", ->
      class RespondToApp extends lapis.Application
        layout: false
        "/test": respond_to {
          GET: => "GET world"
          DELETE: => "DELETE world"
          PUT: => "PUT world"
        }

      request_method = (m) ->
        (select 2, assert_request RespondToApp, "/test", method: m)

      assert.same "GET world", request_method!
      assert.same "DELETE world", request_method "DELETE"
      assert.same "PUT world", request_method "PUT"

    -- spec for default HEAD
    it "responds to HEAD by default", ->
      fn = respond_to {
        GET: => "hello world"
      }

      assert.same {
        layout: false
      }, fn {
        req: { method: "HEAD" }
      }

    it "default missing method handler", ->
      fn = respond_to {
        HEAD: false -- this disables the default head responder
        GET: => "hello world"
      }

      assert.has_error(
        ->
          fn {
            req: { method: "PUT" }
          }
        "don't know how to respond to PUT"
      )

      assert.has_error(
        ->
          fn {
            req: { method: "HEAD" }
          }
        "don't know how to respond to HEAD"
      )

    it "on_error", ->
      import yield_error, capture_errors from require "lapis.application"

      -- we do an extra capture errors to ensure the right error handler is capturing
      fn = capture_errors respond_to {
        on_error: =>
          json: { captured: "hello", errors: @errors }

        POST: =>
          yield_error "something bad happened!"
      }

      assert.same {
        json: {
          errors: {"something bad happened!"}
          captured: "hello"
        }
      }, fn {
        req: { method: "POST" }
      }

      -- no error handler, the outer should capture
      fn = capture_errors respond_to {
        POST: => yield_error "something bad happened!"
      }

      assert.same {
        render: true
      }, fn {
        req: { method: "POST" }
      }

    it "on_invalid_method", ->
      fn = respond_to {
        on_invalid_method: =>
          "got invalid method...: #{@req.method}"

        HEAD: false

        POST: =>
          "hello"
      }

      assert.same "hello", fn {
        req: { method: "POST" }
      }

      assert.same "got invalid method...: GET", fn {
        req: { method: "GET" }
      }

      assert.same "got invalid method...: HEAD", fn {
        req: { method: "HEAD" }
      }

    it "on_invalid_method & capture_errors", ->
      import yield_error from require "lapis.application"

      fn = respond_to {
        on_error: =>
          "<<#{table.concat @errors, ", "}>>"

        on_invalid_method: =>
          yield_error "bad method: #{@req.method}"

        HEAD: false

        POST: => "cool"
      }

      assert.same "<<bad method: HEAD>>", fn {
        req: { method: "HEAD" }
      }

      assert.same "<<bad method: DELETE>>", fn {
        req: { method: "DELETE" }
      }

      assert.same "cool", fn {
        req: { method: "POST" }
      }

  describe "route builders on class", ->
    it "calls match on calss", ->
      local result

      counter = 0

      class SomeApp extends lapis.Application
        @before_filter ->
          counter += 1

        @match "/", => result = "root"
        @match "/user/:id", => result = "user_id"

        @get "cool", "/cool", => result = "get:#{@route_name}"
        @post "cool", "/cool", => result = "post:#{@route_name}"

      assert_request SomeApp, "/"
      assert.same "root", result
      assert.same 1, counter

      assert_request SomeApp, "/user/23042"
      assert.same "user_id", result
      assert.same 2, counter

      assert_request SomeApp, "/cool"
      assert.same "get:cool", result
      assert.same 3, counter

      assert_request SomeApp, "/cool", method: "POST"
      assert.same "post:cool", result
      assert.same 4, counter

      assert.has_error ->
        assert_request SomeApp, "/cool", method: "DELETE"

  describe "instancing", ->
    it "matchs a route", ->
      local res
      app = lapis.Application!
      app\match "/", => res = "root"
      app\match "/user/:id", => res = @params.id

      app\build_router!

      assert_request app, "/"
      assert.same "root", res

      assert_request app, "/user/124"
      assert.same "124", res

    it "responds to verb", ->
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

    it "doesn't allow route mismatch for verbs", ->
      app = lapis.Application!

      app\get "one", "/one", ->
      assert.has_error(
        -> app\post("/one", ->)
        "You are trying to add a new verb action to a route that was declared with and existing path but different route name. Please ensure you use the same route name and path combination when adding additional verbs to a route."
      )

      app\get "/two", ->
      assert.has_error(
        -> app\post("two", "/two", ->)
        "You are trying to add a new verb action to a route that was declared with and existing path but different route name. Please ensure you use the same route name and path combination when adding additional verbs to a route."
      )

      -- TODO: this should fail
      app\get "three", "/three", ->
      app\post "three", "/four", ->

    it "finds actions by name for verb", ->
      local res

      package.loaded["actions.one"] = -> res = "one"
      package.loaded["actions.two"] = -> res = "two"
      package.loaded["actions.three"] = -> res = "three"
      package.loaded["actions.four.get"] = -> res = "four GET"
      package.loaded["actions.four.post"] = -> res = "four POST"

      app = lapis.Application!
      app\match "one", "/one", true
      app\match "/two", "two"

      app\post "/three", "three"

      app\get "/four", "four.get"
      app\post "/four", "four.post"

      app\build_router!

      assert_request app, "/one"
      assert.same "one", res

      assert_request app, "/two"
      assert.same "two", res

      assert_request app, "/three", method: "POST"
      assert.same "three", res

      assert_request app, "/four"
      assert.same "four GET", res

      assert_request app, "/four",method: "POST"
      assert.same "four POST", res

    it "hits default route", ->
      local res

      app = lapis.Application!
      app\match "/", -> res = "/"
      app.default_route = -> res = "default_route"
      app\build_router!

      assert_request app, "/hello"
      assert.same "default_route", res

    it "strips trailing / to find route", ->
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

    it "preserves order of route", ->
      app = lapis.Application!

      routes = for i=1,20
        with r = "/route#{i}"
          app\get r, =>

      app\build_router!

      assert.same routes, [tuple[1] for tuple in *app.router.routes]

  describe "errors", ->
    class ErrorApp extends lapis.Application
      "/": =>
        error "I am an error!"

    it "renders default error page", ->
      status, body, h = mock_request ErrorApp, "/", allow_error: true
      assert.same 500, status
      assert.truthy (body\match "I am an error")

      -- only set on test env
      assert.truthy h["X-Lapis-Error"]

    it "renders default error page as json", ->
      status, body, h = mock_request ErrorApp, "/", {
        allow_error: true
        expect: "json"
        headers: {
          accept: "application/json"
        }
      }
      assert.same 500, status

      assert.truthy body.error
      assert body.error\match "I am an error"

      assert.truthy body.traceback
      assert.truthy body.lapis

      -- only set on test env
      assert.truthy h["X-Lapis-Error"]


    it "raises error in spec by default", ->
      assert.has_error ->
        mock_request ErrorApp, "/"

    it "renders custom error page", ->
      class CustomErrorApp extends lapis.Application
        handle_error: (err, msg) =>
          assert.truthy @original_request
          "hello world", layout: false, status: 444

        "/": =>
          error "I am an error!"

      status, body, h = mock_request CustomErrorApp, "/", allow_error: true
      assert.same 444, status
      assert.same "hello world", body

      -- should still be set
      assert.truthy h["X-Lapis-Error"]


  describe "custom request", ->
    it "renders with custom request (overriding supuport)", ->
      class R extends lapis.Application.Request
        @support: {
          load_session: =>
            @session = {"cool"}

          write_session: =>
        }

      local the_session
      class A extends lapis.Application
        Request: R

        "/": =>
          the_session = @session
          "ok"

      mock_request A, "/"
      assert.same {"cool"}, the_session

  -- should be requrest spec?
  describe "inline html", ->
    class HtmlApp extends lapis.Application
      layout: false

      "/": =>
        @html -> div "hello world"

    it "renders html", ->
      status, body = assert_request HtmlApp, "/"
      assert.same "<div>hello world</div>", body

  -- this should be in request spec...
  describe "request:build_url", ->
    it "build url", ->
      assert.same "http://localhost", mock_app "/hello", {}, =>
        @build_url!

    it "build url with path", ->
      assert.same "http://localhost/hello_dog", mock_app "/hello", {}, =>
        @build_url "hello_dog"

    it "build url with host and port", ->
      assert.same "http://leaf:2000/hello",
        mock_app "/hello", { host: "leaf", port: 2000 }, =>
          @build_url @req.parsed_url.path

    it "doesn't include default port for scheme http", ->
      assert.same "http://leaf/whoa",
        mock_app "/hello", { host: "leaf", port: 80 }, =>
          @build_url "whoa"

    it "doesn't include default port for scheme https", ->
      assert.same "https://leaf/whoa",
        mock_app "/hello", { host: "leaf", scheme: "https", port: 443 }, =>
          @build_url "whoa"

    it "build url with overridden query", ->
      assert.same "http://localhost/please?yes=no",
        mock_app "/hello", {}, =>
          @build_url "please?okay=world", { query: "yes=no" }

    it "build url with overridden port and host", ->
      assert.same "http://yes:4545/cat?sure=dad",
        mock_app "/hello", { host: "leaf", port: 2000 }, =>
          @build_url "cat?sure=dad", host: "yes", port: 4545

    it "return arg if already build url", ->
      assert.same "http://leafo.net",
        mock_app "/hello", { host: "leaf", port: 2000 }, =>
          @build_url "http://leafo.net"


