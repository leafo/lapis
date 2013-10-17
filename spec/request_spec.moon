
lapis = require "lapis"

import mock_request, mock_action from require "lapis.spec.request"

class App extends lapis.Application
  "/hello": =>

describe "application", ->
  it "should mock a request", ->
    assert.same 200, (mock_request App, "/hello")
    assert.same 500, (mock_request App, "/world")

class SessionApp extends lapis.Application
  layout: false

  "/set_session/:value": =>
    @session.hello = @params.value

  "/get_session": =>
    @session.hello

-- tests a series of requests
describe "session app", ->
  it "should set and read session", ->
    _, _, h = mock_request SessionApp, "/set_session/greetings"
    status, res = mock_request SessionApp, "/get_session", prev: h
    assert.same "greetings", res


describe "mock action", ->
  assert.same "hello", mock_action lapis.Application, "/hello", {}, ->
    "hello"

describe "cookies", ->
  class CookieApp extends lapis.Application
    layout: false
    "/": => @cookies.world = 34

    "/many": =>
      @cookies.world = 454545
      @cookies.cow = "one cool ;cookie"

  class CookieApp2 extends lapis.Application
    layout: false
    cookie_attributes: { "Domain=.leafo.net;" }
    "/": => @cookies.world = 34

  it "should write a cookie", ->
    _, _, h = mock_request CookieApp, "/"
    assert.same "world=34; Path=/; HttpOnly", h["Set-cookie"]

  it "should write multiple cookies", ->
    _, _, h = mock_request CookieApp, "/many"

    assert.same {
      'cow=one%20cool%20%3bcookie; Path=/; HttpOnly'
      'world=454545; Path=/; HttpOnly'
    }, h["Set-cookie"]

  it "should write a cookie with cookie attributes", ->
    _, _, h = mock_request CookieApp2, "/"
    assert.same "world=34; Path=/; HttpOnly; Domain=.leafo.net;", h["Set-cookie"]

