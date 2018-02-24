
import auto_table from require "lapis.util"

session = require "lapis.session"

describe "lapis.session", ->
  config = require"lapis.config".get!

  local req

  before_each ->
    config.secret = "the-secret"
    req = {
      cookies: {}
    }

    req.session = session.lazy_session req

    -- seed the session with initial value and change
    rawset req.session, "hello", "world"
    getmetatable(req.session).__index = { car: "engine" }

  assert_session = (expected, expected_err) ->
    sess, err = session.get_session(req)
    assert.same expected_err, err
    assert.same expected, sess

  -- this is to make sure the session format doesn't accidentally change and break all sessions
  it "reads from the current session format", ->
    res = assert session.get_session {
      cookies: {
        lapis_session: [[eyJjYXIiOiJlbmdpbmUiLCJoZWxsbyI6IndvcmxkIn0=
--jXFBL3aIDxK/deWWpUeO92/ftEo=]]
      }
    }

    assert.same {
      car: "engine"
      hello: "world"
    }, res

  it "writes and reads unsigned session", ->
    config.secret = nil
    assert session.write_session req
    assert_session { hello: "world", car: "engine" }

    -- no signature in session
    assert.falsy (req.cookies[config.session_name]\match "\n%-%-")

  it "doesn't read unsigned session when expecting secret", ->
    config.secret = nil
    session.write_session req
    config.secret = "hello"
    assert_session nil, "session: invalid format"

  it "writes and reads signed session", ->
    session.write_session req
    assert_session {
      hello: "world", car: "engine"
    }

    -- signature in session
    assert.truthy (req.cookies[config.session_name]\match "\n%-%-")

  it "doesn't read signed session when there is no secret", ->
    session.write_session req
    config.secret = nil
    assert_session nil, "invalid session serialization"

  it "rejects incorrect secret", ->
    session.write_session req
    config.secret = "not-the-secret"
    assert_session nil, "session: invalid signature"

  it "rejects malformed signed session", ->
    req.cookies.lapis_session = "uhhhh"
    assert_session nil, "session: invalid format"

  it "rejects malformed unsigned session", ->
    config.secret = nil
    req.cookies.lapis_session = "Whoazz"
    assert_session nil, "invalid session serialization"

  describe "lazy_session", ->
    stub_lazy_session = (tbl) ->
      req.cookies[config.session_name] = session.encode_session tbl
      req.session = session.lazy_session req

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
      assert.same {nil, "session unchanged"}, {session.write_session req}

      assert.same req.cookies, {}

    it "should write a lazy_session with new keys", ->
      stub_lazy_session {
        cat: "man"
      }

      req.session.cow = 100
      session.write_session req
      assert_session {
       cat: "man", cow: 100
      }

    it "should remove key from lazy_session", ->
      stub_lazy_session {
        cat: "man"
        horse: "pig"
      }

      req.session.horse = nil
      session.write_session req
      assert_session {
        cat: "man"
      }

