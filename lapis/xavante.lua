require("xavante")
require("xavante.filehandler")
local parse_query_string
do
  local _table_0 = require("lapis.util")
  parse_query_string = _table_0.parse_query_string
end
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
local wrap_dispatch
wrap_dispatch = function(dispatch)
  return function(req, res)
    req.params_get = parse_query_string(req.parsed_url.query or "") or { }
    req.params_post = { }
    return dispatch(req, res)
  end
end
return {
  make_server = make_server,
  wrap_dispatch = wrap_dispatch
}
