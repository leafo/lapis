
import type, getmetatable, setmetatable from _G

-- a mediator for encapsulating logic between multiple models and a request
class Flow
  new: (@_req, obj={}) =>
    assert @_req, "flow missing request"
    proxy = setmetatable obj, getmetatable @

    setmetatable @, {
      __index: (key) =>
        val = proxy[key]
        return val if val != nil

        val = @_req[key]

        -- wrap the function to run in req context
        if type(val) == "function"
          val = (_, ...) -> @_req[key] @_req, ...
          @[key] = val

        val
    }

{ :Flow }
