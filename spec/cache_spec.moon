lapis = require "lapis"

mock_shared = require "lapis.spec.shared"
import mock_request from require "lapis.spec.request"
import cached from require "lapis.cache"


describe "lapis.cache", ->
  before_each -> mock_shared.setup!
  after_each -> mock_shared.teardown!

  it "should cache a page", ->
    counter = 0

    class App extends lapis.Application
      "/hello": cached =>
        counter += 1
        "hello #{counter}"

    status, first_body, first_headers = mock_request App!, "/hello"
    assert.same 200, status

    status, second_body, second_headers = mock_request App!, "/hello"
    assert.same 200, status

    assert.same first_body, second_body


