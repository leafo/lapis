
import Router, RouteParser from require "lapis.router"

build_router = (routes) ->
  handler = (...) -> { ... }
  with r = Router!
    for pattern in *routes
      r\add_route pattern, handler
    r.default_route = -> "failed to find route"

describe "with router", ->
  local r
  handler = (...) -> { ... }

  describe "basic router", ->
    before_each ->
      r = build_router {
        "/hello"
        "/hello/:name[%d]"
        "/hello/:name"
        "/hello/:name/world"
        "/static/*"
        "/x/:color/:height/*"
        "/please/"
      }

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
    r = build_router {"*"}

    assert.same {
      { splat: "hello_world" }
      "*"
    }, r\resolve "hello_world"

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

  before_each ->
    r = build_router {
      { homepage: "/home" }
      { profile: "/profile/:name" }
      { profile_settings: "/profile/:name/settings" }
      { game: "/game/:user_slug/:game_slug" }
      { splatted: "/page/:slug/*" }
    }

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

  describe "basic router", ->
    before_each ->
      r = build_router {
        "/test(/:game)"
        "/zone(/:game(/:user)(*))"
        "/test/me"
      }

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

describe "route precedence", ->
  local r

  before_each ->
    r = build_router {
      "/*"
      "/:slug"
      "/hello"
    }

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
    r = build_router {
      "/*"
      "/:slug1"
      "/:slug2"
      "/:slug3"
      "/:slug4"
      "/:slug5"
      "/hello"
    }

    out = r\resolve "/hey"
    assert.same { { slug1: "hey" }, "/:slug1" }, out

  it "more specific takes precedence", ->
    pending "todo"
    r = build_router {
      "/test/:game"
      "/test/:game-world"
    }

    out = r\resolve "/test/hello-world"
    assert.same { { game: "hello" }, "/test/:game-world" }, out

  it "non-optional takes precedence", ->
    pending "todo"
    r = build_router {
      "/test(/:game)"
      "/test/:game"
    }

    out = r\resolve "/test/thing"
    assert.same { { game: "thing" }, "/test/:game" }, out



