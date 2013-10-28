
functions = require "lapis.util.functions"

moon = require "moon"

describe "lapis.util.functions", ->
  upvalue = "hello"
  fn = -> "the upvalue #{upvalue}"
  other_fn = -> "what up, upvalue #{upvalue}"

  it "should run the function", ->
    clone = functions.locked_fn fn
    assert.are_not.equal fn, clone
    assert.same fn!, clone!
    functions.release_fn clone

  it "should reuse a clone", ->
    clone = functions.locked_fn fn
    functions.release_fn clone
    second_clone = functions.locked_fn fn
    assert.same clone, second_clone


  it "should make multiple clones", ->
    clone_1 = functions.locked_fn fn
    clone_2 = functions.locked_fn fn

    assert.are_not.equal clone_1, clone_2
    assert.same fn!, clone_1!
    assert.same fn!, clone_2!

    functions.release_fn clone_1
    functions.release_fn clone_2


  it "should run two functions", ->
    clone = functions.locked_fn fn
    other_clone = functions.locked_fn other_fn

    assert.same fn!, clone!
    assert.same other_fn!, other_clone!

    functions.release_fn other_clone
    functions.release_fn clone

