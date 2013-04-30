
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
    -> util.slugify "what-about-now"
    "what-about-now"
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
}

describe "lapis.nginx.postgres", ->
  for group in *tests
    it "should match", ->
      input = group[1]!
      if #group > 2
        assert.one_of input, { unpack group, 2 }
      else
        assert.same input, group[2]




