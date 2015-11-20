local Dict
do
  local _class_0
  local _base_0 = {
    get = function(self, key)
      return self.store[key], self.flags[key]
    end,
    set = function(self, key, value, exp, flags)
      self.store[key] = value
      self.flags[key] = flags
      return true
    end,
    add = function(self, key, ...)
      if self.store[key] == nil then
        self:set(key, ...)
      end
      return true
    end,
    replace = function(self, key, ...)
      if self.store[key] ~= nil then
        self:set(key, ...)
      end
      return true
    end,
    delete = function(self, key)
      return self:set(key, nil)
    end,
    incr = function(self, key, value)
      if self.store[key] == nil then
        return nil, "not found"
      end
      local new_val = self.store[key] + value
      self.store[key] = new_val
      return new_val
    end,
    get_keys = function(self)
      local _accum_0 = { }
      local _len_0 = 1
      for k in pairs(self.store) do
        _accum_0[_len_0] = k
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end,
    flush_all = function(self)
      self.store = { }
      self.flags = { }
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self)
      return self:flush_all()
    end,
    __base = _base_0,
    __name = "Dict"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Dict = _class_0
end
local make_shared
make_shared = function()
  return setmetatable({ }, {
    __index = function(self, key)
      do
        local d = Dict()
        self[key] = d
        return d
      end
    end
  })
end
local setup
setup = function()
  local stack = require("lapis.spec.stack")
  return stack.push({
    shared = make_shared()
  })
end
local teardown
teardown = function()
  local stack = require("lapis.spec.stack")
  return stack.pop()
end
return {
  setup = setup,
  teardown = teardown,
  make_shared = make_shared
}
