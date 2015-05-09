assert_model = (primary_model, model_name) ->
  with m = primary_model\get_relation_model model_name
    error "failed to find model `#{model_name}` for relation" unless m

fetch = (name, opts) =>
  source = opts.fetch
  assert type(source) == "function", "Expecting function for `fetch` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = =>
    existing = @[name]
    return existing if existing != nil
    with obj = source @
      @[name] = obj

belongs_to = (name, opts) =>
  source = opts.belongs_to
  assert type(source) == "string", "Expecting model name for `belongs_to` relation"

  get_method = opts.as or "get_#{name}"
  column_name = "#{name}_id"

  @__base[get_method] = =>
    return nil unless @[column_name]
    existing = @[name]
    return existing if existing != nil
    model = assert_model @@, source
    with obj = model\find @[column_name]
      @[name] = obj

has_one = (name, opts) =>
  source = opts.has_one
  assert type(source) == "string", "Expecting model name for `has_one` relation"

  get_method = opts.as or "get_#{name}"

  @__base[get_method] = =>
    existing = @[name]
    return existing if existing != nil
    model = assert_model @@, source

    foreign_key = opts.key or "#{@@singular_name!}_id"

    clause = {
      [foreign_key]: @[@@primary_keys!]
    }

    with obj = model\find clause
      @[name] = obj

has_many = (name, opts) =>
  source = opts.has_many
  assert type(source) == "string", "Expecting model name for `has_many` relation"

  get_method = opts.as or "get_#{name}"
  get_paginated_method = "#{get_method}_paginated"

  build_query = =>
    foreign_key = opts.key or "#{@@singular_name!}_id"

    clause = {
      [foreign_key]: @[@@primary_keys!]
    }

    if where = opts.where
      for k,v in pairs where
        clause[k] = v

    clause = "where #{@@db.encode_clause clause}"

    if order = opts.order
      clause ..= " order by #{order}"

    clause

  @__base[get_method] = =>
    existing = @[name]
    return existing if existing != nil
    model = assert_model @@, source

    with res = model\select build_query(@)
      @[name] = res

  unless opts.pager == false
    @__base[get_paginated_method] = (fetch_opts) =>
      model = assert_model @@, source
      model\paginated build_query(@), fetch_opts

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

  @["preload_#{name}s"] = (objs) =>
    for {type_name, model_name} in *types
      model = assert_model @@, model_name
      filtered = [o for o in *objs when o[type_col] == @@[enum_name][type_name]]
      model\include_in filtered, id_col, as: name

    objs

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
    return existing if existing != nil

    if t = @[type_col]
      model = @@[model_for_type_method] @@, t
      with obj = model\find @[id_col]
        @[name] = obj


{ :fetch, :belongs_to, :has_one, :has_many, :polymorphic_belongs_to }
