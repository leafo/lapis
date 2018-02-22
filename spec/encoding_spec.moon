encoding = require "lapis.util.encoding"

describe "lapis.util.encoding", ->
  config = require"lapis.config".get!

  before_each ->
    config.secret = "the-secret"

  it "should encode message", ->
    encoded = encoding.encode_with_secret { color: "red" }
    input = encoding.decode_with_secret encoded
    assert.same input, { color: "red" }

  it "should encode message", ->
    encoded = encoding.encode_with_secret { color: "red" }
    input = encoding.decode_with_secret encoded
    assert.same input, { color: "red" }

  it "should not decode with incorrect secret", ->
    encoded = encoding.encode_with_secret { color: "red" }
    config.secret = "not-the-secret"
    assert.same { encoding.decode_with_secret encoded }, {nil, "invalid signature"}


  it "should fail on invalid string", ->
    assert.same {encoding.decode_with_secret "hello"},
      {nil, "invalid format"}

    assert.same {encoding.decode_with_secret "hello.world"},
      {nil, "invalid signature"}


