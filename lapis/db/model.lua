local db = require("lapis.db")
local underscore
do
  local _table_0 = require("lapis.util")
  underscore = _table_0.underscore
end
local Model
do
  local _parent_0 = nil
  local _base_0 = { }
  _base_0.__index = _base_0
  if _parent_0 then
    setmetatable(_base_0, _parent_0.__base)
  end
  local _class_0 = setmetatable({
    __init = function(self, ...)
      if _parent_0 then
        return _parent_0.__init(self, ...)
      end
    end,
    __base = _base_0,
    __name = "Model",
    __parent = _parent_0
  }, {
    __index = function(cls, name)
      local val = rawget(_base_0, name)
      if val == nil and _parent_0 then
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
  local self = _class_0
  self.timestamp = false
  self.primary_key = "id"
  self.primary_keys = function(self)
    if type(self.primary_key) == "table" then
      return unpack(self.primary_key)
    else
      return self.primary_key
    end
  end
  self.encode_key = function(self, ...)
    if type(self.primary_key) == "table" then
      return (function(...)
        local _tbl_0 = { }
        for i, k in ipairs(self.primary_key) do
          _tbl_0[k] = select(i, ...)
        end
        return _tbl_0
      end)(...)
    else
      return {
        [self.primary_key] = ...
      }
    end
  end
  self.table_name = function(self)
    return underscore(self.__name)
  end
  self.load = function(self, tbl)
    return setmetatable(tbl, self.__base)
  end
  self.find = function(self, ...)
    local cond
    if "table" == type(select(1, ...)) then
      cond = db.encode_assigns((...))
    else
      cond = db.encode_assigns(self:encode_key(...))
    end
    local table_name = db.escape_identifier(self:table_name())
    do
      local result = unpack(db.select("* from " .. tostring(table_name) .. " where " .. tostring(cond) .. " limit 1"))
      if result then
        return self:load(result)
      end
    end
  end
  self.create = function(self, values)
    if self.timestamp then
      values._timestamp = true
    end
    local res = db.insert(self:table_name(), values, self:primary_keys())
    if res then
      if res.resultset then
        for k, v in pairs(res.resultset[1]) do
          values[k] = v
        end
      end
      return self:load(values)
    end
  end
  self.check_unique_constraint = function(self, name, value)
    local cond = db.encode_assigns({
      [name] = value
    })
    local table_name = db.escape_identifier(self:table_name())
    local res = unpack(db.select("COUNT(*) as c from " .. tostring(table_name) .. " where " .. tostring(cond)))
    return res.c > 0
  end
  if _parent_0 and _parent_0.__inherited then
    _parent_0.__inherited(_parent_0, _class_0)
  end
  Model = _class_0
end
return {
  Model = Model
}
