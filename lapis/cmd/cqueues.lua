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
  local original_path = package.path
  local original_cpath = package.cpath
  local original_searchers = package.searchers
  local original_loaders = package.loaders
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
    package.path = original_path
    package.cpath = original_cpath
    package.searchers = original_searchers
    package.loaders = original_loaders
    return true, count
  end
end
local Runner
do
  local _class_0
  local _base_0 = {
    attach_server = function(self, env, overrides)
      overrides = overrides or { }
      overrides.logging = false
      assert(not self.current_server, "there's already a server thread")
      local AttachedServer
      AttachedServer = require("lapis.cmd.cqueues.attached_server").AttachedServer
      local server = AttachedServer()
      server:start(env, overrides)
      self.current_server = server
      return self.current_server
    end,
    detach_server = function(self)
      return assert(self.current_server, "no current server")
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Runner"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Runner = _class_0
end
local Server
do
  local _class_0
  local _base_0 = {
    stop = function(self)
      assert(self.server, "No running server")
      self.server:close()
      self.server = nil
    end,
    start = function(self)
      local http_server = require("http.server")
      self.server = http_server.listen(self.server_opts)
      io.stdout:setvbuf("no")
      io.stderr:setvbuf("no")
      local logger = require("lapis.logging")
      local port = select(3, assert(self.server:localname()))
      logger.start_server(port, self.config and self.config._name)
      package.loaded["lapis.running_server"] = "cqueues"
      assert(self.server:loop())
      package.loaded["lapis.running_server"] = nil
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, server_opts, config)
      self.server_opts, self.config = server_opts, config
    end,
    __base = _base_0,
    __name = "Server"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Server = _class_0
end
local create_server
create_server = function(app_module, environment)
  if environment then
    require("lapis.environment").push(environment)
  end
  local config = require("lapis.config").get()
  local dispatch, protected_call
  do
    local _obj_0 = require("lapis.cqueues")
    dispatch, protected_call = _obj_0.dispatch, _obj_0.protected_call
  end
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
  local _exp_0 = config.code_cache
  if false == _exp_0 or "off" == _exp_0 then
    local reset = module_reset()
    onstream = function(self, stream)
      reset()
      local app
      if protected_call(stream, function()
        app = load_app()
      end) then
        return dispatch(app, self, stream)
      end
    end
  elseif "app_only" == _exp_0 then
    onstream = function(self, stream)
      stream:get_headers()
      local app
      if protected_call(stream, function()
        app = load_app()
      end) then
        app = load_app()
      end
      return dispatch(app, self, stream)
    end
  else
    local app = load_app()
    onstream = function(self, stream)
      return dispatch(app, self, stream)
    end
  end
  local onerror
  onerror = function(self, context, op, err, errno)
    local msg = op .. " on " .. tostring(context) .. " failed"
    if err then
      msg = msg .. ": " .. tostring(err)
    end
    return assert(io.stderr:write(msg, "\n"))
  end
  return Server({
    host = config.bind_host or "0.0.0.0",
    port = assert(config.port, "missing server port"),
    onstream = onstream,
    onerror = onerror
  }, config)
end
local start_server
start_server = function(...)
  local server = create_server(...)
  return server:start()
end
return {
  type = "cqueues",
  create_server = create_server,
  start_server = start_server,
  runner = Runner()
}
