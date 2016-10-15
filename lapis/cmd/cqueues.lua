local start_server
start_server = function(app)
  local config = require("lapis.config").get()
  local http_server = require("http.server")
  local dispatch
  dispatch = require("lapis.cqueues").dispatch
  local server = http_server.listen({
    host = "127.0.0.1",
    port = assert(config.port, "missing server port"),
    onstream = function(self, stream)
      return dispatch(app, self, stream)
    end,
    onerror = function(self, context, op, err, errno)
      local msg = op .. " on " .. tostring(context) .. " failed"
      if err then
        msg = msg .. ": " .. tostring(err)
      end
      return assert(io.stderr:write(msg, "\n"))
    end
  })
  local bound_port = select(3, server:localname())
  print("Listening on " .. tostring(bound_port) .. "\n")
  return assert(server:loop())
end
return {
  type = "cqueues",
  start_server = start_server
}
