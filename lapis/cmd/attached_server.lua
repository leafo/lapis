local AttachedServer
do
  local _class_0
  local _base_0 = {
    start = function(self, env, env_overrides)
      return error("override me")
    end,
    detach = function(self)
      return error("override me")
    end,
    status_tick = function(self) end,
    wait_until = function(self, server_status)
      if server_status == nil then
        server_status = "open"
      end
      local socket = require("socket")
      local max_tries = 100
      local sleep_for = 0.001
      local start = socket.gettime()
      while true do
        self:status_tick()
        local sock = socket.connect("127.0.0.1", (assert(self.port, "missing port")))
        local _exp_0 = server_status
        if "open" == _exp_0 then
          if sock then
            sock:close()
            break
          end
        elseif "close" == _exp_0 then
          if sock then
            sock:close()
          else
            break
          end
        else
          error("don't know how to wait for " .. tostring(server_status))
        end
        max_tries = max_tries - 1
        if max_tries == 0 then
          error("Timed out waiting for server to " .. tostring(server_status) .. " (" .. tostring(socket.gettime() - start) .. ")")
        end
        socket.sleep(sleep_for)
        sleep_for = math.min(0.1, sleep_for * 2)
      end
    end,
    wait_until_ready = function(self)
      return self:wait_until("open")
    end,
    wait_until_closed = function(self)
      return self:wait_until("close")
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "AttachedServer"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  AttachedServer = _class_0
end
return {
  AttachedServer = AttachedServer
}
