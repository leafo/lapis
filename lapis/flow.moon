
import type, getmetatable, setmetatable, rawset from _G

-- a mediator for encapsulating logic between multiple models and a request
class Flow
  expose_assigns: false

  new: (@_req, obj={}) =>
    assert @_req, "flow missing request"
    proxy = setmetatable obj, getmetatable @

    mt = {
      __index: (key) =>
        val = proxy[key]
        return val if val != nil

        val = @_req[key]

        -- wrap the function to run in req context
        if type(val) == "function"
          val = (_, ...) -> @_req[key] @_req, ...
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
            @_req[key] = val
          else
            rawset @, key, val
        else
          @_req[key] = val

    setmetatable @, mt


{ :Flow }
