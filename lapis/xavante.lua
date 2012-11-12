require("xavante")
require("xavante.filehandler")
local make_server
make_server = function(port, handler)
  xavante.HTTP({
    server = {
      host = "*",
      port = tonumber(port)
    },
    defaultHost = {
      rules = {
        {
          match = ".",
          with = handler
        }
      }
    }
  })
  return xavante
end
return {
  make_server = make_server
}
