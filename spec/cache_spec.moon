lapis = require "lapis"

mock_shared = require "lapis.spec.shared"
import assert_request from require "lapis.spec.request"

cache = require "lapis.cache"
import cached from cache

describe "lapis.cache", ->
  before_each -> mock_shared.setup!
  after_each -> mock_shared.teardown!

  describe "cache_key", ->
    it "hadles empty params", ->
      import cache_key from require "lapis.cache"
      assert.same "/#", cache_key "/", {}

    it "hadles params", ->
      import cache_key from require "lapis.cache"
      assert.same "/site#hello:world-one:two-three:four", cache_key "/site", {
        one: "two"
        three: "four"
        "hello": "world"
      }

    it "hadles boolean params", ->
      import cache_key from require "lapis.cache"
      assert.same "/site#good:cat-other:false-thing:true", cache_key "/site", {
        thing: true
        other: false
        "good": "cat"
      }

    it "hadles nested params", ->
      import cache_key from require "lapis.cache"
      assert.same "/site#age:1:one-2:two-thing:true", cache_key "/site", {
        age: {
          "one"
          "two"
        }
        thing: true
      }

  it "caches a page", ->
    counter = 0

    class App extends lapis.Application
      "/hello": cached =>
        @title = "yeah"
        counter += 1
        "hello #{counter}"

    _, first_body = assert_request App!, "/hello"
    _, second_body = assert_request App!, "/hello"
    _, third_body = assert_request App!, "/hello"

    assert.same [[<!DOCTYPE HTML><html lang="en"><head><title>yeah</title></head><body>hello 1</body></html>]],
      first_body, second_body, third_body

    assert.same 1, counter

  it "skips cache with when", ->
    count = 0

    class App extends lapis.Application
      layout: false

      "/hoi": cached {
        when: => false
        =>
          count += 1
          "hello #{count}"
      }

    for i=1,3
      _, body = assert_request App!, "/hoi"
      assert.same "hello #{i}", body

  it "skips cache non non-get", ->
    count = 0

    class App extends lapis.Application
      layout: false

      "/hoi": cached {
        when: => false
        =>
          count += 1
          "hello #{count}"
      }

    for i=1,3
      _, body = assert_request App!, "/hoi", {
        method: "POST"
      }
      assert.same "hello #{i}", body

  it "caches a page based on params", ->
    counters = setmetatable {}, __index: => 0

    class App extends lapis.Application
      layout: false

      "/sure": cached =>
        counters.sure += 1
        "howdy doody"

      "/hello": cached =>
        counters[@params.counter_key] += 1
        "hello #{counters[@params.counter_key]}"


    _, a_body = assert_request App!, "/hello?counter_key=one&yes=dog"
    _, b_body = assert_request App!, "/hello?yes=dog&counter_key=one"
    assert.same a_body, b_body

    assert_request App!, "/hello?yes=dog&counter_key=two"

    assert.same counters, { one: 1, two: 1 }

    assert_request App!, "/sure"
    assert_request App!, "/sure"

    assert.same counters, { one: 1, two: 1, sure: 1}

    cache.delete_path "/hello"

    assert_request App!, "/hello?counter_key=one&yes=dog"
    assert_request App!, "/hello?yes=dog&counter_key=two"
    assert_request App!, "/sure"

    assert.same counters, { one: 2, two: 2, sure: 1}

    cache.delete_all!

    assert_request App!, "/hello?counter_key=one&yes=dog"
    assert_request App!, "/hello?yes=dog&counter_key=two"
    assert_request App!, "/sure"

    assert.same counters, { one: 3, two: 3, sure: 2}



