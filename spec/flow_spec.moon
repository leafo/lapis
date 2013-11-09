
import Flow from require "lapis.flow"

describe "lapis.flow", ->
  local base_object
  base_object = {
    msg: "hello"
    get_msg: => @msg

    check_base_object: =>
      assert.equal base_object, base_object
  }

  it "should create a flow", ->
    flow = Flow base_object, {
      cool: 10
      proxy_to_message: => @get_msg!
      raw_message: => @msg
      get_cool: => @cool

      check_self: (other) =>
        assert.same other, @
    }

    assert.same "hello", flow\get_msg!
    assert.same "hello", flow\proxy_to_message!
    assert.same "hello", flow\raw_message!
    assert.same "hello", flow.msg

    assert.same 10, flow\get_cool!
    assert.same 10, flow.cool

    flow\check_base_object!
    flow\check_self flow

  it "should create a flow with inheritance", ->
    class MyFlow extends Flow
      some_val: 999
      get_some_val: => @some_val
      proxy_to_message: => @get_msg!

      check_self: (other) =>
        assert.same other, @

    flow = MyFlow base_object

    assert.same "hello", flow\get_msg!
    assert.same "hello", flow\proxy_to_message!
    assert.same "hello", flow.msg

    assert.same 999, flow\get_some_val!
    assert.same 999, flow.some_val

    flow\check_base_object!
    flow\check_self flow


  it "should let flows inherit each other", ->
    class BaseFlow extends Flow
      the_data: 100
      the_method: =>
        @the_data

    class ChildFlow extends BaseFlow
      the_method: =>
        super! + 11

      proxy_to_message: => @get_msg!

    flow = ChildFlow base_object
    assert.same 111, flow\the_method!
    assert.same "hello", flow\proxy_to_message!
