local next, debug, string, setmetatable, rawget
do
  local _obj_0 = _G
  next, debug, string, setmetatable, rawget = _obj_0.next, _obj_0.debug, _obj_0.string, _obj_0.setmetatable, _obj_0.rawget
end
local loadstring = loadstring or load
local clone_function
if debug.upvaluejoin then
  clone_function = function(fn)
    local dumped = string.dump(fn)
    local cloned = loadstring(dumped)
    local i = 1
    while true do
      local name = debug.getupvalue(fn, i)
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
    local list = setmetatable({ }, {
      __mode = "k"
    })
    self[name] = list
    return list
  end
})
local locked_fn
locked_fn = function(fn)
  local list = locks[fn]
  local clone = next(list)
  if clone then
    list[clone] = nil
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
  list[fn] = true
  return true
end
return {
  clone_function = clone_function,
  locked_fn = locked_fn,
  release_fn = release_fn,
  _locks = locks
}
