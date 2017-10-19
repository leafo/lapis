
util = require "lapis.util"
json = require "cjson"

tests = {
  {
    -> util.parse_query_string "field1=value1&field2=value2&field3=value3"
    {
      {"field1", "value1"}
      {"field2", "value2"}
      {"field3", "value3"}
      field1: "value1"
      field2: "value2"
      field3: "value3"
    }
  }

  {
    -> util.parse_query_string "blahblah"
    {
      { "blahblah"}
      blahblah: true
    }
  }

  {
    -> util.parse_query_string "hello=wo%22rld&thing"
    {
      { "hello", 'wo"rld' }
      { "thing" }
      hello: 'wo"rld'
      thing: true
    }
  }


  {
    -> util.parse_query_string "hello=&thing=123&world="
    {
      {"hello", ""}
      {"thing", "123"}
      {"world", ""}

      hello: ""
      thing: "123"
      world: ""
    }
  }

  {
    -> util.parse_query_string "null"
    {
      {"null"}
      null: true
    }
  }

  {
    -> util.underscore "ManifestRocks"
    "manifest_rocks"
  }

  {
    -> util.underscore "ABTestPlatform"
    "abtest_platform"
  }

  {
    -> util.underscore "HELLO_WORLD"
    "" -- TODO: fix
  }

  {
    -> util.underscore "whats_up"
    "whats__up" -- TODO: fix
  }

  {
    -> util.camelize "hello"
    "Hello"
  }

  {
    -> util.camelize "world_wide_i_web"
    "WorldWideIWeb"
  }

  {
    -> util.camelize util.underscore "ManifestRocks"
    "ManifestRocks"
  }

  {
    ->
      util.encode_query_string {
        {"dad", "day"}
        "hello[hole]": "wor=ld"
      }

    "dad=day&hello%5bhole%5d=wor%3dld"
  }

  {
    ->
      util.encode_query_string {
        {"cold", "zone"}
        "hello": true
        "world": false
      }

    "cold=zone&hello"
  }

  {
    ->
      util.encode_query_string {
        "world": false
      }

    ""
  }

  {
    ->
      util.encode_query_string {
        "null": true
      }

    "null"
  }

  { -- stripping invalid types
    ->
      json.decode util.to_json {
        color: "blue"
        data: {
          height: 10
          fn: =>
        }
      }

    {
      color: "blue", data: { height: 10}
    }
  }

  { -- encoding null values
    ->
      util.to_json {
        nothing: json.null
      }

    '{"nothing":null}'
  }

  {
    ->
      util.build_url {
        path: "/test"
        scheme: "http"
        host: "localhost.com"
        port: "8080"
        fragment: "cool_thing"
        query: "dad=days"
      }
    "http://localhost.com:8080/test?dad=days#cool_thing"
  }

  {
    ->
      util.build_url {
        host: "dad.com"
        path: "/test"
        fragment: "cool_thing"
      }
    "//dad.com/test#cool_thing"
  }

  {
    ->
      util.build_url {
        scheme: ""
        host: "leafo.net"
      }
    "//leafo.net"
  }


  {
    -> util.time_ago os.time! - 34234349

    {
      {"years", 1}
      {"days", 31}
      {"hours", 5}
      {"minutes", 32}
      {"seconds", 29}
      years: 1
      days: 31
      hours: 5
      minutes: 32
      seconds: 29
    }
  }

  {
    -> util.time_ago os.time! + 34234349

    {
      {"years", 1}
      {"days", 31}
      {"hours", 5}
      {"minutes", 32}
      {"seconds", 29}
      years: 1
      days: 31
      hours: 5
      minutes: 32
      seconds: 29
    }
  }


  {
    -> util.time_ago_in_words os.time! - 34234349
    "1 year ago"
  }

  {
    -> util.time_ago_in_words os.time! - 34234349, 2
    "1 year, 31 days ago"
  }

  {
    -> util.time_ago_in_words os.time! - 34234349, 10
    "1 year, 31 days, 5 hours, 32 minutes, 29 seconds ago"

  }

  {
    -> util.time_ago_in_words os.time!
    "0 seconds ago"
  }

  {
      -> util.parse_cookie_string "__utma=54729783.634507326.1355638425.1366820216.1367111186.43; __utmc=54729783; __utmz=54729783.1364225235.36.12.utmcsr=t.co|utmccn=(referral)|utmcmd=referral|utmcct=/Q95kO2iEje; __utma=163024063.1111023767.1355638932.1367297108.1367341173.42; __utmb=163024063.1.10.1367341173; __utmc=163024063; __utmz=163024063.1366693549.37.11.utmcsr=t.co|utmccn=(referral)|utmcmd=referral|utmcct=/UYMGwvGJNo"

      {
        __utma: '163024063.1111023767.1355638932.1367297108.1367341173.42'
        __utmz: '163024063.1366693549.37.11.utmcsr=t.co|utmccn=(referral)|utmcmd=referral|utmcct=/UYMGwvGJNo'
        __utmb: '163024063.1.10.1367341173'
        __utmc: '163024063'
      }
  }

  {
    -> util.slugify "What is going on right now?"
    "what-is-going-on-right-now"
  }

  {
    -> util.slugify "whhaa  $%#$  hooo"
    "whhaa-hooo"
  }

  {
    -> util.slugify "what-about-now"
    "what-about-now"
  }

  {
    -> util.slugify "hello - me"
    "hello-me"
  }

  {
    -> util.slugify "cow _ dogs"
    "cow-dogs"
  }


  {
    -> util.uniquify { "hello", "hello", "world", "another", "world" }
    { "hello", "world", "another" }
  }

  {
    -> util.trim "what the    heck"
    "what the    heck"
  }

  {
    -> util.trim "
      blah blah          "
    "blah blah"
  }

  {
    -> util.trim "   hello#{" "\rep 20000}world "
    "hello#{" "\rep 20000}world"
  }

  {
    -> util.trim_filter {
      "     ", " thing ",
      yes: "    "
      okay: " no   "
    }

    { -- TODO: fix indexing?
      nil, "thing", okay: "no"
    }
  }

  {
    -> util.trim_filter {
      hello: " hi"
      world: " hi"
      yeah: "       "
    }, {"hello", "yeah"}, 0

    { hello: "hi", yeah: 0 }
  }


  {
    ->
      util.key_filter {
        hello: "world"
        foo: "bar"
      }, "hello", "yeah"

    { hello: "world" }
  }

  {
    -> "^%()[12332]+$"\match(util.escape_pattern "^%()[12332]+$") and true
    true
  }

  {
    -> util.title_case "hello"
    "Hello"
  }

  {
    -> util.title_case "hello world"
    "Hello World"
  }

  {
    -> util.title_case "hello-world"
    "Hello-world"
  }

  {
    -> util.title_case "What my 200 Dollar thing You love to eat"
    "What My 200 Dollar Thing You Love To Eat"
  }

}

describe "lapis.util", ->
  for group in *tests
    it "should match", ->
      input = group[1]!
      if #group > 2
        assert.one_of input, { unpack group, 2 }
      else
        assert.same input, group[2]

  it "should autoload", ->
    package.loaded["things.hello_world"] = "yeah"
    package.loaded["things.cool_thing"] = "cool"

    mod = util.autoload "things"
    assert.equal "yeah", mod.HelloWorld
    assert.equal "cool", mod.cool_thing

    assert.equal nil, mod.not_here
    assert.equal nil, mod.not_here

    assert.equal "cool", mod.cool_thing

  it "should autoload with starting table", ->
    package.loaded["things.hello_world"] = "yeah"
    package.loaded["things.cool_thing"] = "cool"

    mod = util.autoload "things", { dad: "world" }

    assert.equal "yeah", mod.HelloWorld
    assert.equal "cool", mod.cool_thing
    assert.equal "world", mod.dad

  it "should autoload with multiple prefixes", ->
    package.loaded["things.hello_world"] = "yeah"
    package.loaded["things.cool_thing"] = "cool"
    package.loaded["wings.cool_thing"] = "very cool"
    package.loaded["wings.hats"] = "off to you"

    mod = util.autoload "wings", "things"
    assert.equal "off to you", mod.hats
    assert.equal "very cool", mod.CoolThing
    assert.equal "yeah", mod.hello_world
    assert.equal "yeah", mod.HelloWorld

  it "should singularize words", ->
    words = {
      {"banks", "bank"}
      {"chemists", "chemist"}
      {"hospitals", "hospital"}
      {"letters", "letter"}

      {"vallys", "vally"}
      {"keys", "key"}

      {"industries", "industry"}
      {"ladies", "lady"}

      {"heroes", "hero"}
      {"torpedoes", "torpedo"}
      {"purchases", "purchase"}
      {"addresses", "address"}
      {"responses", "response"}

      -- these will never work
      -- {"halves", "half"}
      -- {"leaves", "leaf"}
      -- {"wives", "wife"}
    }

    for {plural, single} in *words
      assert.same single, util.singularize plural

describe "lapis.util.mixin", ->
  it "should mixin mixins", ->
    import insert from table
    log = {}

    class Mixin
      new: =>
        insert log, "initializing Mixin"
        @thing = { "hello" }

      pop: =>

      add_one: (num) =>
        insert log, "Before add_one (Mixin), #{num}"

    class Mixin2
      new: =>
        insert log, "initializing Mixin2"

      add_one: (num) =>
        insert log, "Before add_one (Mixin2), #{num}"

    class One
      util.mixin Mixin
      util.mixin Mixin2

      add_one: (num) =>
        num + 1

      new: =>
        insert log, "initializing One"

    o = One!
    assert.equal 13, o\add_one(12)
    assert.same {
      "initializing One"
      "initializing Mixin"
      "initializing Mixin2"
      "Before add_one (Mixin2), 12"
      "Before add_one (Mixin), 12"
    }, log


