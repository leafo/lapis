local type, getmetatable, setmetatable, rawset
do
  local _obj_0 = _G
  type, getmetatable, setmetatable, rawset = _obj_0.type, _obj_0.getmetatable, _obj_0.setmetatable, _obj_0.rawset
end
local Flow
local is_flow
is_flow = function(cls)
  if not (cls) then
    return false
  end
  if cls == Flow then
    return true
  end
  return is_flow(cls.__parent)
end
do
  local _class_0
  local _base_0 = {
    expose_assigns = false
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
    __init = function(self, _req, obj)
      if obj == nil then
        obj = { }
      end
      self._req = _req
      assert(self._req, "flow missing request")
      if is_flow(self._req.__class) then
        self._req = self._req._req
      end
      local proxy = setmetatable(obj, getmetatable(self))
      local mt = {
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
            rawset(self, key, val)
          end
          return val
        end
      }
      do
        local expose = self.expose_assigns
        if expose then
          local allowed_assigns
          if type(expose) == "table" then
            do
              local _tbl_0 = { }
              for _index_0 = 1, #expose do
                local name = expose[_index_0]
                _tbl_0[name] = true
              end
              allowed_assigns = _tbl_0
            end
          end
          mt.__newindex = function(self, key, val)
            if allowed_assigns then
              if allowed_assigns[key] then
                self._req[key] = val
              else
                return rawset(self, key, val)
              end
            else
              self._req[key] = val
            end
          end
        end
      end
      return setmetatable(self, mt)
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
  Flow = Flow,
  is_flow = is_flow
}
