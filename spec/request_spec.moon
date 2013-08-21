
lapis = require "lapis"

import mock_request from require "lapis.spec.request"

class App extends lapis.Application
  "/hello": =>

describe "application", ->
  it "should mock a request", ->
    assert.same 200, (mock_request App!, "/hello")
    assert.same 500, (mock_request App!, "/world")

