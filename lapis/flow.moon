
import type, getmetatable, setmetatable, rawset, rawget from _G

local Flow

is_flow = (cls) ->
  return false unless cls
  return true if cls == Flow
  is_flow cls.__parent

MEMO_KEY = setmetatable {}, __tostring: -> "::memo_key::"

-- cache the result of a method after first invocation. Arguments for
-- subsequent calls are ignored
memo = (fn) ->
  (...) =>
    cache = rawget @, MEMO_KEY

    unless cache
      cache = {}
      rawset @, MEMO_KEY, cache

    unless cache[fn]
      cache[fn] = {fn @, ...}

    unpack cache[fn]

-- A flow is a object that forwards all methods and property access that don't
-- exist on the flow to the wrapped object. This allows you to encapsulate
-- functionality within the scope of the Flow class
class Flow
  expose_assigns: false

  @extend: (name, tbl) =>
    lua = require "lapis.lua"

    if type(name) == "table"
      tbl = name
      name = nil

    class_fields = { }

    cls = lua.class name or "ExtendedFlow", tbl, @
    cls, cls.__base

  new: (@_, obj={}) =>
    assert @_, "missing flow target"
    @_req = @_ -- TODO: for legacy flows

    -- get the real request if the object passed is another flow
    if is_flow @_.__class
      @_ = @_._

    old_mt = getmetatable @
    proxy = setmetatable obj, old_mt

    mt = {
      __call: old_mt.__call
      __index: (key) =>
        val = proxy[key]
        return val if val != nil

        val = @_[key]

        -- wrap the function to run in req context
        if type(val) == "function"
          val = (_, ...) -> @_[key] @_, ...
          rawset @, key, val

        val
    }

    if expose = @expose_assigns
      local allowed_assigns
      if type(expose) == "table"
        allowed_assigns = {name, true for name in *expose}

      mt.__newindex = (key, val) =>
        if allowed_assigns
          if allowed_assigns[key]
            @_[key] = val
          else
            rawset @, key, val
        else
          @_[key] = val

    setmetatable @, mt


{ :Flow, :is_flow, :MEMO_KEY, :memo }
