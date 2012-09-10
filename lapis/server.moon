
require "xavante"
require "xavante.filehandler"

module "lapis.server", package.seeall

export make_server = (port, handler) ->
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

export make_static_handler = (root) ->
  handler = xavante.filehandler root
  =>
    import req, res from @
    req.relpath = @params.splat
    handler req, res, root
    layout: false


export serve_from_static = (root="static") ->
  handler = make_static_handler root
  =>
    @params.splat = @req.relpath
    handler @


