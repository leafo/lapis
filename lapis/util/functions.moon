
import next, debug, string, setmetatable, rawget from _G

loadstring = loadstring or load

clone_function = if debug.upvaluejoin
  (fn) ->
    dumped = string.dump fn
    cloned = loadstring(dumped)

    i = 1
    while true
      name = debug.getupvalue(fn, i)
      break unless name
      debug.upvaluejoin(cloned, i, fn, i)
      i += 1

    cloned

else
  (fn) ->
    dumped = string.dump fn
    cloned = loadstring(dumped)

    i = 1
    while true
      name, val = debug.getupvalue(fn, i)
      break unless name
      debug.setupvalue(cloned, i, val)
      i += 1

    cloned

locks = setmetatable {}, {
  __mode: "k"
  __index: (name) =>
    list = setmetatable {}, { __mode: "k" }
    @[name] = list
    list
}

locked_fn = (fn) ->
  -- look for existing lock
  list = locks[fn]
  clone = next list
  if clone
    list[clone] = nil
    clone
  else
    with c = clone_function fn
      locks[c] = fn

release_fn = (fn) ->
  list = locks[rawget locks, fn]
  list[fn] = true
  true

{ :clone_function, :locked_fn, :release_fn, _locks: locks }
