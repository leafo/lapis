
import Router from require "lapis.router"

describe "basic route matching", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route "/hello", handler
    r\add_route "/hello/:name", handler
    r\add_route "/hello/:name/world", handler
    r\add_route "/static/*", handler
    r\add_route "/x/:color/:height/*", handler

    r.default_route = -> "failed to find route"

  it "should match static route", ->
    out = r\resolve "/hello"
    assert.same out, { {}, "/hello" }

  it "should match param route", ->
    out = r\resolve "/hello/world2323"
    assert.same out, {
      { name: "world2323" },
      "/hello/:name"
    }

  it "should match param route", ->
    out = r\resolve "/hello/the-parameter/world"
    assert.same out, {
      { name: "the-parameter" },
      "/hello/:name/world"
    }

  it "should match splat", ->
    out = r\resolve "/static/hello/world/343434/foo%20bar.png"
    assert.same out, {
      { splat: 'hello/world/343434/foo%20bar.png' }
      "/static/*"
    }

  it "should match all", ->
    out = r\resolve "/x/greenthing/123px/ahhhhwwwhwhh.txt"
    assert.same out, {
      {
        splat: 'ahhhhwwwhwhh.txt'
        height: '123px'
        color: 'greenthing'
      }
      "/x/:color/:height/*"
    }

  it "should match nothing", ->
    assert.same r\resolve("/what-the-heck"), "failed to find route"

  it "should match nothing", ->
    assert.same r\resolve("/hello//world"), "failed to find route"


