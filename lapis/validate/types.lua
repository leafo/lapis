local types, BaseType, FailedTransform
do
  local _obj_0 = require("tableshape")
  types, BaseType, FailedTransform = _obj_0.types, _obj_0.BaseType, _obj_0.FailedTransform
end
local assert_error
assert_error = require("lapis.application").assert_error
local AssertErrorType
do
  local _class_0
  local _parent_0 = types.assert
  local _base_0 = {
    assert = assert_error
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "AssertErrorType",
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
  AssertErrorType = _class_0
end
local ParamsType
do
  local _class_0
  local test_input_type
  local _parent_0 = BaseType
  local _base_0 = {
    _transform = function(self, value, state)
      local pass, err = test_input_type(value)
      if not (pass) then
        return FailedTransform, err
      end
      local errors, state
      local _list_0 = self.params_spec
      for _index_0 = 1, #_list_0 do
        local validation = _list_0[_index_0]
        local _ = nil
      end
    end,
    _describe = function(self)
      return "params validator"
    end
  }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, params_spec, opts)
      self.params_spec, self.opts = params_spec, opts
    end,
    __base = _base_0,
    __name = "ParamsType",
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
  test_input_type = types.annotate(types.table, {
    format_error = function(self, val, err)
      return "params: " .. tostring(err)
    end
  })
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  ParamsType = _class_0
end
return {
  params = ParamsType,
  assert_error = AssertErrorType
}
