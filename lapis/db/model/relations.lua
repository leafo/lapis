local assert_model
assert_model = function(primary_model, model_name)
  do
    local m = primary_model:get_relation_model(model_name)
    if not (m) then
      error("failed to find model `" .. tostring(model_name) .. "` for relation")
    end
    return m
  end
end
local fetch
fetch = function(self, name, opts)
  local source = opts.fetch
  assert(type(source) == "function", "Expecting function for `fetch` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    do
      local obj = source(self)
      self[name] = obj
      return obj
    end
  end
end
local belongs_to
belongs_to = function(self, name, opts)
  local source = opts.belongs_to
  assert(type(source) == "string", "Expecting model name for `belongs_to` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  local column_name = opts.key or tostring(name) .. "_id"
  self.__base[get_method] = function(self)
    if not (self[column_name]) then
      return nil
    end
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    local model = assert_model(self.__class, source)
    do
      local obj = model:find(self[column_name])
      self[name] = obj
      return obj
    end
  end
end
local has_one
has_one = function(self, name, opts)
  local source = opts.has_one
  assert(type(source) == "string", "Expecting model name for `has_one` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    local model = assert_model(self.__class, source)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local clause = {
      [foreign_key] = self[self.__class:primary_keys()]
    }
    do
      local obj = model:find(clause)
      self[name] = obj
      return obj
    end
  end
end
local has_many
has_many = function(self, name, opts)
  local source = opts.has_many
  assert(type(source) == "string", "Expecting model name for `has_many` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  local get_paginated_method = tostring(get_method) .. "_paginated"
  local build_query
  build_query = function(self)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local clause = {
      [foreign_key] = self[self.__class:primary_keys()]
    }
    do
      local where = opts.where
      if where then
        for k, v in pairs(where) do
          clause[k] = v
        end
      end
    end
    clause = "where " .. tostring(self.__class.db.encode_clause(clause))
    do
      local order = opts.order
      if order then
        clause = clause .. " order by " .. tostring(order)
      end
    end
    return clause
  end
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    local model = assert_model(self.__class, source)
    do
      local res = model:select(build_query(self))
      self[name] = res
      return res
    end
  end
  if not (opts.pager == false) then
    self.__base[get_paginated_method] = function(self, fetch_opts)
      local model = assert_model(self.__class, source)
      return model:paginated(build_query(self), fetch_opts)
    end
  end
end
local polymorphic_belongs_to
polymorphic_belongs_to = function(self, name, opts)
  local enum
  enum = require("lapis.db.model").enum
  local types = opts.polymorphic_belongs_to
  assert(type(types) == "table", "missing types")
  local type_col = tostring(name) .. "_type"
  local id_col = tostring(name) .. "_id"
  local enum_name = tostring(name) .. "_types"
  local model_for_type_method = "model_for_" .. tostring(name) .. "_type"
  local type_for_object_method = tostring(name) .. "_type_for_object"
  local type_for_model_method = tostring(name) .. "_type_for_model"
  local get_method = "get_" .. tostring(name)
  self[enum_name] = enum((function()
    local _tbl_0 = { }
    for k, v in pairs(types) do
      _tbl_0[assert(v[1], "missing type name")] = k
    end
    return _tbl_0
  end)())
  self["preload_" .. tostring(name) .. "s"] = function(self, objs, preload_opts)
    local fields = preload_opts and preload_opts.fields
    for _index_0 = 1, #types do
      local _des_0 = types[_index_0]
      local type_name, model_name
      type_name, model_name = _des_0[1], _des_0[2]
      local model = assert_model(self.__class, model_name)
      local filtered
      do
        local _accum_0 = { }
        local _len_0 = 1
        for _index_1 = 1, #objs do
          local o = objs[_index_1]
          if o[type_col] == self.__class[enum_name][type_name] then
            _accum_0[_len_0] = o
            _len_0 = _len_0 + 1
          end
        end
        filtered = _accum_0
      end
      model:include_in(filtered, id_col, {
        as = name,
        fields = fields and fields[type_name]
      })
    end
    return objs
  end
  self[model_for_type_method] = function(self, t)
    local type_name = self[enum_name]:to_name(t)
    for _index_0 = 1, #types do
      local _des_0 = types[_index_0]
      local t_name, t_model_name
      t_name, t_model_name = _des_0[1], _des_0[2]
      if t_name == type_name then
        return assert_model(self.__class, t_model_name)
      end
    end
    return error("failed to model for type: " .. tostring(type_name))
  end
  self[type_for_object_method] = function(self, o)
    return self[type_for_model_method](self, assert(o.__class, "invalid object, missing class"))
  end
  self[type_for_model_method] = function(self, m)
    assert(m.__name, "missing class name for model")
    local model_name = m.__name
    for i, _des_0 in ipairs(types) do
      local _, t_model_name
      _, t_model_name = _des_0[1], _des_0[2]
      if model_name == t_model_name then
        return i
      end
    end
    return error("failed to find type for model: " .. tostring(model_name))
  end
  self.__base[get_method] = function(self)
    local existing = self[name]
    if existing ~= nil then
      return existing
    end
    do
      local t = self[type_col]
      if t then
        local model = self.__class[model_for_type_method](self.__class, t)
        do
          local obj = model:find(self[id_col])
          self[name] = obj
          return obj
        end
      end
    end
  end
end
return {
  fetch = fetch,
  belongs_to = belongs_to,
  has_one = has_one,
  has_many = has_many,
  polymorphic_belongs_to = polymorphic_belongs_to
}
