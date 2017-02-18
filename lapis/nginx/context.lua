local insert
insert = table.insert
local DEFAULT_PERFORMANCE_KEY = "performance"
local make_callback
make_callback = function(name)
  local add
  add = function(callback)
    local current = ngx.ctx[name]
    local t = type(current)
    local _exp_0 = t
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
    local callbacks = ngx.ctx[name]
    local _exp_0 = type(callbacks)
    if "table" == _exp_0 then
      for _index_0 = 1, #callbacks do
        local fn = callbacks[_index_0]
        fn(...)
      end
    elseif "function" == _exp_0 then
      return callbacks(...)
    end
  end
  return add, run
end
local after_dispatch, run_after_dispatch = make_callback("after_dispatch")
local increment_perf
increment_perf = function(key, amount, parent)
  if parent == nil then
    parent = DEFAULT_PERFORMANCE_KEY
  end
  if not (ngx and ngx.ctx) then
    return 
  end
  local p = ngx.ctx[parent]
  if not (p) then
    p = { }
    ngx.ctx[parent] = p
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
local set_perf
set_perf = function(key, value, parent)
  if parent == nil then
    parent = DEFAULT_PERFORMANCE_KEY
  end
  if not (ngx and ngx.ctx) then
    return 
  end
  local p = ngx.ctx[parent]
  if not (p) then
    p = { }
    ngx.ctx[parent] = p
  end
  p[key] = value
end
return {
  after_dispatch = after_dispatch,
  run_after_dispatch = run_after_dispatch,
  increment_perf = increment_perf,
  set_perf = set_perf
}
