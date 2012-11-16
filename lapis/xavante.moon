
require "xavante"
require "xavante.filehandler"

import parse_query_string from require "lapis.util"

make_server = (port, handler) ->
  xavante.HTTP {
    server: { host: "*", port: tonumber port },
    defaultHost: {
      rules: {
        {
          match: ".",
          with: handler -- req, res
        }
      }
    }
  }

  xavante

wrap_dispatch = (dispatch) ->
  (req, res) ->
    req.params_get = parse_query_string(req.parsed_url.query or "") or {}
    req.params_post = {} -- TODO: add POST support
    dispatch req, res

{ :make_server, :wrap_dispatch }

