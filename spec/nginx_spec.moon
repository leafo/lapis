
ngx_stack = require "lapis.spec.stack"

describe "nginx.context", ->
  before_each ->
    package.loaded["lapis.nginx.context"] = nil
    ngx_stack.push { ctx: {} }

  after_each ->
    ngx_stack.pop!

  it "should add a callback", ->
    import after_dispatch from require "lapis.nginx.context"
    fn1 = -> 1
    fn2 = -> 1
    
    after_dispatch fn1
    assert.same { after_dispatch: fn1 }, ngx.ctx

    after_dispatch fn2
    assert.same { after_dispatch: {fn1, fn2} }, ngx.ctx
    
  it "should run no callbacks", ->
    import run_after_dispatch from require "lapis.nginx.context"
    run_after_dispatch!

  it "should run one callback", ->
    import run_after_dispatch, after_dispatch from require "lapis.nginx.context"

    local ran
    after_dispatch (a, b) ->
      assert.same "hello", a
      assert.same "world", b
      ran = true

    run_after_dispatch "hello", "world"

    assert.same true, ran

  it "should run multiple callbacks", ->
    import after_dispatch, run_after_dispatch from require "lapis.nginx.context"

    local first, second

    fn1 = (a, b) ->
      assert.same "hello", a
      assert.same "world", b
      first = true

    fn2 = (a, b) ->
      assert.same "hello", a
      assert.same "world", b
      second = true

    after_dispatch fn1
    after_dispatch fn2

    run_after_dispatch "hello", "world"

    assert.same true, first
    assert.same true, second
