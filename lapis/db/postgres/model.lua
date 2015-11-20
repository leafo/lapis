local db = require("lapis.db.postgres")
local BaseModel, Enum, enum
do
  local _obj_0 = require("lapis.db.base_model")
  BaseModel, Enum, enum = _obj_0.BaseModel, _obj_0.Enum, _obj_0.enum
end
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
        values._timestamp = true
      end
      local returning
      for k, v in pairs(values) do
        if db.is_raw(v) then
          returning = returning or { }
          table.insert(returning, k)
        end
      end
      if returning then
        do
          local res = db.update(self.__class:table_name(), values, cond, unpack(returning))
          do
            local update = unpack(res)
            if update then
              for _index_0 = 1, #returning do
                local k = returning[_index_0]
                self[k] = update[k]
              end
            end
          end
          return res
        end
      else
        return db.update(self.__class:table_name(), values, cond)
      end
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
      values._timestamp = true
    end
    local returning, return_all
    if opts and opts.returning then
      if opts.returning == "*" then
        return_all = true
        returning = {
          db.raw("*")
        }
      else
        returning = {
          self:primary_keys()
        }
        local _list_0 = opts.returning
        for _index_0 = 1, #_list_0 do
          local field = _list_0[_index_0]
          table.insert(returning, field)
        end
      end
    end
    if not (return_all) then
      for k, v in pairs(values) do
        if db.is_raw(v) then
          returning = returning or {
            self:primary_keys()
          }
          table.insert(returning, k)
        end
      end
    end
    local res
    if returning then
      res = db.insert(self:table_name(), values, unpack(returning))
    else
      res = db.insert(self:table_name(), values, self:primary_keys())
    end
    if res then
      if returning and not return_all then
        for _index_0 = 1, #returning do
          local k = returning[_index_0]
          values[k] = res[1][k]
        end
      end
      for k, v in pairs(res[1]) do
        values[k] = v
      end
      return self:load(values)
    else
      return nil, "Failed to create " .. tostring(self.__name)
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
  enum = enum
}
