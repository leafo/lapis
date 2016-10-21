local start_server
start_server = function(app_module)
  local config = require("lapis.config").get()
  local http_server = require("http.server")
  local dispatch
  dispatch = require("lapis.cqueues").dispatch
  local load_app
  load_app = function()
    local app_cls
    if type(app_module) == "string" then
      app_cls = require(app_module)
    else
      app_cls = app_module
    end
    if app_cls.__base then
      return app_cls()
    else
      app_cls:build_router()
      return app_cls
    end
  end
  local onstream
  if config.code_cache == false or config.code_cache == "off" then
    onstream = error("not yet")
  else
    local app = load_app()
    onstream = function(self, stream)
      return dispatch(app, self, stream)
    end
  end
  local server = http_server.listen({
    host = "127.0.0.1",
    port = assert(config.port, "missing server port"),
    onstream = onstream,
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
