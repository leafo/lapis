-- functions that interact with the request's context
import insert from table

DEFAULT_AFTER_DISPATCH_KEY = "after_dispatch"
DEFAULT_PERFORMANCE_KEY = "performance"

-- this stores a list of callbacks functions stored in the ngx.ctx
-- and provides a method to call them
make_callback = (name) ->
  running = false

  add = (callback) ->
    if running
      error "you tried add to #{name} while running a callback"

    current = ngx.ctx[name]
    switch type current
      when "nil"
        ngx.ctx[name] = callback
      when "function"
        ngx.ctx[name] = { current, callback }
      when "table"
        insert current, callback

  run = (...) ->
    running = true
    callbacks = ngx.ctx[name]

    -- clear out callbacks so they can't be double triggered
    ngx.ctx[name] = nil

    switch type callbacks
      when "table"
        for fn in *callbacks
          fn ...
      when "function"
        callbacks ...

    running = false

  add, run


-- creates increment and set functions for a named counter
make_counter = (name) ->
  increment = (key, amount) ->
    return unless ngx and ngx.ctx

    p = ngx.ctx[name]
    unless p
      p = {}
      ngx.ctx[name] = p

    if old = p[key]
      p[key] = old + amount
    else
      p[key] = amount

  set = (key, value) ->
    return unless ngx and ngx.ctx

    p = ngx.ctx[name]
    unless p
      p = {}
      ngx.ctx[name] = p

    p[key] = value

  increment, set

-- after_dispatch is called after the request processing is completed
-- this is typically used for cleaning up of resources opened during the
-- request or relinquishing sockets back to the socket pool
after_dispatch, run_after_dispatch = make_callback DEFAULT_AFTER_DISPATCH_KEY

-- for performance tracking
increment_perf, set_perf = make_counter DEFAULT_PERFORMANCE_KEY

{
  :after_dispatch, :run_after_dispatch, :increment_perf, :set_perf
}
