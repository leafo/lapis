-- functions that interact with the request's context
import insert from table

DEFAULT_PERFORMANCE_KEY = "performance"

make_callback = (name) ->
  add = (callback) ->
    current = ngx.ctx[name]
    t = type current
    switch t
      when "nil"
        ngx.ctx[name] = callback
      when "function"
        ngx.ctx[name] = { current, callback }
      when "table"
        insert current, callback

  run = (...) ->
    callbacks = ngx.ctx[name]
    switch type callbacks
      when "table"
        for fn in *callbacks
          fn ...
      when "function"
        callbacks ...

  add, run

after_dispatch, run_after_dispatch = make_callback "after_dispatch"

-- for performance tracking
increment_perf = (key, amount, parent=DEFAULT_PERFORMANCE_KEY) ->
  return unless ngx and ngx.ctx

  p = ngx.ctx[parent]
  unless p
    p = {}
    ngx.ctx[parent] = p

  if old = p[key]
    p[key] = old + amount
  else
    p[key] = amount

set_perf = (key, value, parent=DEFAULT_PERFORMANCE_KEY) ->
  return unless ngx and ngx.ctx

  p = ngx.ctx[parent]
  unless p
    p = {}
    ngx.ctx[parent] = p

  p[key] = value


{
  :after_dispatch, :run_after_dispatch, :increment_perf, :set_perf
}
