local to_json
to_json = require("lapis.util").to_json
local AttachedServer
AttachedServer = require("lapis.cmd.attached_server").AttachedServer
local CqueuesAttachedServer
do
  local _class_0
  local _parent_0 = AttachedServer
  local _base_0 = {
    start = function(self, env, overrides)
      local thread = require("cqueues.thread")
      self.port = overrides and overrides.port or require("lapis.config").get(env).port
      self.current_thread, self.thread_socket = assert(thread.start(function(sock, env, overrides)
        local from_json
        from_json = require("lapis.util").from_json
        local push, pop
        do
          local _obj_0 = require("lapis.environment")
          push, pop = _obj_0.push, _obj_0.pop
        end
        local start_server
        start_server = require("lapis.cmd.cqueues").start_server
        overrides = from_json(overrides)
        if not (next(overrides)) then
          overrides = nil
        end
        push(env, overrides)
        local config = require("lapis.config").get()
        local app_module = config.app_class or "app"
        return start_server(app_module)
      end, env, to_json(overrides or { })))
      return self:wait_until_ready()
    end,
    status_tick = function(self)
      local joined, err = self.current_thread:join(0)
      if joined then
        return error("Failed to start test server: " .. tostring(err))
      end
    end,
    detach = function(self) end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "CqueuesAttachedServer",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil then
        local parent = rawget(cls, "__parent")
        if parent then
          return parent[name]
        end
      else
        return val
      end
    end,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  CqueuesAttachedServer = _class_0
end
return {
  AttachedServer = CqueuesAttachedServer
}
