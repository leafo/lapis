
import runner from require "lapis.cmd.cqueues"

import SpecServer from require "lapis.spec.server"
server = SpecServer runner

version = require "lapis.version"

describe "server", ->
  setup ->
    server\load_test_server {
      app_class: "spec_cqueues.s1.app"
    }

  teardown ->
    server\close_test_server!

  it "should request basic page", ->
    status, res, headers = server\request "/"
    assert.same 200, status
    assert.same [[<!DOCTYPE HTML><html lang="en"><head><title>Lapis Page</title></head><body>Welcome to Lapis ]] .. version .. [[</body></html>]], res

    assert.same {
      content_type: "text/html"
      connection: "close"
    }, headers

  it "should request json page", ->
    status, res, headers = server\request "/world", {
      expect: "json"
    }

    assert.same 200, status
    assert.same { success: true }, res

    assert.same {
      content_type: "application/json"
      connection: "close"
    }, headers

  describe "params", ->
    it "dumps query params", ->
      status, res, headers = server\request "/dump-params?color=blue&color=green&height[oops]=9", {
        expect: "json"
      }

      assert.same 200, status
      assert.same {
        color: "green"
        height: {
          oops: "9"
        }
      }, res

    it "dumps post params", ->
      status, res, headers = server\request "/dump-params", {
        expect: "json"
        post: {
          color: "blue"
          "height[oops]": "9"
        }
      }

      assert.same 200, status
      assert.same {
        color: "blue"
        height: {
          oops: "9"
        }
      }, res

    it "dumps json params", ->
      status, res, headers = server\request "/dump-params", {
        expect: "json"
        method: "POST"
        headers: {
          "content-type": "application/json"
        }
        data: '{"thing": 1234}'
      }

      assert.same 200, status
      -- this route isn't json aware
      assert.same {}, res

      status, res, headers = server\request "/dump-json-params", {
        expect: "json"
        method: "POST"
        headers: {
          "content-type": "application/json"
        }
        data: '{"thing": 1234}'
      }

      assert.same {
        thing: 1234
      }, res


  describe "csrf", ->
    import escape from require "lapis.util"
    import decode_with_secret from require "lapis.util.encoding"

    it "should get a csrf token", ->
      import parse_cookie_string from require "lapis.util"

      status, res, headers = server\request "/form", {
        expect: "json"
      }

      assert.same 200, status
      assert.truthy res.csrf_token
      assert.truthy headers.set_cookie
      cookies = parse_cookie_string headers.set_cookie
      assert.truthy cookies.lapis_session_token

    it "should get a csrf token from existing token", ->
      random_text = "hello world"

      status, res, headers = server\request "/form", {
        expect: "json"
        headers: {
          "Cookie": "lapis_session_token=#{escape random_text}"
        }
      }

      token = res.csrf_token
      assert.same {
        k: "hello world"
      }, decode_with_secret token

    it "rejects missing csrf token", ->
      random_text = "hello world"

      status, res, headers = server\request "/form", {
        expect: "json"
        post: { }
        headers: {
          "Cookie": "lapis_session_token=#{escape random_text}"
        }
      }

      assert.same {
        errors: {
          "missing csrf token"
        }
      }, res

    it "rejects invalid csrf token", ->
      random_text = "hello world"

      status, res, headers = server\request "/form", {
        expect: "json"
        post: {
          csrf_token: "hello world"
        }
        headers: {
          "Cookie": "lapis_session_token=#{escape random_text}"
        }
      }

      assert.same {
        errors: {
          "csrf: invalid format"
        }
      }, res

      csrf = require "lapis.csrf"
      token = csrf.generate_token { cookies: {} }

      status, res, headers = server\request "/form", {
        expect: "json"
        post: {
          csrf_token: token
        }
        headers: {
          "Cookie": "lapis_session_token=#{escape random_text}"
        }
      }

      assert.same {
        errors: {
          "csrf: token mismatch"
        }
      }, res

    it "accepts csrf token", ->
      status, res, headers = server\request "/form", {
        expect: "json"
        headers: {}
      }

      import parse_cookie_string from require "lapis.util"
      cookies = parse_cookie_string headers.set_cookie

      status, res, headers = server\request "/form", {
        expect: "json"
        post: {
          csrf_token: res.csrf_token
        }
        headers: {
          "Cookie": "lapis_session_token=#{escape cookies.lapis_session_token}"
        }
      }

      assert.same {success: true}, res
      assert.nil res.headers



