
import mock_request from require "lapis.spec.request"

-- class Application
--   "/hello": =>

describe "application", ->
  it "should mock a request", ->
    res = mock_request {
      dispatch: (req, res) ->
        ngx.say "hi"
    }, "/hello"

    assert.same "hi\n", res

