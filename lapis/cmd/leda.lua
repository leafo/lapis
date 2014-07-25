local dump
do
  local _obj_0 = require('moonscript.util')
  dump = _obj_0.dump
end
local lfs = require('lfs')
local config = require('lapis.config')
local Leda, leda, find_leda, start_leda
do
  local _base_0 = {
    paths = {
      "/usr/local/bin",
      "/usr/bin"
    },
    start = function(self, environment)
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
  local _class_0 = setmetatable({
    __init = function(self)
      local bin = "leda"
      table.insert(self.paths, os.getenv("LAPIS_LEDA"))
      local _list_0 = self.paths
      for _index_0 = 1, #_list_0 do
        local path = _list_0[_index_0]
        path = path .. "/" .. "leda"
        if lfs.attributes(path) then
          self.bin = path
        end
      end
    end,
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
find_leda = function()
  return leda.bin
end
start_leda = function(environment)
  return leda:start(environment)
end
return {
  find_leda = find_leda,
  start_leda = start_leda
}
