local underscore, escape_pattern, uniquify, singularize
do
  local _obj_0 = require("lapis.util")
  underscore, escape_pattern, uniquify, singularize = _obj_0.underscore, _obj_0.escape_pattern, _obj_0.uniquify, _obj_0.singularize
end
local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local require, type, setmetatable, rawget, assert, pairs, unpack, error, next
do
  local _obj_0 = _G
  require, type, setmetatable, rawget, assert, pairs, unpack, error, next = _obj_0.require, _obj_0.type, _obj_0.setmetatable, _obj_0.rawget, _obj_0.assert, _obj_0.pairs, _obj_0.unpack, _obj_0.error, _obj_0.next
end
local cjson = require("cjson")
local OffsetPaginator
OffsetPaginator = require("lapis.db.pagination").OffsetPaginator
local add_relations, mark_loaded_relations
do
  local _obj_0 = require("lapis.db.model.relations")
  add_relations, mark_loaded_relations = _obj_0.add_relations, _obj_0.mark_loaded_relations
end
local Enum
do
  local _class_0
  local debug
  local _base_0 = {
    for_db = function(self, key)
      if type(key) == "string" then
        return (assert(self[key], "enum does not contain key " .. tostring(key) .. " " .. tostring(debug(self))))
      elseif type(key) == "number" then
        assert(self[key], "enum does not contain val " .. tostring(key) .. " " .. tostring(debug(self)))
        return key
      else
        return error("don't know how to handle type " .. tostring(type(key)) .. " for enum")
      end
    end,
    to_name = function(self, val)
      if type(val) == "string" then
        assert(self[val], "enum does not contain key " .. tostring(val) .. " " .. tostring(debug(self)))
        return val
      elseif type(val) == "number" then
        local key = self[val]
        return (assert(key, "enum does not contain val " .. tostring(val) .. " " .. tostring(debug(self))))
      else
        return error("don't know how to handle type " .. tostring(type(val)) .. " for enum")
      end
    end
  }
  _base_0.__index = _base_0
  _class_0 = setmetatable({
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
  local self = _class_0
  debug = function(self)
    return "(contains: " .. tostring(table.concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for i, v in ipairs(self) do
        _accum_0[_len_0] = tostring(i) .. ":" .. tostring(v)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ", ")) .. ")"
  end
  Enum = _class_0
end
local enum
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
local BaseModel
do
  local _class_0
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
          val = self.__class.db.NULL
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
      local res = self.__class.db.delete(self.__class:table_name(), self:_primary_cond())
      return res.affected_rows and res.affected_rows > 0, res
    end,
    update = function(self, first, ...)
      return error("subclass responsibility")
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
            _accum_0[_len_0] = self.__class.db.escape_identifier(f)
            _len_0 = _len_0 + 1
          end
          return _accum_0
        end)(), ", ")
      end
      local cond = self.__class.db.encode_clause(self:_primary_cond())
      local tbl_name = self.__class.db.escape_identifier(self.__class:table_name())
      local res = unpack(self.__class.db.select(tostring(fields) .. " from " .. tostring(tbl_name) .. " where " .. tostring(cond)))
      if not (res) then
        error(tostring(self.__class:table_name()) .. " failed to find row to refresh from, did the primary key change?")
      end
      if field_names then
        for _index_0 = 1, #field_names do
          local field = field_names[_index_0]
          self[field] = res[field]
        end
      else
        local relations = require("lapis.db.model.relations")
        do
          local loaded_relations = self[relations.LOADED_KEY]
          if loaded_relations then
            for name in pairs(loaded_relations) do
              relations.clear_loaded_relation(self, name)
            end
          end
        end
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
  _class_0 = setmetatable({
    __init = function() end,
    __base = _base_0,
    __name = "BaseModel"
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
  self.db = nil
  self.timestamp = false
  self.primary_key = "id"
  self.__inherited = function(self, child)
    do
      local r = rawget(child, "relations")
      if r then
        return add_relations(child, r, self.db)
      end
    end
  end
  self.get_relation_model = function(self, name)
    return require("models")[name]
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
    if not (rawget(self, "__table_name")) then
      self.__table_name = underscore(self.__name)
    end
    return self.__table_name
  end
  self.scoped_model = function(base_model, prefix, mod, external_models)
    do
      local _class_1
      local _parent_0 = base_model
      local _base_1 = { }
      _base_1.__index = _base_1
      setmetatable(_base_1, _parent_0.__base)
      _class_1 = setmetatable({
        __init = function(self, ...)
          return _class_1.__parent.__init(self, ...)
        end,
        __base = _base_1,
        __name = nil,
        __parent = _parent_0
      }, {
        __index = function(cls, name)
          local val = rawget(_base_1, name)
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
          local _self_0 = setmetatable({}, _base_1)
          cls.__init(_self_0, ...)
          return _self_0
        end
      })
      _base_1.__class = _class_1
      local self = _class_1
      self.get_relation_model = (function()
        if mod then
          return function(self, name)
            if external_models and external_models[name] then
              return base_model:get_relation_model(name)
            else
              return require(mod)[name]
            end
          end
        end
      end)()
      self.table_name = function(self)
        return tostring(prefix) .. tostring(base_model.table_name(self))
      end
      self.singular_name = function(self)
        return singularize(base_model.table_name(self))
      end
      if _parent_0.__inherited then
        _parent_0.__inherited(_parent_0, _class_1)
      end
      return _class_1
    end
  end
  self.singular_name = function(self)
    return singularize(self:table_name())
  end
  self.columns = function(self)
    local columns = self.db.query([[      select column_name, data_type
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
    local opts
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
    query = self.db.interpolate_query(query, ...)
    local tbl_name = self.db.escape_identifier(self:table_name())
    local load_as = opts and opts.load
    local fields = opts and opts.fields or "*"
    do
      local res = self.db.select(tostring(fields) .. " from " .. tostring(tbl_name) .. " " .. tostring(query))
      if res then
        if load_as == false then
          return res
        end
        if load_as then
          return load_as:load_all(res)
        else
          return self:load_all(res)
        end
      end
    end
  end
  self.count = function(self, clause, ...)
    local tbl_name = self.db.escape_identifier(self:table_name())
    local query = "COUNT(*) as c from " .. tostring(tbl_name)
    if clause then
      query = query .. (" where " .. self.db.interpolate_query(clause, ...))
    end
    return unpack(self.db.select(query)).c
  end
  self.include_in = function(self, other_records, foreign_key, opts)
    local fields = opts and opts.fields or "*"
    local flip = opts and opts.flip
    local many = opts and opts.many
    local value_fn = opts and opts.value
    if not flip and type(self.primary_key) == "table" then
      error(tostring(self:table_name()) .. " must have singular primary key for include_in")
    end
    local src_key = flip and (opts.local_key or "id") or foreign_key
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
          _accum_0[_len_0] = self.db.escape_literal(id)
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
      local tbl_name = self.db.escape_identifier(self:table_name())
      local find_by_escaped = self.db.escape_identifier(find_by)
      local query = tostring(fields) .. " from " .. tostring(tbl_name) .. " where " .. tostring(find_by_escaped) .. " in (" .. tostring(flat_ids) .. ")"
      if opts and opts.where then
        query = query .. (" and " .. self.db.encode_clause(opts.where))
      end
      do
        local order = many and opts.order
        if order then
          query = query .. " order by " .. tostring(order)
        end
      end
      do
        local group = opts and opts.group
        if group then
          query = query .. " group by " .. tostring(group)
        end
      end
      do
        local res = self.db.select(query)
        if res then
          local records = { }
          if many then
            for _index_0 = 1, #res do
              local t = res[_index_0]
              local t_key = t[find_by]
              if records[t_key] == nil then
                records[t_key] = { }
              end
              local row = self:load(t)
              if value_fn then
                row = value_fn(row)
              end
              insert(records[t_key], row)
            end
          else
            for _index_0 = 1, #res do
              local t = res[_index_0]
              local row = self:load(t)
              if value_fn then
                row = value_fn(row)
              end
              records[t[find_by]] = row
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
            if many and not other[field_name] then
              other[field_name] = { }
            end
          end
          do
            local for_relation = opts and opts.for_relation
            if for_relation then
              mark_loaded_relations(other_records, for_relation)
            end
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
      error(tostring(self:table_name()) .. " find_all must have a singular key to search")
    end
    if #ids == 0 then
      return { }
    end
    local flat_ids = concat((function()
      local _accum_0 = { }
      local _len_0 = 1
      for _index_0 = 1, #ids do
        local id = ids[_index_0]
        _accum_0[_len_0] = self.db.escape_literal(id)
        _len_0 = _len_0 + 1
      end
      return _accum_0
    end)(), ", ")
    local primary = self.db.escape_identifier(by_key)
    local tbl_name = self.db.escape_identifier(self:table_name())
    local query = fields .. " from " .. tostring(tbl_name) .. " where " .. tostring(primary) .. " in (" .. tostring(flat_ids) .. ")"
    if where then
      query = query .. (" and " .. self.db.encode_clause(where))
    end
    if clause then
      if type(clause) == "table" then
        assert(clause[1], "invalid clause")
        clause = self.db.interpolate_query(unpack(clause))
      end
      query = query .. (" " .. clause)
    end
    do
      local res = self.db.select(query)
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
      error(tostring(self:table_name()) .. " trying to find with no conditions")
    end
    local cond
    if "table" == type(first) then
      cond = self.db.encode_clause((...))
    else
      cond = self.db.encode_clause(self:encode_key(...))
    end
    local table_name = self.db.escape_identifier(self:table_name())
    do
      local result = unpack(self.db.select("* from " .. tostring(table_name) .. " where " .. tostring(cond) .. " limit 1"))
      if result then
        return self:load(result)
      end
    end
  end
  self.create = function(self, values, opts)
    return error("subclass responsibility")
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
    local cond = self.db.encode_clause(t)
    local table_name = self.db.escape_identifier(self:table_name())
    return nil ~= unpack(self.db.select("1 from " .. tostring(table_name) .. " where " .. tostring(cond) .. " limit 1"))
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
    local class_fields = {
      "primary_key",
      "timestamp",
      "constraints",
      "relations"
    }
    return lua.class(table_name, tbl, self, function(cls)
      cls.table_name = function()
        return table_name
      end
      for _index_0 = 1, #class_fields do
        local f = class_fields[_index_0]
        cls[f] = tbl[f]
        cls.__base[f] = nil
      end
    end)
  end
  BaseModel = _class_0
end
return {
  BaseModel = BaseModel,
  Enum = Enum,
  enum = enum
}
