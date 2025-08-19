
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

  describe "increment_perf", ->
    it "should increment a new key", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "requests", 1
      assert.same { performance: { requests: 1 } }, ngx.ctx

    it "should increment an existing key", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "requests", 5
      increment_perf "requests", 3
      assert.same { performance: { requests: 8 } }, ngx.ctx

    it "should handle multiple counters", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "requests", 2
      increment_perf "errors", 1
      increment_perf "requests", 3
      assert.same { performance: { requests: 5, errors: 1 } }, ngx.ctx

    it "should handle negative increments", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "counter", 10
      increment_perf "counter", -3
      assert.same { performance: { counter: 7 } }, ngx.ctx

    it "should handle zero increments", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "counter", 5
      increment_perf "counter", 0
      assert.same { performance: { counter: 5 } }, ngx.ctx

    it "should handle decimal increments", ->
      import increment_perf from require "lapis.nginx.context"
      increment_perf "time", 1.5
      increment_perf "time", 2.3
      assert.same { performance: { time: 3.8 } }, ngx.ctx

  describe "set_perf", ->
    it "should set a new key", ->
      import set_perf from require "lapis.nginx.context"
      set_perf "response_time", 150
      assert.same { performance: { response_time: 150 } }, ngx.ctx

    it "should overwrite an existing key", ->
      import set_perf from require "lapis.nginx.context"
      set_perf "response_time", 100
      set_perf "response_time", 200
      assert.same { performance: { response_time: 200 } }, ngx.ctx

    it "should handle multiple performance keys", ->
      import set_perf from require "lapis.nginx.context"
      set_perf "response_time", 150
      set_perf "memory_usage", 1024
      set_perf "cpu_usage", 0.75
      assert.same { performance: { response_time: 150, memory_usage: 1024, cpu_usage: 0.75 } }, ngx.ctx

    it "should handle other types", ->
      import set_perf from require "lapis.nginx.context"

      set_perf "status", "success"
      set_perf "optional_field", nil
      set_perf "cache_hit", true
      set_perf "error_occurred", false

      assert.same {
        performance: {
          status: "success",
          cache_hit: true
          error_occurred: false
        }
      }, ngx.ctx

  describe "perf functions interaction", ->
    it "should allow set_perf to overwrite increment_perf results", ->
      import increment_perf, set_perf from require "lapis.nginx.context"
      increment_perf "counter", 10
      set_perf "counter", 25
      assert.same { performance: { counter: 25 } }, ngx.ctx

    it "should allow increment_perf to modify set_perf results", ->
      import increment_perf, set_perf from require "lapis.nginx.context"
      set_perf "counter", 20
      increment_perf "counter", 5
      assert.same { performance: { counter: 25 } }, ngx.ctx
