local module_reset
module_reset = function()
  local keep
  do
    local _tbl_0 = { }
    for k in pairs(package.loaded) do
      _tbl_0[k] = true
    end
    keep = _tbl_0
  end
  return function()
    local count = 0
    local _list_0
    do
      local _accum_0 = { }
      local _len_0 = 1
      for k in pairs(package.loaded) do
        if not keep[k] then
          _accum_0[_len_0] = k
          _len_0 = _len_0 + 1
        end
      end
      _list_0 = _accum_0
    end
    for _index_0 = 1, #_list_0 do
      local mod = _list_0[_index_0]
      count = count + 1
      package.loaded[mod] = nil
    end
    return true, count
  end
end
local start_server
start_server = function(app_module)
  local config = require("lapis.config").get()
  local http_server = require("http.server")
  local dispatch
  dispatch = require("lapis.cqueues").dispatch
  package.loaded["lapis.running_server"] = "cqueues"
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
    local reset = module_reset()
    onstream = function(self, stream)
      reset()
      local app = load_app()
      return dispatch(app, self, stream)
    end
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
  assert(server:loop())
  package.loaded["lapis.running_server"] = nil
end
return {
  type = "cqueues",
  start_server = start_server
}
