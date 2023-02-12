local db = require("lapis.db.postgres")
local select, pairs, type
do
  local _obj_0 = _G
  select, pairs, type, select = _obj_0.select, _obj_0.pairs, _obj_0.type, _obj_0.select
end
local unpack = unpack or table.unpack
local insert
insert = table.insert
local BaseModel, Enum, enum
do
  local _obj_0 = require("lapis.db.base_model")
  BaseModel, Enum, enum = _obj_0.BaseModel, _obj_0.Enum, _obj_0.enum
end
local preload
preload = require("lapis.db.model.relations").preload
local Model
do
  local _class_0
  local _parent_0 = BaseModel
  local _base_0 = { }
  _base_0.__index = _base_0
  setmetatable(_base_0, _parent_0.__base)
  _class_0 = setmetatable({
    __init = function(self, ...)
      return _class_0.__parent.__init(self, ...)
    end,
    __base = _base_0,
    __name = "Model",
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
  self.db = db
  self.columns = function(self)
    local columns = self.db.query([[SELECT column_name, data_type FROM information_schema.columns WHERE table_name = ?]], self:table_name())
    self.columns = function()
      return columns
    end
    return columns
  end
  if _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Model = _class_0
end
return {
  Model = Model,
  Enum = Enum,
  enum = enum,
  preload = preload
}
