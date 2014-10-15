
import Parser, Compiler from require "etlua"

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

class EtluaWidget extends Widget
  @load: (code) =>
    lua_code, err = parser\compile_to_lua code, BufferCompiler
    fn, err = unless err
      parser\load lua_code

    return nil, err if err

    class TemplateWidget extends EtluaWidget
      _tpl_fn: fn


  _tpl_fn: nil -- set by superclass

  content_for: (name, val) =>
    if val
      super name, val
    else
      if val = @[name]
        @_buffer\write val
        ""

  _find_helper: (name) =>
    switch name
      when "render"
        return @_buffer\render
      when "widget"
        return @_buffer\render_widget

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

    old_widget = @_buffer.widget
    @_buffer.widget = @

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

    clone = locked_fn @_tpl_fn
    parser\run clone, scope, @_buffer
    release_fn clone

    @_buffer.widget = old_widget
    nil

{ :EtluaWidget, :BufferCompiler }
