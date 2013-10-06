
lapis = require "lapis"

import mock_action from require "lapis.spec.request"

describe "request:build_url", ->
  it "should build url", ->
    assert.same "http://localhost", mock_action "/hello", {}, =>
      @build_url!

  it "should build url with path", ->
    assert.same "http://localhost/hello_dog", mock_action "/hello", {}, =>
      @build_url "hello_dog"

  it "should build url with host and port", ->
    assert.same "http://leaf:2000/hello",
      mock_action "/hello", { host: "leaf", port: 2000 }, =>
        @build_url @req.parsed_url.path

  it "should build url with overridden query", ->
    assert.same "http://localhost/please?yes=no",
      mock_action "/hello", {}, =>
        @build_url "please?okay=world", { query: "yes=no" }

  it "should build url with overridden port and host", ->
    assert.same "http://yes:4545/cat?sure=dad",
      mock_action "/hello", { host: "leaf", port: 2000 }, =>
        @build_url "cat?sure=dad", host: "yes", port: 4545

  it "should return arg if already build url", ->
    assert.same "http://leafo.net",
      mock_action "/hello", { host: "leaf", port: 2000 }, =>
        @build_url "http://leafo.net"
