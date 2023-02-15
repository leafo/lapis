local db = require("lapis.db.mysql")
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
  local _base_0 = {
    update = function(self, first, ...)
      local cond = self:_primary_cond()
      local columns
      if type(first) == "table" then
        do
          local _accum_0 = { }
          local _len_0 = 1
          for k, v in pairs(first) do
            if type(k) == "number" then
              _accum_0[_len_0] = v
            else
              self[k] = v
              _accum_0[_len_0] = k
            end
            _len_0 = _len_0 + 1
          end
          columns = _accum_0
        end
      else
        columns = {
          first,
          ...
        }
      end
      if next(columns) == nil then
        return nil, "nothing to update"
      end
      if self.__class.constraints then
        for _, column in pairs(columns) do
          do
            local err = self.__class:_check_constraint(column, self[column], self)
            if err then
              return nil, err
            end
          end
        end
      end
      local values
      do
        local _tbl_0 = { }
        for _index_0 = 1, #columns do
          local col = columns[_index_0]
          _tbl_0[col] = self[col]
        end
        values = _tbl_0
      end
      local nargs = select("#", ...)
      local last = nargs > 0 and select(nargs, ...)
      local opts
      if type(last) == "table" then
        opts = last
      end
      if self.__class.timestamp and not (opts and opts.timestamp == false) then
        local time = self.__class.db.format_date()
        values.updated_at = values.updated_at or time
      end
      local res = db.update(self.__class:table_name(), values, cond)
      return (res.affected_rows or 0) > 0, res
    end
  }
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
    local columns = self.db.query("\n      SHOW COLUMNS FROM " .. tostring(self.db.escape_identifier(self:table_name())) .. "\n    ")
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #columns do
        local c = columns[_index_0]
        _accum_0[_len_0] = c
        _len_0 = _len_0 + 1
      end
      columns = _accum_0
    end
    self.columns = function()
      return columns
    end
    return columns
  end
  self.create = function(self, values, opts)
    if self.constraints then
      for key in pairs(self.constraints) do
        do
          local err = self:_check_constraint(key, values and values[key], values)
          if err then
            return nil, err
          end
        end
      end
    end
    if self.timestamp then
      local time = self.db.format_date()
      values.created_at = values.created_at or time
      values.updated_at = values.updated_at or time
    end
    local res = db.insert(self:table_name(), values)
    if res then
      local new_id = res.last_auto_id or res.insert_id
      if not values[self.primary_key] and new_id and new_id ~= 0 then
        values[self.primary_key] = new_id
      end
      return self:load(values)
    else
      return nil, "Failed to create " .. tostring(self.__name)
    end
  end
  self.find_all = function(self, ...)
    local res = BaseModel.find_all(self, ...)
    if res[1] then
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #res do
        local r = res[_index_0]
        _accum_0[_len_0] = r
        _len_0 = _len_0 + 1
      end
      return _accum_0
    else
      return res
    end
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
