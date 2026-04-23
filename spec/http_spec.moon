
describe "lapis.http", ->
  local location, options
  local original_resty_http

  before_each ->
    original_resty_http = package.loaded["resty.http"]

    stack = require "lapis.spec.stack"
    stack.push {
      HTTP_GET: 1
      HTTP_POST: 2
      HTTP_PUT: 2

      get_phase: -> "content"

      location: {
        capture: (_location, _options) ->
          location = _location
          options = _options
          {}
      }
    }

  after_each ->
    stack = require "lapis.spec.stack"
    stack.pop!
    package.loaded["resty.http"] = original_resty_http

  describe "simple", ->
    local simple
    before_each ->
      simple = require("lapis.http").simple

    it "should call with string", ->
      simple "http://leafo.net"

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_GET
        ctx: {}
        vars: {
          _url: "http://leafo.net/"
        }
      }, options

    it "should call table", ->
      simple {
        url: "http://leafo.net/lapis"
      }

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_GET
        ctx: {}
        vars: {
          _url: "http://leafo.net/lapis"
        }
      }, options


    it "should call with body", ->
      simple "http://leafo.net", "gold coins"

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_POST
        body: "gold coins"
        ctx: {}
        vars: {
          _url: "http://leafo.net/"
        }
      }, options


    it "should encode form", ->
      simple "http://leafo.net/lapis", {
        color: "blue's"
      }

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_POST
        body: "color=blue%27s"
        ctx: {
          headers: {
            "Content-type": "application/x-www-form-urlencoded"
          }
        }
        vars: {
          _url: "http://leafo.net/lapis"
        }
      }, options


    it "should set method and body", ->
      simple {
        url: "http://leafo.net/lapis"
        method: "PUT"
        body: "yeah"
      }

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_PUT
        body: "yeah"
        ctx: { }
        vars: { _url: "http://leafo.net/lapis" }
      }, options


  describe "request", ->
    local request
    before_each ->
      request = require("lapis.http").request

    it "should call with string", ->
      request "http://leafo.net"

      assert.same "/proxy", location
      assert.same {
        method: ngx.HTTP_GET
        ctx: {}
        vars: {
          _url: "http://leafo.net/"
        }
      }, options

    it "should set content length for timer post body", ->
      local resty_options

      package.loaded["resty.http"] = {
        new: ->
          {
            request_uri: (_, _url, _options) ->
              resty_options = _options
              {
                body: "ok"
                status: 200
                headers: {}
              }
          }
      }

      ngx.get_phase = -> "timer"

      body, status = request "http://leafo.net", "gold coins"

      assert.same "ok", body
      assert.same 200, status
      assert.same "application/x-www-form-urlencoded", resty_options.headers["Content-type"]
      assert.same 10, resty_options.headers["Content-Length"]
      assert.same "function", type resty_options.body
