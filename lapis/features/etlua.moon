
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

    render: (buffer) =>
      seen_helpers = {}
      scope = setmetatable { self: @ }, {
        __index: (scope, key) ->
          if not seen_helpers[key]
            helper_value = @_find_helper key
            seen_helpers[key] = true
            if helper_value != nil
              scope[key] = helper_value
              return helper_value
      }


      clone = locked_fn fn
      parser\run clone, scope, buffer
      release_fn clone
      nil

