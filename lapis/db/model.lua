local db = require("lapis.db")
local underscore, escape_pattern, uniquify
do
  local _obj_0 = require("lapis.util")
  underscore, escape_pattern, uniquify = _obj_0.underscore, _obj_0.escape_pattern, _obj_0.uniquify
end
local insert, concat
do
  local _obj_0 = table
  insert, concat = _obj_0.insert, _obj_0.concat
end
local cjson = require("cjson")
local Model, Paginator
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
      return db.delete(self.__class:table_name(), self:_primary_cond())
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
        return 
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
      if self.__class.constraints then
        for key, value in pairs(values) do
          do
            local err = self.__class:_check_constraint(key, value, self)
            if err then
              return nil, err
            end
          end
        end
      end
      if self.__class.timestamp then
        values._timestamp = true
      end
      return db.update(self.__class:table_name(), values, cond)
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
          for _index_0 = 1, #res do
            local t = res[_index_0]
            records[t[find_by]] = self:load(t)
          end
          local field_name
          if opts and opts.as then
            field_name = opts.as
          elseif flip then
            local tbl = self:table_name()
            field_name = tbl:match("^(.*)s$") or tbl
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
    local fields = "*"
    if type(by_key) == "table" then
      fields = by_key.fields or fields
      where = by_key.where
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
  self.create = function(self, values)
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
    local res = db.insert(self:table_name(), values, self:primary_keys())
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
    return Paginator(self, ...)
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
do
  local _base_0 = {
    per_page = 10,
    each_page = function(self, starting_page)
      if starting_page == nil then
        starting_page = 1
      end
      return coroutine.wrap(function()
        local page = starting_page
        while true do
          local results = self:get_page(page)
          if not (next(results)) then
            break
          end
          coroutine.yield(results, page)
          page = page + 1
        end
      end)
    end,
    get_all = function(self)
      return self.prepare_results(self.model:select(self._clause, self.opts))
    end,
    get_page = function(self, page)
      page = (math.max(1, tonumber(page) or 0)) - 1
      return self.prepare_results(self.model:select(self._clause .. [[      limit ?
      offset ?
    ]], self.per_page, self.per_page * page, self.opts))
    end,
    num_pages = function(self)
      return math.ceil(self:total_items() / self.per_page)
    end,
    total_items = function(self)
      self._count = self._count or self.model:count(db.parse_clause(self._clause).where)
      return self._count
    end,
    prepare_results = function(...)
      return ...
    end
  }
  _base_0.__index = _base_0
  local _class_0 = setmetatable({
    __init = function(self, model, clause, ...)
      self.model = model
      local param_count = select("#", ...)
      local opts
      if param_count > 0 then
        local last = select(param_count, ...)
        opts = type(last) == "table" and last
      end
      self.per_page = self.model.per_page
      if opts then
        self.per_page = opts.per_page
      end
      if opts and opts.prepare_results then
        self.prepare_results = opts.prepare_results
      end
      self._clause = db.interpolate_query(clause, ...)
      self.opts = opts
    end,
    __base = _base_0,
    __name = "Paginator"
  }, {
    __index = _base_0,
    __call = function(cls, ...)
      local _self_0 = setmetatable({}, _base_0)
      cls.__init(_self_0, ...)
      return _self_0
    end
  })
  _base_0.__class = _class_0
  Paginator = _class_0
end
return {
  Model = Model,
  Paginator = Paginator
}
