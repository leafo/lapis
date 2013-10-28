local clone_function
if debug.upvaluejoin then
  clone_function = function(fn)
    local dumped = string.dump(fn)
    local cloned = loadstring(dumped)
    local i = 1
    while true do
      local name, val = debug.getupvalue(fn, i)
      if not (name) then
        break
      end
      debug.upvaluejoin(cloned, i, fn, i)
      i = i + 1
    end
    return cloned
  end
else
  clone_function = function(fn)
    local dumped = string.dump(fn)
    local cloned = loadstring(dumped)
    local i = 1
    while true do
      local name, val = debug.getupvalue(fn, i)
      if not (name) then
        break
      end
      debug.setupvalue(cloned, i, val)
      i = i + 1
    end
    return cloned
  end
end
local locks = setmetatable({ }, {
  __mode = "k",
  __index = function(self, name)
    local val = {
      len = 0
    }
    self[name] = val
    return val
  end
})
local locked_fn
locked_fn = function(fn)
  local list = locks[fn]
  local clone = list[list.len]
  if clone then
    list[list.len] = nil
    list.len = list.len - 1
    return clone
  else
    do
      local c = clone_function(fn)
      locks[c] = fn
      return c
    end
  end
end
local release_fn
release_fn = function(fn)
  local list = locks[rawget(locks, fn)]
  list.len = list.len + 1
  list[list.len] = fn
  return true
end
return {
  clone_function = clone_function,
  locked_fn = locked_fn,
  release_fn = release_fn,
  _locks = locks
}
