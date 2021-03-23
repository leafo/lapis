LOADED_KEY = setmetatable {}, __tostring: => "::loaded_relations::"

assert_model = (primary_model, model_name) ->
  with m = primary_model\get_relation_model model_name
    error "failed to find model `#{model_name}` for relation" unless m

find_relation = (model, name) ->
  return unless model

  if rs = model.relations
    for relation in *rs
      if relation[1] == name
        return relation

  if p = model.__parent
    find_relation p, name

local preload

-- preload_relation is inserted into the relation class as a method
-- self: model class
-- objects: array of instances of model
-- name: the name of the relation to preload
-- ...: options passed to preloader
preload_relation = (objects, name, ...) =>
  -- relations prefixed with ? are optional loads, we can skip it if it doesn't exist
  optional = if name\sub(1,1) == "?"
    name = name\sub 2
    true

  preloader = @relation_preloaders and @relation_preloaders[name]

  unless preloader
    return false if optional
    error "Model #{@__name} doesn't have preloader for #{name}"

  preloader @, objects, ...
  true

-- this function is deprecated, replaced by 'preload', which has support for
-- nested relations of different types
preload_relations = (objects, name, ...) =>
  preload_relation @, objects, name

  if ...
    preload_relations @, objects, ...
  else
    true

-- this is used to preload a list of model instances, `objects`, that are all
-- the same type, `model`.
-- * `front` -- name of the relation to preload, it can either be a table
--   description or a single relation name
-- * `sub_relations` will hold the outlist list of models that have been loaded
--   indexed by any subsequent relations to load
preload_homogeneous = (sub_relations, model, objects, front, ...) ->
  import to_json from require "lapis.util"
  return unless front

  if type(front) == "table"
    for key, val in pairs front
      relation = type(key) == "string" and key or val

      -- this lets you set pass preload opts by using the reference to the
      -- preload function as a special key
      preload_opts = type(val) == "table" and val[preload] or nil

      preload_relation model, objects, relation, preload_opts

      if type(key) == "string"
        optional, relation_name = if key\sub(1,1) == "?"
          true, key\sub 2
        else
          false, key

        r = find_relation model, relation_name

        unless r
          continue if optional
          error "Model #{model.__name} doesn't have preloader for #{relation_name}"

        sub_relations or= {}
        sub_relations[val] or= {}
        loaded_objects = sub_relations[val]

        if r.has_many or r.fetch and r.many
          for obj in *objects
            continue unless obj[relation_name] -- if the preloader didn't insert array then just skip
            for fetched in *obj[relation_name]
              table.insert loaded_objects, fetched
        else
          for obj in *objects
            table.insert loaded_objects, obj[relation_name]
  else
    preload_relation model, objects, front

  if ...
    preload_homogeneous sub_relations, model, objects, ...
  else
    sub_relations

preload = (objects, ...) ->
  -- group by type
  by_type = {}

  for object in *objects
    cls = object.__class
    unless cls
      error "attempting to preload an object that doesn't have a class, are you sure it's a model?"

    by_type[cls] or= {}
    table.insert by_type[object.__class], object

  local sub_relations

  for model, model_objects in pairs by_type
    sub_relations = preload_homogeneous sub_relations, model, model_objects, ...

  if sub_relations
    for sub_load, sub_objects in pairs sub_relations
      preload sub_objects, sub_load

  true

mark_loaded_relations = (items, name) ->
  for item in *items
    if loaded = item[LOADED_KEY]
      loaded[name] = true
    else
      item[LOADED_KEY] = { [name]: true }

clear_loaded_relation = (item, name) ->
  item[name] = nil
  if loaded = item[LOADED_KEY]
    loaded[name] = nil
  true

relation_is_loaded = (item, name) ->
  item[name] or item[LOADED_KEY] and item[LOADED_KEY][name]

get_relations_class = (model) ->
  parent = model.__parent
  unless parent
    error "model does not have parent class"

  if rawget parent, "_relations_class"
    return parent

  preloaders = {}
  if inherited = parent.relation_preloaders
    setmetatable preloaders, __index: inherited

  relations_class = class extends model.__parent
    @__name: "#{model.__name}Relations"
    @_relations_class: true

    @relation_preloaders: preloaders

    @preload_relations: preload_relations
    @preload_relation: preload_relation

    clear_loaded_relation: clear_loaded_relation

  model.__parent = relations_class
  setmetatable model.__base, relations_class.__base
  relations_class

fetch = (name, opts) =>
  source = opts.fetch
  if source == true
    assert type(opts.preload) == "function", "You set fetch to `true` but did not provide a `preload` function"
    source = =>
      @@preload_relation { @ }, name
      @[name]

  assert type(source) == "function", "Expecting function for `fetch` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = =>
    existing = @[name]

    loaded = @[LOADED_KEY]
    return existing if existing != nil or loaded and loaded[name]
    if loaded
      loaded[name] = true
    else
      @[LOADED_KEY] = { [name]: true }

    with obj = source @
      @[name] = obj

  if opts.preload
    @relation_preloaders[name] = (objects, preload_opts) =>
      mark_loaded_relations objects, name
      opts.preload objects, preload_opts, @, name

belongs_to = (name, opts) =>
  source = opts.belongs_to
  assert type(source) == "string", "Expecting model name for `belongs_to` relation"

  get_method = opts.as or "get_#{name}"
  column_name = opts.key or "#{name}_id"

  assert type(column_name) == "string",
    "`belongs_to` relation doesn't support composite key, use `has_one` instead"

  @__base[get_method] = =>
    return nil unless @[column_name]
    existing = @[name]

    loaded = @[LOADED_KEY]
    return existing if existing != nil or loaded and loaded[name]
    if loaded
      loaded[name] = true
    else
      @[LOADED_KEY] = { [name]: true }

    model = assert_model @@, source
    with obj = model\find @[column_name]
      @[name] = obj

  @relation_preloaders[name] = (objects, preload_opts) =>
    model = assert_model @@, source
    preload_opts or= {}
    preload_opts.as = name
    preload_opts.for_relation = name
    model\include_in objects, column_name, preload_opts

has_one = (name, opts) =>
  source = opts.has_one
  model_name = @__name
  assert type(source) == "string", "Expecting model name for `has_one` relation"

  get_method = opts.as or "get_#{name}"

  -- assert opts.local_key, "`has_one` relation `local_key` option deprecated for composite `key`"

  @__base[get_method] = =>
    existing = @[name]

    loaded = @[LOADED_KEY]
    return existing if existing != nil or loaded and loaded[name]
    if loaded
      loaded[name] = true
    else
      @[LOADED_KEY] = { [name]: true }

    model = assert_model @@, source

    clause = if type(opts.key) == "table"
      out = {}
      for k,v in pairs opts.key
        key, local_key = if type(k) == "number"
          v, v
        else
          k,v

        out[key] = @[local_key] or @@db.NULL

      out
    else
      local_key = opts.local_key
      unless local_key
        local_key, extra_key = @@primary_keys!
        assert extra_key == nil, "Model #{model_name} has composite primary keys, you must specify column mapping directly with `key`"

      {
        [opts.key or "#{@@singular_name!}_id"]: @[local_key]
      }

    if where = opts.where
      for k,v in pairs where
        clause[k] = v

    with obj = model\find clause
      @[name] = obj

  @relation_preloaders[name] = (objects, preload_opts) =>
    model = assert_model @@, source

    key = if type(opts.key) == "table"
      opts.key
    else
      local_key = opts.local_key
      unless local_key
        local_key, extra_key = @@primary_keys!
        assert extra_key == nil, "Model #{model_name} has composite primary keys, you must specify column mapping directly with `key`"

      {
        [opts.key or "#{@@singular_name!}_id"]: local_key
      }

    preload_opts or= {}

    preload_opts.for_relation = name
    preload_opts.as = name
    preload_opts.where or= opts.where

    model\include_in objects, key, preload_opts

has_many = (name, opts) =>
  source = opts.has_many
  assert type(source) == "string", "Expecting model name for `has_many` relation"

  get_method = opts.as or "get_#{name}"
  get_paginated_method = "#{get_method}_paginated"

  build_query = (additional_opts) =>
    foreign_key = opts.key or "#{@@singular_name!}_id"

    clause = if type(foreign_key) == "table"
      out = {}
      for k,v in pairs foreign_key
        key, local_key = if type(k) == "number"
          v, v
        else
          k,v

        out[key] = @[local_key] or @@db.NULL

      out
    else
      {
        [foreign_key]: @[opts.local_key or @@primary_keys!]
      }

    if where = opts.where
      for k,v in pairs where
        clause[k] = v

    if additional_opts and additional_opts.where
      for k,v in pairs additional_opts.where
        clause[k] = v

    clause = "where #{@@db.encode_clause clause}"

    if order = additional_opts and additional_opts.order or opts.order
      clause ..= " order by #{order}"

    clause

  @__base[get_method] = =>
    existing = @[name]

    loaded = @[LOADED_KEY]
    return existing if existing != nil or loaded and loaded[name]
    if loaded
      loaded[name] = true
    else
      @[LOADED_KEY] = { [name]: true }

    model = assert_model @@, source

    with res = model\select build_query(@)
      @[name] = res

  unless opts.pager == false
    @__base[get_paginated_method] = (fetch_opts) =>
      model = assert_model @@, source

      query_opts = if fetch_opts and (fetch_opts.where or fetch_opts.order)
        -- ordered paginator can take order
        order = unless fetch_opts.ordered
          fetch_opts.order

        {
          where: fetch_opts.where
          :order
        }

      model\paginated build_query(@, query_opts), fetch_opts

  @relation_preloaders[name] = (objects, preload_opts) =>
    model = assert_model @@, source

    foreign_key = opts.key or "#{@@singular_name!}_id"
    composite_key = type(foreign_key) == "table"

    local_key = unless composite_key
      opts.local_key or @@primary_keys!

    preload_opts or= {}

    unless composite_key
      preload_opts.flip = true

    preload_opts.many = true
    preload_opts.for_relation = name
    preload_opts.as = name
    preload_opts.local_key = local_key

    preload_opts.order or= opts.order
    preload_opts.where or= opts.where

    model\include_in objects, foreign_key, preload_opts

polymorphic_belongs_to = (name, opts) =>
  import enum from require "lapis.db.model"
  types = opts.polymorphic_belongs_to

  assert type(types) == "table", "missing types"

  type_col = "#{name}_type"
  id_col = "#{name}_id"
  enum_name = "#{name}_types"

  model_for_type_method = "model_for_#{name}_type"
  type_for_object_method = "#{name}_type_for_object"
  type_for_model_method = "#{name}_type_for_model"

  get_method = "get_#{name}"

  @[enum_name] = enum { assert(v[1], "missing type name"), k for k,v in pairs types}

  @relation_preloaders[name] = (objs, preload_opts) =>
    fields = preload_opts and preload_opts.fields

    for {type_name, model_name} in *types
      model = assert_model @@, model_name
      filtered = [o for o in *objs when o[type_col] == @@[enum_name][type_name]]
      model\include_in filtered, id_col, {
        for_relation: name
        as: name
        fields: fields and fields[type_name]
      }

    objs

  -- TODO: deprecate this for the new `preload_relations` method
  @["preload_#{name}s"] = @relation_preloaders[name]

  @[model_for_type_method] = (t) =>
    type_name = @[enum_name]\to_name t
    for {t_name, t_model_name} in *types
      if t_name == type_name
        return assert_model @@, t_model_name

    error "failed to model for type: #{type_name}"

  @[type_for_object_method] = (o) =>
    @[type_for_model_method] @, assert o.__class, "invalid object, missing class"

  @[type_for_model_method] = (m) =>
    assert m.__name, "missing class name for model"
    model_name = m.__name

    for i, {_, t_model_name} in ipairs types
      if model_name == t_model_name
        return i

    error "failed to find type for model: #{model_name}"

  @__base[get_method] = =>
    existing = @[name]

    loaded = @[LOADED_KEY]
    return existing if existing != nil or loaded and loaded[name]
    if loaded
      loaded[name] = true
    else
      @[LOADED_KEY] = { [name]: true }

    if t = @[type_col]
      model = @@[model_for_type_method] @@, t
      with obj = model\find @[id_col]
        @[name] = obj


relation_builders = {
  :fetch, :belongs_to, :has_one, :has_many, :polymorphic_belongs_to,
}

-- add_relations, Things, {
--   {"user", has_one: "Users"}
--   {"posts", has_many: "Posts", pager: true, order: "id ASC"}
-- }
add_relations = (relations) =>
  cls = get_relations_class @

  for relation in *relations
    name = assert relation[1], "missing relation name"
    built = false

    for k in pairs relation
      if builder = relation_builders[k]
        builder cls, name, relation
        built = true
        break

    continue if built

    import flatten_params from require "lapis.logging"
    error "don't know how to create relation `#{flatten_params relation}`"

{
  :relation_builders, :find_relation, :clear_loaded_relation, :LOADED_KEY
  :add_relations, :get_relations_class, :mark_loaded_relations, :relation_is_loaded
  :preload
}
