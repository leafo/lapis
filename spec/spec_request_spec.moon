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

    it "should mock request with session", ->
      class SessionApp extends lapis.Application
        "/test-session": =>
          import flatten_session from require "lapis.session"
          assert.same {
            color: "hello"
            height: {1,2,3,4}
          }, flatten_session @session

      mock_request SessionApp, "/test-session", {
        session: {
          color: "hello"
          height: {1,2,3,4}
        }
      }

  describe "mock_action", ->
    it "should mock action", ->
      assert.same "hello", mock_action lapis.Application, "/hello", {}, ->
        "hello"

  describe "stub_request", ->
    class SomeApp extends lapis.Application
      [cool_page: "/cool/:name"]: =>

    it "should stub a request object", ->
      req = stub_request SomeApp, "/"
      assert.same "/cool/world", req\url_for "cool_page", name: "world"

    it "populates params from POST body", ->
      req = stub_request SomeApp, "/", post: {name: "test", age: "25"}
      assert.same "test", req.params.name
      assert.same "25", req.params.age

    it "sets @POST for post params", ->
      req = stub_request SomeApp, "/", post: {foo: "bar"}
      assert.same {foo: "bar"}, req.POST

    it "sets @GET for query params", ->
      req = stub_request SomeApp, "/?color=blue"
      assert.same {color: "blue"}, req.GET

    it "allows direct params option", ->
      req = stub_request SomeApp, "/", params: {id: "5", name: "test"}
      assert.same "5", req.params.id
      assert.same "test", req.params.name

    it "merges direct params with POST params", ->
      req = stub_request SomeApp, "/", post: {a: "1"}, params: {b: "2"}
      assert.same "1", req.params.a
      assert.same "2", req.params.b

    it "provides access to session", ->
      req = stub_request SomeApp, "/", session: {user_id: 123}
      assert.same 123, req.session.user_id

    it "provides access to cookies", ->
      req = stub_request SomeApp, "/", cookies: {token: "abc123"}
      assert.same "abc123", req.cookies.token

    it "build_url works", ->
      req = stub_request SomeApp, "/"
      assert.same "http://localhost/hello", req\build_url "/hello"

    it "build_url respects host option", ->
      req = stub_request SomeApp, "/", host: "example.com"
      assert.same "http://example.com/hello", req\build_url "/hello"

    it "provides request method", ->
      req = stub_request SomeApp, "/", method: "PUT"
      assert.same "PUT", req.req.method

    it "provides parsed_url", ->
      req = stub_request SomeApp, "/test/path?foo=bar"
      assert.same "/test/path", req.req.parsed_url.path

    it "provides access to custom headers", ->
      req = stub_request SomeApp, "/", headers: {
        "X-Custom-Header": "custom-value"
        "Authorization": "Bearer token123"
      }
      assert.same "custom-value", req.req.headers["x_custom_header"]
      assert.same "Bearer token123", req.req.headers["authorization"]

    it "uses custom Request class when defined on app", ->
      import Request from require "lapis.application"

      class CustomRequest extends Request
        custom_method: => "custom value"

      class AppWithCustomRequest extends lapis.Application
        Request: CustomRequest
        [home: "/"]: =>

      req = stub_request AppWithCustomRequest, "/"
      assert.same CustomRequest, req.__class
      assert.same "custom value", req\custom_method!
