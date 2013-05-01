
-- without nginx the library uses crypto
return unless pcall -> require "crypto"

encoding = require "lapis.util.encoding"

describe "lapis.util.encoding", ->
  before_each ->
    require"lapis.session".set_secret "the-secret"

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
    require"lapis.session".set_secret "not-the-secret"
    assert.same { encoding.decode_with_secret encoded }, {nil, "invalid message secret"}


  it "should fail on invalid string", ->
    assert.same {encoding.decode_with_secret "hello"},
      {nil, "invalid message"}

    assert.same {encoding.decode_with_secret "hello.world"},
      {nil, "invalid message secret"}


