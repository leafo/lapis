
import Parser from require "etlua"
loadkit = require "loadkit"

import Widget, Buffer from require "lapis.html"
import locked_fn, release_fn from require "lapis.util.functions"

parser = Parser!

loadkit.register "etlua", (file, mod, fname) ->
  lua_code, err = parser\compile_to_lua file\read "*a"
  fn, err = unless err
    parser\load lua_code

  if err
    error "[#{fname}] #{err}"

  class TemplateWidget extends Widget
    content_for: (name, val) =>
      if val
        super name, val
      else
        if val = @[name]
          buffer = Buffer {}
          buffer\write val
          table.concat buffer.buffer

    _find_helper: (name) =>
      if chain = @_get_helper_chain!
        for h in *chain
          helper_val = h[name]
          if helper_val != nil
            -- call functions in scope of helper
            value = if type(helper_val) == "function"
              (...) -> helper_val h, ...
            else
              helper_val

            return value

      -- look on self
      val = @[name]
      if val != nil
        real_value = if type(val) == "function"
          (...) -> val @, ...
        else
          val

        return real_value

    render: (buffer) =>
      seen_helpers = {}
      scope = setmetatable { }, {
        __index: (scope, key) ->
          if not seen_helpers[key]
            seen_helpers[key] = true
            helper_value = @_find_helper key
            if helper_value != nil
              scope[key] = helper_value
              return helper_value
      }


      clone = locked_fn fn
      parser\run clone, scope, buffer
      release_fn clone
      nil

