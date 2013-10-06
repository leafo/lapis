
lapis = require "lapis"

import mock_request, mock_action from require "lapis.spec.request"

class App extends lapis.Application
  "/hello": =>

describe "application", ->
  it "should mock a request", ->
    assert.same 200, (mock_request App!, "/hello")
    assert.same 500, (mock_request App!, "/world")

class SessionApp extends lapis.Application
  layout: false

  "/set_session/:value": =>
    @session.hello = @params.value

  "/get_session": =>
    @session.hello

-- tests a series of requests
describe "session app", ->
  it "should set and read session", ->
    _, _, h = mock_request SessionApp!, "/set_session/greetings"
    status, res = mock_request SessionApp!, "/get_session", prev: h
    assert.same "greetings", res


describe "mock action", ->
  assert.same "hello", mock_action "/hello", {}, ->
    "hello"

