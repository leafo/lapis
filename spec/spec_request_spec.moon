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
