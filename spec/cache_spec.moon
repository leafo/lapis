mock_shared = require "spec.mock_shared"
cache = require "lapis.cache"

r = {
  GET: {}
  res: {
    headers: {
      "Content-type": "text/html"
    }
  }

  req: {
    parsed_url: {
      path: "/hello"
    }
  }
}


describe "lapis.cache", ->
  setup ->
    mock_shared.setup!

  teardown ->
    mock_shared.teardown!

  it "should cache a page", ->
    counter = 0

    action = cache.cached =>
      counter += 1
      "hello #{counter}"

    action r



