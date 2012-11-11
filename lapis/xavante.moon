
require "xavante"
require "xavante.filehandler"

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

{ :make_server }

