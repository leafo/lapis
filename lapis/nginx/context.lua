local insert
insert = table.insert
local DEFAULT_AFTER_DISPATCH_KEY = "after_dispatch"
local DEFAULT_PERFORMANCE_KEY = "performance"
local make_callback
make_callback = function(name)
  local running = false
  local add
  add = function(callback)
    if running then
      error("you tried add to " .. tostring(name) .. " while running a callback")
    end
    local current = ngx.ctx[name]
    local _exp_0 = type(current)
    if "nil" == _exp_0 then
      ngx.ctx[name] = callback
    elseif "function" == _exp_0 then
      ngx.ctx[name] = {
        current,
        callback
      }
    elseif "table" == _exp_0 then
      return insert(current, callback)
    end
  end
  local run
  run = function(...)
    running = true
    local callbacks = ngx.ctx[name]
    ngx.ctx[name] = nil
    local _exp_0 = type(callbacks)
    if "table" == _exp_0 then
      for _index_0 = 1, #callbacks do
        local fn = callbacks[_index_0]
        fn(...)
      end
    elseif "function" == _exp_0 then
      callbacks(...)
    end
    running = false
  end
  return add, run
end
local make_counter
make_counter = function(name)
  local increment
  increment = function(key, amount)
    if not (ngx and ngx.ctx) then
      return 
    end
    local p = ngx.ctx[name]
    if not (p) then
      p = { }
      ngx.ctx[name] = p
    end
    do
      local old = p[key]
      if old then
        p[key] = old + amount
      else
        p[key] = amount
      end
    end
  end
  local set
  set = function(key, value)
    if not (ngx and ngx.ctx) then
      return 
    end
    local p = ngx.ctx[name]
    if not (p) then
      p = { }
      ngx.ctx[name] = p
    end
    p[key] = value
  end
  return increment, set
end
local after_dispatch, run_after_dispatch = make_callback(DEFAULT_AFTER_DISPATCH_KEY)
local increment_perf, set_perf = make_counter(DEFAULT_PERFORMANCE_KEY)
return {
  after_dispatch = after_dispatch,
  run_after_dispatch = run_after_dispatch,
  increment_perf = increment_perf,
  set_perf = set_perf
}
