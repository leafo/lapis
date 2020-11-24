local LOADED_KEY = setmetatable({ }, {
  __tostring = function(self)
    return "::loaded_relations::"
  end
})
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
local find_relation
find_relation = function(model, name)
  if not (model) then
    return 
  end
  do
    local rs = model.relations
    if rs then
      for _index_0 = 1, #rs do
        local relation = rs[_index_0]
        if relation[1] == name then
          return relation
        end
      end
    end
  end
  do
    local p = model.__parent
    if p then
      return find_relation(p, name)
    end
  end
end
local preload_relation
preload_relation = function(self, objects, name, ...)
  local preloader = self.relation_preloaders[name]
  if not (preloader) then
    error("Model " .. tostring(self.__name) .. " doesn't have preloader for " .. tostring(name))
  end
  preloader(self, objects, ...)
  return true
end
local preload_relations
preload_relations = function(self, objects, name, ...)
  local preloader = self.relation_preloaders[name]
  if not (preloader) then
    error("Model " .. tostring(self.__name) .. " doesn't have preloader for " .. tostring(name))
  end
  preloader(self, objects)
  if ... then
    return self:preload_relations(objects, ...)
  else
    return true
  end
end
local preload_homogeneous
preload_homogeneous = function(sub_relations, model, objects, front, ...)
  local to_json
  to_json = require("lapis.util").to_json
  if not (front) then
    return 
  end
  if type(front) == "table" then
    for key, val in pairs(front) do
      local relation = type(key) == "string" and key or val
      preload_relation(model, objects, relation)
      if type(key) == "string" then
        local r = find_relation(model, key)
        if not (r) then
          error("missing relation: " .. tostring(key))
        end
        sub_relations = sub_relations or { }
        sub_relations[val] = sub_relations[val] or { }
        local loaded_objects = sub_relations[val]
        if r.has_many or r.fetch and r.many then
          for _index_0 = 1, #objects do
            local obj = objects[_index_0]
            local _list_0 = obj[key]
            for _index_1 = 1, #_list_0 do
              local fetched = _list_0[_index_1]
              table.insert(loaded_objects, fetched)
            end
          end
        else
          for _index_0 = 1, #objects do
            local obj = objects[_index_0]
            table.insert(loaded_objects, obj[key])
          end
        end
      end
    end
  else
    preload_relation(model, objects, front)
  end
  if ... then
    return preload_homogeneous(sub_relations, model, objects, ...)
  else
    return sub_relations
  end
end
local preload
preload = function(objects, ...)
  local by_type = { }
  for _index_0 = 1, #objects do
    local object = objects[_index_0]
    local cls = object.__class
    if not (cls) then
      error("attempting to preload an object that doesn't have a class, are you sure it's a model?")
    end
    by_type[cls] = by_type[cls] or { }
    table.insert(by_type[object.__class], object)
  end
  local sub_relations
  for model, model_objects in pairs(by_type) do
    sub_relations = preload_homogeneous(sub_relations, model, model_objects, ...)
  end
  if sub_relations then
    for sub_load, sub_objects in pairs(sub_relations) do
      preload(sub_objects, sub_load)
    end
  end
  return true
end
local mark_loaded_relations
mark_loaded_relations = function(items, name)
  for _index_0 = 1, #items do
    local item = items[_index_0]
    do
      local loaded = item[LOADED_KEY]
      if loaded then
        loaded[name] = true
      else
        item[LOADED_KEY] = {
          [name] = true
        }
      end
    end
  end
end
local clear_loaded_relation
clear_loaded_relation = function(item, name)
  item[name] = nil
  do
    local loaded = item[LOADED_KEY]
    if loaded then
      loaded[name] = nil
    end
  end
  return true
end
local relation_is_loaded
relation_is_loaded = function(item, name)
  return item[name] or item[LOADED_KEY] and item[LOADED_KEY][name]
end
local get_relations_class
get_relations_class = function(model)
  local parent = model.__parent
  if not (parent) then
    error("model does not have parent class")
  end
  if rawget(parent, "_relations_class") then
    return parent
  end
  local preloaders = { }
  do
    local inherited = parent.relation_preloaders
    if inherited then
      setmetatable(preloaders, {
        __index = inherited
      })
    end
  end
  local relations_class
  do
    local _class_0
    local _parent_0 = model.__parent
    local _base_0 = {
      clear_loaded_relation = clear_loaded_relation
    }
    _base_0.__index = _base_0
    setmetatable(_base_0, _parent_0.__base)
    _class_0 = setmetatable({
      __init = function(self, ...)
        return _class_0.__parent.__init(self, ...)
      end,
      __base = _base_0,
      __name = "relations_class",
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
    self.__name = tostring(model.__name) .. "Relations"
    self._relations_class = true
    self.relation_preloaders = preloaders
    self.preload_relations = preload_relations
    self.preload_relation = preload_relation
    if _parent_0.__inherited then
      _parent_0.__inherited(_parent_0, _class_0)
    end
    relations_class = _class_0
  end
  model.__parent = relations_class
  setmetatable(model.__base, relations_class.__base)
  return relations_class
end
local fetch
fetch = function(self, name, opts)
  local source = opts.fetch
  assert(type(source) == "function", "Expecting function for `fetch` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    local loaded = self[LOADED_KEY]
    if existing ~= nil or loaded and loaded[name] then
      return existing
    end
    if loaded then
      loaded[name] = true
    else
      self[LOADED_KEY] = {
        [name] = true
      }
    end
    do
      local obj = source(self)
      self[name] = obj
      return obj
    end
  end
  if opts.preload then
    self.relation_preloaders[name] = function(self, objects, preload_opts)
      mark_loaded_relations(objects, name)
      return opts.preload(objects, preload_opts, self, name)
    end
  end
end
local belongs_to
belongs_to = function(self, name, opts)
  local source = opts.belongs_to
  assert(type(source) == "string", "Expecting model name for `belongs_to` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  local column_name = opts.key or tostring(name) .. "_id"
  assert(type(column_name) == "string", "`belongs_to` relation doesn't support composite key, use `has_one` instead")
  self.__base[get_method] = function(self)
    if not (self[column_name]) then
      return nil
    end
    local existing = self[name]
    local loaded = self[LOADED_KEY]
    if existing ~= nil or loaded and loaded[name] then
      return existing
    end
    if loaded then
      loaded[name] = true
    else
      self[LOADED_KEY] = {
        [name] = true
      }
    end
    local model = assert_model(self.__class, source)
    do
      local obj = model:find(self[column_name])
      self[name] = obj
      return obj
    end
  end
  self.relation_preloaders[name] = function(self, objects, preload_opts)
    local model = assert_model(self.__class, source)
    preload_opts = preload_opts or { }
    preload_opts.as = name
    preload_opts.for_relation = name
    return model:include_in(objects, column_name, preload_opts)
  end
end
local has_one
has_one = function(self, name, opts)
  local source = opts.has_one
  local model_name = self.__name
  assert(type(source) == "string", "Expecting model name for `has_one` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  self.__base[get_method] = function(self)
    local existing = self[name]
    local loaded = self[LOADED_KEY]
    if existing ~= nil or loaded and loaded[name] then
      return existing
    end
    if loaded then
      loaded[name] = true
    else
      self[LOADED_KEY] = {
        [name] = true
      }
    end
    local model = assert_model(self.__class, source)
    local clause
    if type(opts.key) == "table" then
      local out = { }
      for k, v in pairs(opts.key) do
        local key, local_key
        if type(k) == "number" then
          key, local_key = v, v
        else
          key, local_key = k, v
        end
        out[key] = self[local_key] or self.__class.db.NULL
      end
      clause = out
    else
      local local_key = opts.local_key
      if not (local_key) then
        local extra_key
        local_key, extra_key = self.__class:primary_keys()
        assert(extra_key == nil, "Model " .. tostring(model_name) .. " has composite primary keys, you must specify column mapping directly with `key`")
      end
      clause = {
        [opts.key or tostring(self.__class:singular_name()) .. "_id"] = self[local_key]
      }
    end
    do
      local where = opts.where
      if where then
        for k, v in pairs(where) do
          clause[k] = v
        end
      end
    end
    do
      local obj = model:find(clause)
      self[name] = obj
      return obj
    end
  end
  self.relation_preloaders[name] = function(self, objects, preload_opts)
    local model = assert_model(self.__class, source)
    local key
    if type(opts.key) == "table" then
      key = opts.key
    else
      local local_key = opts.local_key
      if not (local_key) then
        local extra_key
        local_key, extra_key = self.__class:primary_keys()
        assert(extra_key == nil, "Model " .. tostring(model_name) .. " has composite primary keys, you must specify column mapping directly with `key`")
      end
      key = {
        [opts.key or tostring(self.__class:singular_name()) .. "_id"] = local_key
      }
    end
    preload_opts = preload_opts or { }
    preload_opts.for_relation = name
    preload_opts.as = name
    preload_opts.where = preload_opts.where or opts.where
    return model:include_in(objects, key, preload_opts)
  end
end
local has_many
has_many = function(self, name, opts)
  local source = opts.has_many
  assert(type(source) == "string", "Expecting model name for `has_many` relation")
  local get_method = opts.as or "get_" .. tostring(name)
  local get_paginated_method = tostring(get_method) .. "_paginated"
  local build_query
  build_query = function(self, additional_opts)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local clause
    if type(foreign_key) == "table" then
      local out = { }
      for k, v in pairs(foreign_key) do
        local key, local_key
        if type(k) == "number" then
          key, local_key = v, v
        else
          key, local_key = k, v
        end
        out[key] = self[local_key] or self.__class.db.NULL
      end
      clause = out
    else
      clause = {
        [foreign_key] = self[opts.local_key or self.__class:primary_keys()]
      }
    end
    do
      local where = opts.where
      if where then
        for k, v in pairs(where) do
          clause[k] = v
        end
      end
    end
    if additional_opts and additional_opts.where then
      for k, v in pairs(additional_opts.where) do
        clause[k] = v
      end
    end
    clause = "where " .. tostring(self.__class.db.encode_clause(clause))
    do
      local order = additional_opts and additional_opts.order or opts.order
      if order then
        clause = clause .. " order by " .. tostring(order)
      end
    end
    return clause
  end
  self.__base[get_method] = function(self)
    local existing = self[name]
    local loaded = self[LOADED_KEY]
    if existing ~= nil or loaded and loaded[name] then
      return existing
    end
    if loaded then
      loaded[name] = true
    else
      self[LOADED_KEY] = {
        [name] = true
      }
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
      local query_opts
      if fetch_opts and (fetch_opts.where or fetch_opts.order) then
        local order
        if not (fetch_opts.ordered) then
          order = fetch_opts.order
        end
        query_opts = {
          where = fetch_opts.where,
          order = order
        }
      end
      return model:paginated(build_query(self, query_opts), fetch_opts)
    end
  end
  self.relation_preloaders[name] = function(self, objects, preload_opts)
    local model = assert_model(self.__class, source)
    local foreign_key = opts.key or tostring(self.__class:singular_name()) .. "_id"
    local composite_key = type(foreign_key) == "table"
    local local_key
    if not (composite_key) then
      local_key = opts.local_key or self.__class:primary_keys()
    end
    preload_opts = preload_opts or { }
    if not (composite_key) then
      preload_opts.flip = true
    end
    preload_opts.many = true
    preload_opts.for_relation = name
    preload_opts.as = name
    preload_opts.local_key = local_key
    preload_opts.order = preload_opts.order or opts.order
    preload_opts.where = preload_opts.where or opts.where
    return model:include_in(objects, foreign_key, preload_opts)
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
  self.relation_preloaders[name] = function(self, objs, preload_opts)
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
        for_relation = name,
        as = name,
        fields = fields and fields[type_name]
      })
    end
    return objs
  end
  self["preload_" .. tostring(name) .. "s"] = self.relation_preloaders[name]
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
    local loaded = self[LOADED_KEY]
    if existing ~= nil or loaded and loaded[name] then
      return existing
    end
    if loaded then
      loaded[name] = true
    else
      self[LOADED_KEY] = {
        [name] = true
      }
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
local relation_builders = {
  fetch = fetch,
  belongs_to = belongs_to,
  has_one = has_one,
  has_many = has_many,
  polymorphic_belongs_to = polymorphic_belongs_to
}
local add_relations
add_relations = function(self, relations)
  local cls = get_relations_class(self)
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
            builder(cls, name, relation)
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
return {
  relation_builders = relation_builders,
  find_relation = find_relation,
  clear_loaded_relation = clear_loaded_relation,
  LOADED_KEY = LOADED_KEY,
  add_relations = add_relations,
  get_relations_class = get_relations_class,
  mark_loaded_relations = mark_loaded_relations,
  relation_is_loaded = relation_is_loaded,
  preload = preload
}
