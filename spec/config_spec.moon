
config = require "lapis.config"

_G.do_nothing = ->

describe "lapis.config", ->
  before_each ->
    config.reset true

  it "should create empty config", ->
    assert.same config.get"hello", { _name: "hello" }

  it "should create correct object", ->
    f = ->
      burly "dad"
      color "blue"

    config.config "basic", ->
      do_nothing!
      color "red"
      port 80

      things ->
        cool "yes"
        yes "really"

      include ->
        height "10px"

      set "not", "yeah"

      set many: "things", are: "set"

      include f

    input = config.get "basic"
    assert.same input, {
      _name: "basic"

      color: "blue"
      are: "set"
      burly: "dad"
      things: {
        yes: "really"
        cool: "yes"
      }
      not: "yeah"
      many: "things"
      height: "10px"
      port: 80
    }

  it "should create correct object", ->
    config.config "cool", ->
      hello {
        one: "thing"
        leads: "another"
        nest: {
          egg: true
          grass: true
        }
      }

      hello {
        dad: "son"
         nest: {
           bird: false
           grass: false
         }
      }

    input = config.get "cool"
    assert.same input, {
      _name: "cool"
      hello: {
        nest: {
          grass: false
          egg: true
          bird: false
        }
        dad: "son"
        one: "thing"
        leads: "another"
      }
    }

  it "should unset", ->
    config.config "yeah", ->
      hello "world"
      hello!

      one "two"
      three "four"

      unset "one", "four", "three"

    assert.same config.get"yeah", { _name: "yeah" }
