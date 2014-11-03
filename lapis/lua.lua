local _class, _super
_class = function(name, tbl, extend)
  if not (type(name) == "string") then
    extend = tbl
    tbl = name
    name = nil
  end
  local cls
  if extend then
    do
      local _parent_0 = extend
      local _base_0 = { }
      _base_0.__index = _base_0
      setmetatable(_base_0, _parent_0.__base)
      local _class_0 = setmetatable({
        __init = tbl and tbl.new,
        __base = _base_0,
        __name = "cls",
        __parent = _parent_0
      }, {
        __index = function(cls, name)
          local val = rawget(_base_0, name)
          if val == nil then
            return _parent_0[name]
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
      cls = _class_0
    end
  else
    do
      local _base_0 = { }
      _base_0.__index = _base_0
      local _class_0 = setmetatable({
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
      cls = _class_0
    end
  end
  local base = cls.__base
  if tbl then
    tbl.new = nil
    for k, v in pairs(tbl) do
      base[k] = v
    end
  end
  base.super = base.super or _super
  cls.__name = name
  do
    local inherited = extend and extend.__inherited
    if inherited then
      inherited(extend, cls)
    end
  end
  return cls
end
_super = function(instance, method, ...)
  local parent_method
  if method == "new" then
    parent_method = instance.__class.__parent.__init
  else
    parent_method = instance.__class.__parent.__base[method]
  end
  return parent_method(instance, ...)
end
return {
  class = _class,
  super = _super
}
