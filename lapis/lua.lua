local _super
_super = function(cls, self, method, ...)
  local fn
  if method == "new" then
    fn = cls.__parent.__init
  else
    fn = cls.__parent.__base[method]
  end
  return fn(self, ...)
end
local _class
_class = function(name, tbl, extend, setup_fn)
  local cls
  if extend then
    do
      local _class_0
      local _parent_0 = extend
      local _base_0 = { }
      _base_0.__index = _base_0
      setmetatable(_base_0, _parent_0.__base)
      _class_0 = setmetatable({
        __init = tbl and tbl.new,
        __base = _base_0,
        __name = "cls",
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
      local self = _class_0
      self.super = _super
      self.__name = name
      if tbl then
        tbl.new = nil
        for k, v in pairs(tbl) do
          self.__base[k] = v
        end
      end
      local _ = setup_fn and setup_fn(self)
      if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_0)
      end
      cls = _class_0
    end
  else
    do
      local _class_0
      local _base_0 = { }
      _base_0.__index = _base_0
      _class_0 = setmetatable({
        __init = tbl and tbl.new,
        __base = _base_0,
        __name = "cls"
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
      self.super = _super
      self.__name = name
      if tbl then
        tbl.new = nil
        for k, v in pairs(tbl) do
          self.__base[k] = v
        end
      end
      local _ = setup_fn and setup_fn(self)
      cls = _class_0
    end
  end
  return cls
end
return {
  class = _class
}
