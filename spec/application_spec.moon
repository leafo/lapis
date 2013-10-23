
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
    assert.same "application_json", headers["Content-type"]
