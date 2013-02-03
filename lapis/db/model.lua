local db = require("lapis.db")
db.set_logger(require("lapis.logging"))
local underscore, escape_pattern, uniquify
do
  local _table_0 = require("lapis.util")
  underscore, escape_pattern, uniquify = _table_0.underscore, _table_0.escape_pattern, _table_0.uniquify
end
local insert, concat = table.insert, table.concat
local Model
do
  local _parent_0 = nil
  local _base_0 = {
    _primary_cond = function(self)
      return (function()
        local _tbl_0 = { }
        local _list_0 = {
          self.__class:primary_keys()
        }
        for _index_0 = 1, #_list_0 do
          local key = _list_0[_index_0]
          _tbl_0[key] = self[key]
        end
        return _tbl_0
      end)()
    end,
    url_key = function(self)
      return concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = {
          self.__class:primary_keys()
        }
        for _index_0 = 1, #_list_0 do
          local key = _list_0[_index_0]
          _accum_0[_len_0] = self[key]
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), "-")
    end,
    delete = function(self)
      return db.delete(self.__class:table_name(), self:_primary_cond())
    end,
    update = function(self, first, ...)
      local cond = self:_primary_cond()
      local columns
      if type(first) == "table" then
        columns = (function()
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
          return _accum_0
        end)()
      else
        columns = {
          first,
          ...
        }
      end
      return db.update(self.__class:table_name(), (function()
        local _tbl_0 = { }
        local _list_0 = columns
        for _index_0 = 1, #_list_0 do
          local col = _list_0[_index_0]
          _tbl_0[col] = self[col]
        end
        return _tbl_0
      end)(), cond)
    end
  }
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
    local name = underscore(self.__name)
    self.table_name = function()
      return name
    end
    return name
  end
  self.load = function(self, tbl)
    for k, v in pairs(tbl) do
      if v == ngx.null then
        tbl[k] = nil
      end
    end
    return setmetatable(tbl, self.__base)
  end
  self.load_all = function(self, tbls)
    return (function()
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = tbls
      for _index_0 = 1, #_list_0 do
        local t = _list_0[_index_0]
        _accum_0[_len_0] = self:load(t)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)()
  end
  self.select = function(self, query, ...)
    if query == nil then
      query = ""
    end
    local opts = { }
    local param_count = select("#", ...)
    if param_count > 0 then
      local last = select(param_count, ...)
      if type(last) == "table" then
        opts = last
      end
    end
    query = db.interpolate_query(query, ...)
    local tbl_name = db.escape_identifier(self:table_name())
    local fields = opts.fields or "*"
    do
      local res = db.select(tostring(fields) .. " from " .. tostring(tbl_name) .. " " .. tostring(query))
      if res then
        return self:load_all(res)
      end
    end
  end
  self.include_in = function(self, other_records, foreign_key)
    if type(self.primary_key) == "table" then
      error("model must have singular primary key to include")
    end
    local include_ids = (function()
      local _accum_0 = { }
      local _len_0 = 1
      local _list_0 = other_records
      for _index_0 = 1, #_list_0 do
        local _continue_0 = false
        repeat
          local record = _list_0[_index_0]
          do
            local _with_0 = record[foreign_key]
            local id = _with_0
            if not (id) then
              _continue_0 = true
              break
            end
            _accum_0[_len_0] = _with_0
          end
          _len_0 = _len_0 + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      return _accum_0
    end)()
    if next(include_ids) then
      include_ids = uniquify(include_ids)
      local flat_ids = concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        local _list_0 = include_ids
        for _index_0 = 1, #_list_0 do
          local id = _list_0[_index_0]
          _accum_0[_len_0] = db.escape_literal(id)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), ", ")
      local primary = db.escape_identifier(self.primary_key)
      local tbl_name = db.escape_identifier(self:table_name())
      do
        local res = db.select("* from " .. tostring(tbl_name) .. " where " .. tostring(primary) .. " in (" .. tostring(flat_ids) .. ")")
        if res then
          local records = { }
          local _list_0 = res
          for _index_0 = 1, #_list_0 do
            local t = _list_0[_index_0]
            records[t[self.primary_key]] = self:load(t)
          end
          local field_name = foreign_key:match("^(.*)_" .. tostring(escape_pattern(self.primary_key)) .. "$")
          local _list_1 = other_records
          for _index_0 = 1, #_list_1 do
            local other = _list_1[_index_0]
            other[field_name] = records[other[foreign_key]]
          end
        end
      end
    end
    return other_records
  end
  self.find = function(self, ...)
    local first = select(1, ...)
    if first == nil then
      error("(" .. tostring(self:table_name()) .. ") trying to find with no conditions")
    end
    local cond
    if "table" == type(first) then
      cond = db.encode_assigns((...), nil, " and ")
    else
      cond = db.encode_assigns(self:encode_key(...), nil, " and ")
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
    else
      return nil, "Failed to create " .. tostring(self.__name)
    end
  end
  self.check_unique_constraint = function(self, name, value)
    local t
    if type(name) == "table" then
      t = name
    else
      t = {
        [name] = value
      }
    end
    local cond = db.encode_assigns(t, nil, " and ")
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
