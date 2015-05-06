local db = require("lapis.db")
local underscore, escape_pattern, uniquify, get_fields
do
  local _obj_0 = require("lapis.util")
  underscore, escape_pattern, uniquify, get_fields = _obj_0.underscore, _obj_0.escape_pattern, _obj_0.uniquify, _obj_0.get_fields
end
local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local cjson = require("cjson")
local OffsetPaginator
do
  local _obj_0 = require("lapis.db.pagination")
  OffsetPaginator = _obj_0.OffsetPaginator
end
local singularize, Enum, enum, add_relations, Model
singularize = function(name)
  return name:match("^(.*)s$") or name
end
do
  local _base_0 = {
    for_db = function(self, key)
      if type(key) == "string" then
        return (assert(self[key], "enum does not contain key " .. tostring(key)))
      elseif type(key) == "number" then
        assert(self[key], "enum does not contain val " .. tostring(key))
        return key
      else
        return error("don't know how to handle type " .. tostring(type(key)) .. " for enum")
      end
    end,
    to_name = function(self, val)
      if type(val) == "string" then
        assert(self[val], "enum does not contain key " .. tostring(val))
        return val
      elseif type(val) == "number" then
        local key = self[val]
        return (assert(key, "enum does not contain val " .. tostring(val)))
      else
        return error("don't know how to handle type " .. tostring(type(val)) .. " for enum")
      end
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Enum"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Enum = _class_0
end
enum = function(tbl)
  local keys
  do
    local _accum_0 = { }
    local _len_0 = 1
    for k in pairs(tbl) do
      _accum_0[_len_0] = k
      _len_0 = _len_0 + 1
    end
    keys = _accum_0
  end
  for _index_0 = 1, #keys do
    local key = keys[_index_0]
    tbl[tbl[key]] = key
  end
  return setmetatable(tbl, Enum.__base)
end
add_relations = function(self, relations)
  local relation_builders = require("lapis.db.model.relations")
  for _index_0 = 1, #relations do
    local _continue_0 = false
    repeat
      local relation = relations[_index_0]
      local name = assert(relation[1], "missing relation name")
      local built = false
      for k in pairs(relation) do
        do
          local builder = relation_builders[k]
          if builder then
            builder(self, name, relation)
            built = true
            break
          end
        end
      end
      if built then
        _continue_0 = true
        break
      end
      local flatten_params
      flatten_params = require("lapis.logging").flatten_params
      error("don't know how to create relation `" .. tostring(flatten_params(relation)) .. "`")
      _continue_0 = true
    until true
    if not _continue_0 then
      break
    end
  end
end
do
  local _base_0 = {
    _primary_cond = function(self)
      local cond = { }
      local _list_0 = {
        self.__class:primary_keys()
      }
      for _index_0 = 1, #_list_0 do
        local key = _list_0[_index_0]
        local val = self[key]
        if val == nil then
          val = db.NULL
        end
        cond[key] = val
      end
      return cond
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
      local res = db.delete(self.__class:table_name(), self:_primary_cond())
      return res.affected_rows and res.affected_rows > 0, res
    end,
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
              for k, v in pairs(update) do
                self[k] = v
              end
            end
          end
          return res
        end
      else
        return db.update(self.__class:table_name(), values, cond)
      end
    end,
    refresh = function(self, fields, ...)
      if fields == nil then
        fields = "*"
      end
      local field_names
      if fields ~= "*" then
        field_names = {
          fields,
          ...
        }
        fields = table.concat((function()
          local _accum_0 = { }
          local _len_0 = 1
          for _index_0 = 1, #field_names do
            local f = field_names[_index_0]
            _accum_0[_len_0] = db.escape_identifier(f)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ", ")
      end
      local cond = db.encode_clause(self:_primary_cond())
      local tbl_name = db.escape_identifier(self.__class:table_name())
      local res = unpack(db.select(tostring(fields) .. " from " .. tostring(tbl_name) .. " where " .. tostring(cond)))
      if not (res) then
        error("failed to find row to refresh from, did the primary key change?")
      end
      if field_names then
        for _index_0 = 1, #field_names do
          local field = field_names[_index_0]
          self[field] = res[field]
        end
      else
        for k, v in pairs(self) do
          self[k] = nil
        end
        for k, v in pairs(res) do
          self[k] = v
        end
        self.__class:load(self)
      end
      return self
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "Model"
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
  self.timestamp = false
  self.primary_key = "id"
  self.__inherited = function(self, child)
    do
      local r = child.relations
      if r then
        return add_relations(child, r)
      end
    end
  end
  self.primary_keys = function(self)
    if type(self.primary_key) == "table" then
      return unpack(self.primary_key)
    else
      return self.primary_key
    end
  end
  self.encode_key = function(self, ...)
    if type(self.primary_key) == "table" then
      local _tbl_0 = { }
      for i, k in ipairs(self.primary_key) do
        _tbl_0[k] = select(i, ...)
      end
      return _tbl_0
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
  self.singular_name = function(self)
    return singularize(self:table_name())
  end
  self.columns = function(self)
    local columns = db.query([[      select column_name, data_type
      from information_schema.columns
      where table_name = ?]], self:table_name())
    self.columns = function()
      return columns
    end
    return columns
  end
  self.load = function(self, tbl)
    for k, v in pairs(tbl) do
      if ngx and v == ngx.null or v == cjson.null then
        tbl[k] = nil
      end
    end
    return setmetatable(tbl, self.__base)
  end
  self.load_all = function(self, tbls)
    local _accum_0 = { }
    local _len_0 = 1
    for _index_0 = 1, #tbls do
      local t = tbls[_index_0]
      _accum_0[_len_0] = self:load(t)
      _len_0 = _len_0 + 1
    end
    return _accum_0
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
    if type(query) == "table" then
      opts = query
      query = ""
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
  self.count = function(self, clause, ...)
    local tbl_name = db.escape_identifier(self:table_name())
    local query = "COUNT(*) as c from " .. tostring(tbl_name)
    if clause then
      query = query .. (" where " .. db.interpolate_query(clause, ...))
    end
    return unpack(db.select(query)).c
  end
  self.include_in = function(self, other_records, foreign_key, opts)
    local fields = opts and opts.fields or "*"
    local flip = opts and opts.flip
    local many = opts and opts.many
    if not flip and type(self.primary_key) == "table" then
      error("model must have singular primary key to include")
    end
    local src_key = flip and "id" or foreign_key
    local include_ids
    do
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #other_records do
        local _continue_0 = false
        repeat
          local record = other_records[_index_0]
          do
            local id = record[src_key]
            if not (id) then
              _continue_0 = true
              break
            end
            _accum_0[_len_0] = id
          end
          _len_0 = _len_0 + 1
          _continue_0 = true
        until true
        if not _continue_0 then
          break
        end
      end
      include_ids = _accum_0
    end
    if next(include_ids) then
      include_ids = uniquify(include_ids)
      local flat_ids = concat((function()
        local _accum_0 = { }
        local _len_0 = 1
        for _index_0 = 1, #include_ids do
          local id = include_ids[_index_0]
          _accum_0[_len_0] = db.escape_literal(id)
          _len_0 = _len_0 + 1
        end
        return _accum_0
      end)(), ", ")
      local find_by
      if flip then
        find_by = foreign_key
      else
        find_by = self.primary_key
      end
      local tbl_name = db.escape_identifier(self:table_name())
      local find_by_escaped = db.escape_identifier(find_by)
      local query = tostring(fields) .. " from " .. tostring(tbl_name) .. " where " .. tostring(find_by_escaped) .. " in (" .. tostring(flat_ids) .. ")"
      if opts and opts.where then
        query = query .. (" and " .. db.encode_clause(opts.where))
      end
      do
        local res = db.select(query)
        if res then
          local records = { }
<<<<<<< HEAD
          for _index_0 = 1, #res do
            local t = res[_index_0]
            local t_key = t[find_by]
            local data = self:load(t)
            if has_many then
              if records[t_key] == nil then
                records[t_key] = { }
              end
              table.insert(records[t_key], data)
            else
              records[t_key] = data
=======
          if many then
            for _index_0 = 1, #res do
              local t = res[_index_0]
              local t_key = t[find_by]
              if records[t_key] == nil then
                records[t_key] = { }
              end
              insert(records[t_key], self:load(t))
            end
          else
            for _index_0 = 1, #res do
              local t = res[_index_0]
              records[t[find_by]] = self:load(t)
>>>>>>> upstream/master
            end
          end
          local field_name
          if opts and opts.as then
            field_name = opts.as
          elseif flip then
            if many then
              field_name = self:table_name()
            else
              field_name = self:singular_name()
            end
          else
            field_name = foreign_key:match("^(.*)_" .. tostring(escape_pattern(self.primary_key)) .. "$")
          end
          assert(field_name, "failed to infer field name, provide one with `as`")
          for _index_0 = 1, #other_records do
            local other = other_records[_index_0]
            other[field_name] = records[other[src_key]]
          end
        end
      end
    end
    return other_records
  end
  self.find_all = function(self, ids, by_key)
    if by_key == nil then
      by_key = self.primary_key
    end
    local where = nil
    local clause = nil
    local fields = "*"
    if type(by_key) == "table" then
      fields = by_key.fields or fields
      where = by_key.where
      clause = by_key.clause
      by_key = by_key.key or self.primary_key
    end
    if type(by_key) == "table" and by_key[1] ~= "raw" then
      error("find_all must have a singular key to search")
    end
    if #ids == 0 then
      return { }
    end
    local flat_ids = concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #ids do
        local id = ids[_index_0]
        _accum_0[_len_0] = db.escape_literal(id)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ", ")
    local primary = db.escape_identifier(by_key)
    local tbl_name = db.escape_identifier(self:table_name())
    local query = fields .. " from " .. tostring(tbl_name) .. " where " .. tostring(primary) .. " in (" .. tostring(flat_ids) .. ")"
    if where then
      query = query .. (" and " .. db.encode_clause(where))
    end
    if clause then
      if type(clause) == "table" then
        assert(clause[1], "invalid clause")
        clause = db.interpolate_query(unpack(clause))
      end
      query = query .. (" " .. clause)
    end
    do
      local res = db.select(query)
      if res then
        for _index_0 = 1, #res do
          local r = res[_index_0]
          self:load(r)
        end
        return res
      end
    end
  end
  self.find = function(self, ...)
    local first = select(1, ...)
    if first == nil then
      error("(" .. tostring(self:table_name()) .. ") trying to find with no conditions")
    end
    local cond
    if "table" == type(first) then
      cond = db.encode_clause((...))
    else
      cond = db.encode_clause(self:encode_key(...))
    end
    local table_name = db.escape_identifier(self:table_name())
    do
      local result = unpack(db.select("* from " .. tostring(table_name) .. " where " .. tostring(cond) .. " limit 1"))
      if result then
        return self:load(result)
      end
    end
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
      values._timestamp = true
    end
    local returning
    if opts and opts.returning then
      returning = {
        self:primary_keys()
      }
      local _list_0 = opts.returning
      for _index_0 = 1, #_list_0 do
        local field = _list_0[_index_0]
        table.insert(returning, field)
      end
    end
    for k, v in pairs(values) do
      if db.is_raw(v) then
        returning = returning or {
          self:primary_keys()
        }
        table.insert(returning, k)
      end
    end
    local res
    if returning then
      res = db.insert(self:table_name(), values, unpack(returning))
    else
      res = db.insert(self:table_name(), values, self:primary_keys())
    end
    if res then
      for k, v in pairs(res[1]) do
        values[k] = v
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
    if not (next(t)) then
      error("missing constraint to check")
    end
    local cond = db.encode_clause(t)
    local table_name = db.escape_identifier(self:table_name())
    return nil ~= unpack(db.select("1 from " .. tostring(table_name) .. " where " .. tostring(cond) .. " limit 1"))
  end
  self._check_constraint = function(self, key, value, obj)
    if not (self.constraints) then
      return 
    end
    do
      local fn = self.constraints[key]
      if fn then
        return fn(self, value, key, obj)
      end
    end
  end
  self.paginated = function(self, ...)
    return OffsetPaginator(self, ...)
  end
  self.extend = function(self, table_name, tbl)
    if tbl == nil then
      tbl = { }
    end
    local lua = require("lapis.lua")
    do
      local cls = lua.class(table_name, tbl, self)
      cls.table_name = function()
        return table_name
      end
      cls.primary_key = tbl.primary_key
      cls.timestamp = tbl.timestamp
      cls.constraints = tbl.constraints
      return cls
    end
  end
  Model = _class_0
end
return {
  Model = Model,
  Enum = Enum,
  enum = enum
}
