local config = require('lapis.config')
local path = require("lapis.cmd.path")
local leda
local Leda
do
  local _class_0
  local _base_0 = {
    paths = {
      "/usr/local/bin",
      "/usr/bin"
    },
    find_bin = function(self)
      if self.bin then
        return self.bin
      end
      local bin = "leda"
      local paths
      do
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = self.paths
        for _index_0 = 1, #_list_0 do
          local p = _list_0[_index_0]
          _accum_0[_len_0] = p
          _len_0 = _len_0 + 1
        end
        paths = _accum_0
      end
      table.insert(paths, os.getenv("LAPIS_LEDA"))
      for _index_0 = 1, #paths do
        local to_check = paths[_index_0]
        to_check = to_check .. "/" .. tostring(bin)
        if path.exists(to_check) then
          self.bin = to_check
          return self.bin
        end
      end
      return nil, "failed to find leda installation"
    end,
    start = function(self, environment)
      assert(self:find_bin())
      local port = config.get().port
      local host = config.get().host or 'localhost'
      print("starting server on " .. tostring(host) .. ":" .. tostring(port) .. " in environment " .. tostring(environment) .. ". Press Ctrl-C to exit")
      local env = ""
      if environment == 'development' then
        env = "LEDA_DEBUG=1"
      end
      local execute = tostring(env) .. " " .. tostring(self.bin) .. " --execute='require(\"lapis\").serve(\"app\")'"
      return os.execute(execute)
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Leda"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Leda = _class_0
end
leda = Leda()
local find_leda
find_leda = function()
  return leda:find_bin()
end
local start_leda
start_leda = function(environment)
  return leda:start(environment)
end
return {
  find_leda = find_leda,
  start_leda = start_leda
}
