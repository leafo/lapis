
-- without nginx the library uses crypto
unless pcall -> require "crypto"
  describe "lapis.session", ->
    it "should have luacrypto", ->
      pending "luacrypto is required for session test"
  return

import auto_table from require "lapis.util"

session = require "lapis.session"

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


  stub_lazy_session = (tbl) ->
    req.cookies[config.session_name] = session.encode_session tbl
    req.session = session.lazy_session req

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

  it "should load a lazy_session", ->
    stub_lazy_session {
      hello: "world"
      dog: { height: 10 }
    }

    assert.same req.session.hello, "world"
    assert.same req.session.dog, { height: 10 }

  it "should write not write an unchanged lazy_session", ->
    stub_lazy_session {
      cat: "man"
    }

    assert.same req.session.cat, "man"

    req.cookies = {} -- clear cookies to see if we write new session cookie
    session.write_session req

    assert.same req.cookies, {}

  it "should write a lazy_session with new keys", ->
    stub_lazy_session {
      cat: "man"
    }

    req.session.cow = 100
    session.write_session req
    assert.same session.get_session(req), { cat: "man", cow: 100 }

  it "should remove key from lazy_session", ->
    stub_lazy_session {
      cat: "man"
      horse: "pig"
    }

    req.session.horse = nil
    session.write_session req
    assert.same session.get_session(req), { cat: "man" }

