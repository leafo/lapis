
etlua = require "etlua"
loadkit = require "loadkit"

import Widget from require "lapis.html"
import locked_fn, release_fn from require "lapis.util.functions"

loadkit.register "etlua", (file) ->
  fn = assert etlua.compile file\read "*a"

  class TemplateWidget extends Widget
    render: (buffer) =>
      seen_helpers = {}
      scope = setmetatable {}, {
        __index: (scope, key) ->
          if not seen_helpers[key]
            helper_value = @_find_helper key
            seen_helpers[key] = true
            if helper_value != nil
              scope[key] = helper_value
              return helper_value
      }

      table.insert buffer, fn scope

(app) -> -- nothing to do

