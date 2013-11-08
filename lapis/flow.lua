local type, getmetatable, setmetatable
do
  local _obj_0 = _G
  type, getmetatable, setmetatable = _obj_0.type, _obj_0.getmetatable, _obj_0.setmetatable
end
local Flow
do
  local _base_0 = { }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, _req, obj)
      if obj == nil then
        obj = { }
      end
      self._req = _req
      assert(self._req, "flow missing request")
      local proxy = setmetatable(obj, getmetatable(self))
      return setmetatable(self, {
        __index = function(self, key)
          local val = proxy[key]
          if val ~= nil then
            return val
          end
          val = self._req[key]
          if type(val) == "function" then
            val = function(_, ...)
              return self._req[key](self._req, ...)
            end
            self[key] = val
          end
          return val
        end
      })
    end,
    __base = _base_0,
    __name = "Flow"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Flow = _class_0
end
return {
  Flow = Flow
}
