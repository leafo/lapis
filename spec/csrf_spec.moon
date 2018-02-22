csrf = require "lapis.csrf"
import encode_with_secret, decode_with_secret from require "lapis.util.encoding"

describe "lapis.csrf", ->
  config = require"lapis.config".get!

  before_each ->
    config.secret = "the-secret"

  describe "generate_token", ->
    it "generates fresh token", ->
      r = {
        cookies: {}
      }
      t = csrf.generate_token r
      assert.truthy t
      assert.truthy r.cookies.lapis_session_token

      out = decode_with_secret t
      assert.same {
        k: r.cookies.lapis_session_token
      }, out

    it "generates fresh token with payload", ->
      r = {
        cookies: {}
      }
      t = csrf.generate_token r, {
        color: "blue"
      }
      assert.truthy t
      assert.truthy t
      assert.truthy r.cookies.lapis_session_token

      out = decode_with_secret t
      assert.same {
        d: {
          color: "blue"
        }
        k: r.cookies["lapis_session_token"]
      }, out

    it "re-uses token stored in cookie", ->
      r = {
        cookies: {
          lapis_session_token: "hello world"
        }
      }
      t = csrf.generate_token r

      assert.truthy t
      assert.same "hello world", r.cookies.lapis_session_token

      assert.same {
        k: "hello world"
      }, decode_with_secret t

    it "re-uses token stored in cookie with payload", ->
      r = {
        cookies: {
          lapis_session_token: "hello world"
        }
      }
      t = csrf.generate_token r, {
        color: "blue"
      }

      assert.truthy t
      assert.same "hello world", r.cookies.lapis_session_token

      assert.same {
        d: {
          color: "blue"
        }
        k: "hello world"
      }, decode_with_secret t


  describe "validate_token", ->
    it "fails validation when param is missing", ->
      assert.same {
        nil, "missing csrf token"
      }, {
        csrf.validate_token {
          cookies: {
            lapis_session_token: "blahblah"
          }
          params: { }
        }
      }

    it "fails validation when cookie isn't set", ->
      assert.same {
        nil
        "csrf: missing token cookie"
      },{
        csrf.validate_token {
          cookies: { }
          params: {
            csrf_token: "testtoeknthing"
          }
        }
      }

    it "fails validation for invalid signed token", ->
      r = { cookies: {} }
      token = csrf.generate_token r

      assert.same {
        nil
        "csrf: invalid format"
      },{
        csrf.validate_token {
          cookies: r.cookies
          params: {
            csrf_token: "this is wrong"
          }
        }
      }

    it "fails validation for cookie mismatch", ->
      r = { cookies: {} }
      token = csrf.generate_token r

      assert.same {
        nil
        "csrf: token mismatch"
      },{
        csrf.validate_token {
          cookies: {
            lapis_session_token: "random bytes"
          }
          params: {
            csrf_token: token
          }
        }
      }

    it "validates token", ->
      r = { cookies: {} }
      token = csrf.generate_token r, {
        color: "blue"
      }

      assert csrf.validate_token {
        cookies: r.cookies
        params: {
          csrf_token: token
        }
      }

    it "fails validation when token callback fails", ->
      r = { cookies: {} }
      token = csrf.generate_token r, { number: 5 }

      assert.same {
        nil
        "csrf: is not right"
      },{
        csrf.validate_token {
          cookies: r.cookies
          params: {
            csrf_token: token
          }
        }, (d) ->
          assert.same {
            number: 5
          }, d
          nil, "is not right"
      }

      -- with no error messag
      assert.same {
        nil
        "csrf: failed check"
      },{
        csrf.validate_token {
          cookies: r.cookies
          params: {
            csrf_token: token
          }
        }, (d) -> nil
      }

    it "valides token with callback", ->
      r = { cookies: {} }
      token = csrf.generate_token r, { number: 5 }

      assert csrf.validate_token {
        cookies: r.cookies
        params: {
          csrf_token: token
        }
      }, (d) -> d.number == 5
