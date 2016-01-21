
import Router, RouteParser from require "lapis.router"

describe "basic route matching", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route "/hello", handler
    r\add_route "/hello/:name[%d]", handler
    r\add_route "/hello/:name", handler
    r\add_route "/hello/:name/world", handler
    r\add_route "/static/*", handler
    r\add_route "/x/:color/:height/*", handler
    r\add_route "/please/", handler

    r.default_route = -> "failed to find route"

  it "should match static route", ->
    out = r\resolve "/hello"
    assert.same { {}, "/hello" }, out

  it "should match character class route", ->
    out = r\resolve "/hello/234"
    assert.same { { name: "234" }, "/hello/:name[%d]" }, out

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

  it "should match trailing exactly", ->
    assert.same {
      {}
      "/please/"
    }, r\resolve("/please/")

    assert.same "failed to find route", r\resolve("/please")

  it "should match the catchall", ->
    r = Router!
    r\add_route "*", handler
    assert.same {
      { splat: "hello_world" }
      "*"
    }, r\resolve "hello_world"

  it "should match splat with trailing literal", ->
    router = Router!
    router\add_route "/*/hello"
    router\build!

    assert.same {
      {
        splat: "one/two"
      }
      nil
      "/*/hello"
    }, {router.p\match "/one/two/hello"}


  it "should match var with trailing literal", ->
    router = Router!
    router\add_route "/hi/:one-:two"
    router\build!

    assert.same {
      {
        one: "blah"
        two: "blorgbeef-fe"
      }
      nil
      "/hi/:one-:two"
    }, {router.p\match "/hi/blah-blorgbeef-fe"}

describe "character classes", ->
  local r, g
  before_each ->
    r = RouteParser!
    g = r\build_grammar!

  it "it matches %d", ->
    p = g\match("/:hello[%d]") * -1

    assert.same nil, (p\match "/what")
    assert.same nil, (p\match "/")
    assert.same { hello: "1223"}, (p\match "/1223")
    assert.same { hello: "1"}, (p\match "/1")

  it "it matches %a", ->
    p = g\match("/:world[%a]") * -1

    assert.same { world: "what" }, (p\match "/what")
    assert.same nil, (p\match "/1223")
    assert.same nil, (p\match "/1")

  it "it matches %w", ->
    p = g\match("/:lee[%w]") * -1

    assert.same { lee: "what" }, (p\match "/what")
    assert.same { lee: "999" }, (p\match "/999")
    assert.same { lee: "aj23" }, (p\match "/aj23")

    assert.same nil, (p\match "/2lll__")
    assert.same nil, (p\match "/")

  it "it matches range", ->
    p = g\match("/:ben[a-f]") * -1
    assert.same nil, (p\match "/what")
    assert.same { ben: "abf" }, (p\match "/abf")

  it "it matches literal characters", ->
    p = g\match("/:andy[12fg]") * -1
    assert.same nil, (p\match "/what")
    assert.same { andy: "12" }, (p\match "/12")
    assert.same { andy: "f2" }, (p\match "/f2")


  it "it matches combination characters", ->
    p = g\match("/:dap[a%dd-g]") * -1
    assert.same nil, (p\match "/what")
    assert.same { dap: "a3" }, (p\match "/a3")
    assert.same { dap: "9a99f" }, (p\match "/9a99f")


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

  it "should generate correct url", ->
    url = r\url_for "splatted", slug: "cool", splat: "hello"
    assert.same "/page/cool/hello", url

  it "should generate url with query string as table", ->
    url = r\url_for "profile", { name: "adam" }, hello: "world"
    assert.same "/profile/adam?hello=world", url

  it "should generate url with query string as value", ->
    url = r\url_for "profile", { name: "adam" }, "required"
    assert.same "/profile/adam?required", url

  it "generates url with empty query params", ->
    url = r\url_for "profile", { name: "adam" }, {}
    assert.same "/profile/adam", url

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

describe "optional parts", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route "/test(/:game)", handler
    r\add_route "/zone(/:game(/:user)(*))", handler
    r\add_route "/test/me", handler

    r.default_route = -> "failed to find route"

  it "matches without optional", ->
    out = r\resolve "/test/yeah"
    assert.same { {game: "yeah"}, "/test(/:game)" }, out

  it "matches with optional part", ->
    out = r\resolve "/test/ozone"
    assert.same { {game: "ozone"}, "/test(/:game)" }, out

  it "fails to find", ->
    out = r\resolve "/test/ozone/"
    assert.same "failed to find route", out

  it "lets literal route take precedence", ->
    out = r\resolve "/test/me"
    assert.same { {}, "/test/me" }, out

  it "matches without any optionals", ->
    out = r\resolve "/zone"
    assert.same { {}, "/zone(/:game(/:user)(*))" }, out

  it "matches with one optional", ->
    out = r\resolve "/zone/drone"
    assert.same { { game: "drone"}, "/zone(/:game(/:user)(*))" }, out

  it "matches with two optional", ->
    out = r\resolve "/zone/drone/leafo"
    assert.same { { game: "drone", user: "leafo" }, "/zone(/:game(/:user)(*))" }, out

  it "matches with three optional", ->
    out = r\resolve "/zone/drone/leafo/here"
    assert.same {
      { game: "drone", user: "leafo", splat: "/here" }
      "/zone(/:game(/:user)(*))"
    }, out


describe "route precedence", ->
  local r
  handler = (...) -> { ... }

  before_each ->
    r = Router!
    r\add_route "/*", handler
    r\add_route "/:slug", handler
    r\add_route "/hello", handler

    r.default_route = -> "failed to find route"

  it "matches literal route first", ->
    out = r\resolve "/hello"
    assert.same { {}, "/hello" }, out

  it "matches var route second", ->
    out = r\resolve "/world"
    assert.same { {slug: "world"}, "/:slug" }, out

  it "matches slug last", ->
    out = r\resolve "/whoa/zone"
    assert.same { { splat: "whoa/zone" }, "/*" }, out

  it "preserves declare order among routes with same precedence", ->
    r = Router!
    r\add_route "/*", handler

    for i=1,20
      r\add_route "/:slug#{i}", handler

    r\add_route "/hello", handler

    out = r\resolve "/hey"
    assert.same { { slug1: "hey" }, "/:slug1" }, out

  it "more specific takes precedence", ->
    pending "todo"
    r = Router!
    r\add_route "/test/:game", handler
    r\add_route "/test/:game-world", handler

    out = r\resolve "/test/hello-world"
    assert.same { { game: "hello" }, "/test/:game-world" }, out

  it "non-optional takes precedence", ->
    pending "todo"
    r = Router!
    r\add_route "/test(/:game)", handler
    r\add_route "/test/:game", handler

    out = r\resolve "/test/thing"
    assert.same { { game: "thing" }, "/test/:game" }, out



