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
      local nargs = select("#", ...)
      local last = nargs > 0 and select(nargs, ...)
      local opts
      if type(last) == "table" then
        opts = last
      end
      if opts then
        if opts.returning ~= nil then
          error(tostring(self.__class.__name) .. ".update: returning is not supported by the MySQL backend")
        end
        if opts.where ~= nil then
          assert(type(opts.where) == "table", tostring(self.__class.__name) .. ".update: where condition must be a table or db.clause")
        end
      end
      local cond = self:_primary_cond()
      if opts and opts.where then
        local where
        if self.__class.db.is_clause(opts.where) then
          where = opts.where
        else
          where = self.__class.db.encode_clause(opts.where)
        end
        cond = self.__class.db.clause({
          self.__class.db.clause(cond),
          where
        })
      end
      local update_fields = { }
      local columns
      if type(first) == "table" then
        do
          local _accum_0 = { }
          local _len_0 = 1
          for k, v in pairs(first) do
            if type(k) == "number" then
              update_fields[v] = self[v]
              _accum_0[_len_0] = v
            else
              update_fields[k] = v
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
        for _index_0 = 1, #columns do
          local c = columns[_index_0]
          update_fields[c] = self[c]
        end
      end
      if next(columns) == nil then
        return nil, "nothing to update"
      end
      if self.__class.constraints then
        for _index_0 = 1, #columns do
          local column = columns[_index_0]
          do
            local err = self.__class:_check_constraint(column, update_fields[column], self)
            if err then
              return nil, err
            end
          end
        end
      end
      if self.__class.timestamp and not (opts and opts.timestamp == false) then
        local time = self.__class.db.format_date()
        update_fields.updated_at = update_fields.updated_at or time
      end
      local res = db.update(self.__class:table_name(), update_fields, cond)
      local did_update = (res.affected_rows or 0) > 0
      if did_update then
        for k, v in pairs(update_fields) do
          if v == self.__class.db.NULL then
            self[k] = nil
          else
            self[k] = v
          end
        end
      end
      return did_update, res
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
    if opts then
      if opts.returning ~= nil then
        error(tostring(self.__name) .. ".create: returning is not supported by the MySQL backend")
      end
      if opts.on_conflict ~= nil then
        error(tostring(self.__name) .. ".create: on_conflict is not supported by the MySQL backend")
      end
    end
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
