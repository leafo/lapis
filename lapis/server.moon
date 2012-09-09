
require "xavante"

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

