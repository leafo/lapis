
import type, getmetatable, setmetatable, rawset from _G

local Flow

is_flow = (cls) ->
  return false unless cls
  return true if cls == Flow
  is_flow cls.__parent

-- a mediator for encapsulating logic between multiple models and a request
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


{ :Flow, :is_flow }
