
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
    assert.same { {}, "/hello" }, out

  it "should match param route", ->
    out = r\resolve "/hello/world2323"
    assert.same {
      { name: "world2323" },
      "/hello/:name"
    }, out

  it "should match param route", ->
    out = r\resolve "/hello/the-parameter/world"
    assert.same {
      { name: "the-parameter" },
      "/hello/:name/world"
    }, out

  it "should match splat", ->
    out = r\resolve "/static/hello/world/343434/foo%20bar.png"
    assert.same {
      { splat: 'hello/world/343434/foo%20bar.png' }
      "/static/*"
    }, out

  it "should match all", ->
    out = r\resolve "/x/greenthing/123px/ahhhhwwwhwhh.txt"
    assert.same {
      {
        splat: 'ahhhhwwwhwhh.txt'
        height: '123px'
        color: 'greenthing'
      }
      "/x/:color/:height/*"
    }, out

  it "should match nothing", ->
    assert.same "failed to find route", r\resolve("/what-the-heck")

  it "should match nothing", ->
    assert.same "failed to find route", r\resolve("/hello//world")

  it "should match the catchall", ->
    r = Router!
    r\add_route "*", handler
    assert.same {
      { splat: "hello_world" }
      "*"
    }, r\resolve "hello_world"

describe "named routes", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route { homepage: "/home" }, handler
    r\add_route { profile: "/profile/:name" }, handler
    r\add_route { profile_settings: "/profile/:name/settings" }, handler
    r\add_route { game: "/game/:user_slug/:game_slug" }, handler
    r\add_route { splatted: "/page/:slug/*" }, handler

    r.default_route = -> "failed to find route"

  it "should match", ->
    out = r\resolve "/home"
    assert.same {
      {}, "/home", "homepage"
    }, out

  it "should generate correct url", ->
    url = r\url_for "homepage"
    assert.same "/home", url

  it "should generate correct url", ->
    url = r\url_for "profile", name: "adam"
    assert.same "/profile/adam", url

  it "should generate correct url", ->
    url = r\url_for "game", user_slug: "leafo", game_slug: "x-moon"
    assert.same "/game/leafo/x-moon", url

  -- TODO: this is incorrect
  it "should generate correct url", ->
    url = r\url_for "splatted", slug: "cool", splat: "hello"
    assert.same "/page/cool/*", url

  it "should create param from object", ->
    user = {
      url_key: (route_name, param_name) =>
        assert.same "profile_settings", route_name
        assert.same "name", param_name
        "adam"
    }

    url = r\url_for "profile_settings", name: user
    assert.same "/profile/adam/settings", url

  it "should not build url", ->
    assert.has_error (-> r\url_for "fake_url", name: user),
      "Missing route named fake_url"

