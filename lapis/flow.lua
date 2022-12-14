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
    __init = function(self, _, obj)
      if obj == nil then
        obj = { }
      end
      self._ = _
      assert(self._, "missing flow target")
      self._req = self._
      if is_flow(self._.__class) then
        self._ = self._._
      end
      local old_mt = getmetatable(self)
      local proxy = setmetatable(obj, old_mt)
      local mt = {
        __call = old_mt.__call,
        __index = function(self, key)
          local val = proxy[key]
          if val ~= nil then
            return val
          end
          val = self._[key]
          if type(val) == "function" then
            val = function(_, ...)
              return self._[key](self._, ...)
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
                self._[key] = val
              else
                return rawset(self, key, val)
              end
            else
              self._[key] = val
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
  local self = _class_0
  self.extend = function(self, name, tbl)
    local lua = require("lapis.lua")
    if type(name) == "table" then
      tbl = name
      name = nil
    end
    local class_fields = { }
    local cls = lua.class(name or "ExtendedFlow", tbl, self)
    return cls, cls.__base
  end
  Flow = _class_0
end
return {
  Flow = Flow,
  is_flow = is_flow
}
