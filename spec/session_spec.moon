
-- without nginx the library uses crypto
unless pcall -> require "crypto"
  describe "lapis.session", ->
    it "should have luacrypto", ->
      pending "luacrypto is required for session test"
  return

session = require "lapis.session"

import auto_table from require "lapis.util"

describe "lapis.session", ->
  config = require"lapis.config".get!

  local req

  before_each ->
    config.secret = "the-secret"
    req = {
      cookies: {}
      session: setmetatable { hello: "world" }, {
        __index: { car: "engine" }
      }
    }

  it "should write unsigned session", ->
    config.secret = nil
    session.write_session req
    assert.same session.get_session(req), {
      hello: "world", car: "engine"
    }

  it "should not read unsigned session with secret", ->
    config.secret = nil
    session.write_session req
    config.secret = "hello"
    assert.same session.get_session(req), {}

  it "should write signed session", ->
    session.write_session req
    assert.same session.get_session(req), {
      hello: "world", car: "engine"
    }

  it "should not read incorrect secret", ->
    session.write_session req
    config.secret = "not-the-secret"
    assert.same session.get_session(req), {}

  it "should not fail on malformed session", ->
    req.cookies.lapis_session = "uhhhh"
    assert.same session.get_session(req), {}

  it "should write unloaded auto_table session", ->
    req.session = auto_table -> { hello: "world" }
    req.session.foo = "bar"
    session.write_session req
    assert.same session.get_session(req), { hello: "world", foo: "bar" }

