
import Parser, Compiler from require "etlua"
loadkit = require "loadkit"

import Widget, Buffer from require "lapis.html"
import locked_fn, release_fn from require "lapis.util.functions"

parser = Parser!

class BufferCompiler extends Compiler
  header: =>
    @push "local _tostring, _escape, _b = ...\n",
      "local _b_buffer = _b.buffer\n",
      "local _b_i\n"

  increment: =>
    @push "_b_i = _b.i + 1\n"
    @push "_b.i = _b_i\n"

  assign: (...) =>
    @push "_b_buffer[_b_i] = ", ...
    @push "\n" if ...

loadkit.register "etlua", (file, mod, fname) ->
  lua_code, err = parser\compile_to_lua file\read("*a"), BufferCompiler
  print lua_code

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
          @_buffer\write val
          ""

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
      @_buffer = if buffer.__class == Buffer
        buffer
      else
        Buffer buffer

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
      parser\run clone, scope, @_buffer
      require("moon").p @_buffer
      release_fn clone
      nil

