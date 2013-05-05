
-- without nginx the library uses crypto
unless pcall -> require "crypto"
  describe "lapis.session", ->
    it "should have luacrypto", ->
      pending "luacrypto is required for session test"
  return

session = require "lapis.session"

describe "lapis.session", ->
  local req

  before_each ->
    session.set_secret "the-secret"
    req = {
      cookies: {}
      session: setmetatable { hello: "world" }, {
        __index: { car: "engine" }
      }
    }

  it "should write unsigned session", ->
    session.set_secret nil
    session.write_session req
    assert.same session.get_session(req), {
      hello: "world", car: "engine"
    }

  it "should not read unsigned session with secret", ->
    session.set_secret nil
    session.write_session req
    session.set_secret "hello"
    assert.same session.get_session(req), {}

  it "should write signed session", ->
    session.write_session req
    assert.same session.get_session(req), {
      hello: "world", car: "engine"
    }

  it "should not read incorrect secret", ->
    session.write_session req
    session.set_secret "not-the-secret"
    assert.same session.get_session(req), {}

  it "should not fail on malformed session", ->
    req.cookies.lapis_session = "uhhhh"
    assert.same session.get_session(req), {}

