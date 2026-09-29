import flatten_params from require "lapis.logging"

describe "lapis.logging", ->
  describe "flatten_params", ->
    it "flattens nil", ->
      assert.same "{}", flatten_params nil

    it "flattens empty table", ->
      assert.same "{  }", flatten_params {}

    it "flattens values", ->
      assert.same '{ a: "hello" }', flatten_params { a: "hello" }
      assert.same '{ a: "5" }', flatten_params { a: 5 }
      assert.same '{ a: true }', flatten_params { a: true }

    it "flattens nested tables", ->
      assert.same '{ a: { b: { c: "d" } } }', flatten_params {
        a: { b: { c: "d" } }
      }

    it "truncates deeply nested tables", ->
      assert.same '{ a: { a: { a: { a: { a: { ... } } } } } }', flatten_params {
        a: { a: { a: { a: { a: { a: "deep" } } } } }
      }

    it "truncates recursive tables", ->
      t = {}
      t.a = t
      assert.same '{ a: { a: { a: { a: { a: { ... } } } } } }', flatten_params t
