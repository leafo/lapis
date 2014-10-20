
describe "lapis.http", ->
  local location, options

  before_each ->
    stack = require "lapis.spec.stack"
    stack.push {
      HTTP_GET: 1
      HTTP_POST: 2
      HTTP_PUT: 2

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

